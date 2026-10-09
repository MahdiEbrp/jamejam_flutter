// Parity port of tests/JameJam.Tests/HaftKhan/HaftKhanServiceTests.cs (19 cases).
//
// The business logic of the to-do list, run against the in-memory repository and a fixed
// clock — fully deterministic, exactly like the .NET fixture (which injects a
// FixedTimeProvider for the same reason).
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/haftkhan/haftkhan_service.dart';
import 'package:jamejam/features/haftkhan/models.dart';
import 'package:jamejam/features/haftkhan/task_guard.dart';
import 'package:jamejam/features/haftkhan/task_repository.dart';

/// The .NET suite's FixedTimeProvider: one instant, no drift.
DateTime Function() fixedClock(DateTime now) =>
    () => now;

void main() {
  final now = DateTime.utc(2026, 9, 19, 10);
  late MemoryTaskRepository repository;
  late HaftKhanService service;

  setUp(() {
    repository = MemoryTaskRepository();
    service = HaftKhanService(repository: repository, clock: fixedClock(now));
  });

  // AddTask_RoundTrips_AllFields
  test('addTask round-trips every field through storage', () async {
    final task = await service.addTask(
      title: '  Slay the dragon ',
      notes: ' bring a sword\u0002',
      priorityName: 'critical',
      dueDateText: '2026-09-25',
    );

    final stored = await service.find('${task.id}');

    expect(stored.title, 'Slay the dragon');
    expect(stored.notes, 'bring a sword');
    expect(stored.priority, TaskPriority.critical);
    expect(stored.dueDate, DateOnly(2026, 9, 25));
    expect(stored.state, TaskState.todo);
    expect(stored.completedAt, isNull);
    expect(
      stored.createdAt.isBefore(
        DateTime.now().toUtc().add(const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });

  // AddTask_ControlCharsAreStripped
  test('addTask strips control characters from the title', () async {
    final task = await service.addTask(title: 'a\u0007b');

    expect(task.title, 'ab');
  });

  // AddTask_EmptyTitle_Throws
  test('addTask rejects an empty title', () {
    expect(() => service.addTask(title: '   '), throwsArgumentError);
  });

  // AddTask_TooLongTitle_Throws
  test('addTask rejects a too-long title', () {
    expect(() => service.addTask(title: 't' * 201), throwsA(isA<RangeError>()));
  });

  // AddTask_InvalidPriority_Throws
  test('addTask rejects an unknown priority', () {
    expect(
      () => service.addTask(title: 't', priorityName: 'urgent'),
      throwsArgumentError,
    );
  });

  // AddTask_InvalidDate_Throws
  test('addTask rejects an unparseable date', () {
    expect(
      () => service.addTask(title: 't', dueDateText: 'not-a-date'),
      throwsArgumentError,
    );
  });

  // AddTask_NaturalLanguageDate_Parses
  test('addTask accepts a natural-language date', () async {
    final task = await service.addTask(title: 't', dueDateText: 'tomorrow');

    expect(task.dueDate, DateOnly(2026, 9, 20));
  });

  // Start_SetsDoingState
  test('start moves a task to doing and stamps the clock', () async {
    final task = await service.addTask(title: 't');

    final started = await service.start('${task.id}');

    expect(started.state, TaskState.doing);
    expect(started.updatedAt, now);
    expect((await service.find('${task.id}')).state, TaskState.doing);
  });

  // Start_DoneTask_Throws
  test('start refuses a finished task', () async {
    final task = await service.addTask(title: 't');
    await service.complete('${task.id}');

    await expectLater(
      service.start('${task.id}'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('already done'),
        ),
      ),
    );
  });

  // Complete_SetsDone_AndRecordsCompletionTime
  test('complete marks the task done and records the time', () async {
    final task = await service.addTask(title: 't');

    final result = await service.complete('${task.id}');

    expect(result.completed.state, TaskState.done);
    expect(result.completed.completedAt, now);
    expect(result.completed.updatedAt, now);
    expect(result.next, isNull);
  });

  // Complete_AlreadyDone_Throws
  test('complete refuses an already finished task', () async {
    final task = await service.addTask(title: 't');
    await service.complete('${task.id}');

    await expectLater(service.complete('${task.id}'), throwsStateError);
  });

  // Remove_RemovesExistingTask
  test('remove deletes the task', () async {
    final task = await service.addTask(title: 't');

    await service.remove('${task.id}');

    await expectLater(
      service.find('${task.id}'),
      throwsA(isA<TaskNotFoundException>()),
    );
  });

  // Remove_MissingTask_ThrowsNotFound
  test('remove on a missing task reports the id', () async {
    await expectLater(
      service.remove('99'),
      throwsA(
        isA<TaskNotFoundException>()
            .having((error) => error.id, 'id', 99)
            .having(
              (error) => error.toString(),
              'message',
              contains('Task 99 was not found.'),
            ),
      ),
    );
  });

  // ClearCompleted_RemovesOnlyDone
  test(
    'clearCompleted removes only finished tasks and reports the count',
    () async {
      final done = await service.addTask(title: 'done');
      final open = await service.addTask(title: 'open');
      await service.complete('${done.id}');

      expect(await service.clearCompleted(), 1);
      expect((await service.find('${open.id}')).title, 'open');
      expect(await service.clearCompleted(), 0);
    },
  );

  // List_Open_SortsByPriorityThenDueThenId
  test('the open view sorts by priority, then due date, then id', () async {
    final low = await service.addTask(title: 'low', priorityName: 'low');
    final criticalLater = await service.addTask(
      title: 'crit-later',
      priorityName: 'critical',
      dueDateText: '2026-09-30',
    );
    final criticalSooner = await service.addTask(
      title: 'crit-sooner',
      priorityName: 'critical',
      dueDateText: '2026-09-20',
    );
    final normal = await service.addTask(title: 'normal');

    final open = await service.list(TaskView.open);

    expect(open.map((task) => task.id), [
      criticalSooner.id,
      criticalLater.id,
      normal.id,
      low.id,
    ]);
  });

  // List_Done_OnlyCompleted
  test('the done view lists only finished tasks', () async {
    final openTask = await service.addTask(title: 'open');
    final doneTask = await service.addTask(title: 'done');
    await service.complete('${doneTask.id}');

    final done = await service.list(TaskView.done);

    expect(done.map((task) => task.id), [doneTask.id]);
    expect(
      (await service.list(TaskView.open)).map((task) => task.id),
      contains(openTask.id),
    );
  });

  // List_Today_OnlyTasksDueToday
  test('the today view lists only tasks due today', () async {
    await service.addTask(title: 'past', dueDateText: '2026-09-18');
    final todayTask = await service.addTask(
      title: 'today',
      dueDateText: '2026-09-19',
    );
    await service.addTask(title: 'future', dueDateText: '2026-09-20');

    expect((await service.list(TaskView.today)).map((task) => task.id), [
      todayTask.id,
    ]);
  });

  // List_Overdue_OnlyPastDueOpenTasks
  test('the overdue view lists only open tasks past their due date', () async {
    final yesterday = await service.addTask(
      title: 'past',
      dueDateText: '2026-09-18',
    );
    await service.addTask(title: 'today', dueDateText: '2026-09-19');

    expect((await service.list(TaskView.overdue)).map((task) => task.id), [
      yesterday.id,
    ]);
  });

  // Stats_CountsStatesAndOverdue
  test('the report counts every state plus overdue', () async {
    await service.addTask(title: 'todo');
    final doing = await service.addTask(title: 'doing');
    await service.start('${doing.id}');
    final doneTask = await service.addTask(title: 'done');
    await service.complete('${doneTask.id}');
    await service.addTask(title: 'overdue', dueDateText: '2026-09-01');

    final report = await service.report();

    expect(report.todo + report.doing + report.done, 4);
    expect(report.todo, 2);
    expect(report.doing, 1);
    expect(report.done, 1);
    expect(report.overdue, 1);
  });

  // Options_AreValidatedAtConstruction
  test('options are validated when the service is built', () {
    expect(
      () => HaftKhanService(
        repository: repository,
        clock: fixedClock(now),
        options: const HaftKhanOptions(maxTitleLength: 0),
      ),
      throwsA(isA<RangeError>()),
    );
  });

  // Find_InvalidIdText_Throws
  test('find rejects a non-numeric id and reports a missing one', () async {
    await expectLater(service.find('zero'), throwsArgumentError);
    await expectLater(service.find('7'), throwsA(isA<TaskNotFoundException>()));
  });
}
