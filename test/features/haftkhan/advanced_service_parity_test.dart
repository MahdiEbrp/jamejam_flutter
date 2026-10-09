// Parity port of tests/JameJam.Tests/HaftKhan/AdvancedHaftKhanServiceTests.cs (24 cases).
//
// Feature coverage for the advanced engine: tags, projects, recurrence, dependencies,
// undo, search, filters, focus, board, matrix, streaks, and import/export.
//
// Divergence from the .NET fixture: `List((TaskView)99)` has no Dart equivalent — the enum
// switch is exhaustive at compile time, so an invented view cannot exist to test. Everything
// else is case-for-case.
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/haftkhan/backup.dart';
import 'package:jamejam/features/haftkhan/haftkhan_service.dart';
import 'package:jamejam/features/haftkhan/models.dart';
import 'package:jamejam/features/haftkhan/task_guard.dart';
import 'package:jamejam/features/haftkhan/task_repository.dart';

void main() {
  final now = DateTime.utc(2026, 9, 19, 10); // a Saturday

  late MemoryTaskRepository repository;
  late HaftKhanService service;

  setUp(() {
    repository = MemoryTaskRepository();
    service = HaftKhanService(repository: repository, clock: () => now);
  });

  // ── Tags & projects ──

  // AddTask_StoresProjectTagsAndEffort
  test('addTask stores project, tags and effort', () async {
    final task = await service.addTask(
      title: 'Fix the stable',
      priorityName: 'high',
      project: 'home',
      tagsCsv: 'chores,quick',
      effortName: 'm',
    );

    expect(task.project, 'home');
    expect(task.tags, ['chores', 'quick']);
    expect(task.effort, TaskEffort.medium);
    expect(await repository.getTags(task.id), ['chores', 'quick']);
  });

  // ListFiltered_ByTagProjectAndPriority
  test('listFiltered filters by tag, project and minimum priority', () async {
    await service.addTask(
      title: 'a',
      priorityName: 'high',
      project: 'home',
      tagsCsv: 'chores',
    );
    await service.addTask(
      title: 'b',
      priorityName: 'low',
      project: 'work',
      tagsCsv: 'email',
    );
    await service.addTask(
      title: 'c',
      priorityName: 'critical',
      project: 'home',
      tagsCsv: 'email',
    );

    expect(
      (await service.listFiltered(
        TaskView.open,
        tag: 'chores',
      )).map((task) => task.title),
      ['a'],
    );
    expect(
      (await service.listFiltered(
        TaskView.open,
        project: 'HOME',
      )).map((task) => task.title),
      ['c', 'a'], // priority order
    );
    expect(
      (await service.listFiltered(
        TaskView.open,
        tag: 'email',
        priorityName: 'critical',
      )).map((task) => task.title),
      ['c'],
    );
    expect(
      (await service.listFiltered(
        TaskView.open,
        priorityName: 'low',
      )).map((task) => task.title),
      ['c', 'a', 'b'],
    );
  });

  // Search_FindsTitlesNotesProjectsAndTags
  test('search looks in titles, notes, projects and tags', () async {
    await service.addTask(
      title: 'Slay dragon',
      notes: 'needs a sword',
      project: 'myth',
      tagsCsv: 'hero',
    );
    await service.addTask(title: 'Buy bread');

    expect((await service.search('dragon')).single.title, 'Slay dragon');
    expect((await service.search('sword')).single.title, 'Slay dragon');
    expect((await service.search('myth')).single.title, 'Slay dragon');
    expect((await service.search('HERO')).single.title, 'Slay dragon');
    expect(await service.search('dragonfly'), isEmpty);
    await expectLater(service.search('   '), throwsArgumentError);
  });

  // ── Recurrence ──

  // Complete_RecurringTask_SpawnsNextOccurrence
  test('completing a recurring task spawns the next occurrence', () async {
    final task = await service.addTask(
      title: 'Water the horse',
      priorityName: 'high',
      dueDateText: '2026-09-19',
      project: 'stable',
      tagsCsv: 'chor',
      recurrenceName: 'daily',
    );

    final result = await service.complete('${task.id}');

    expect(result.completed.state, TaskState.done);
    final next = result.next!;
    expect(next.id, isNot(task.id));
    expect(next.state, TaskState.todo);
    expect(next.dueDate, DateOnly(2026, 9, 20));
    expect(next.priority, TaskPriority.high);
    expect(next.project, 'stable');
    expect(next.tags, ['chor']);
    expect(next.recurrence, RecurrenceKind.daily);
  });

  // Complete_OneOffTask_DoesNotSpawn
  test('completing a one-off task spawns nothing', () async {
    final task = await service.addTask(title: 'one-off');

    expect((await service.complete('${task.id}')).next, isNull);
  });

  // ── Dependencies ──

  // AddTask_WithBlockers_CreatesLinks
  test('addTask with blockers creates the dependency links', () async {
    final first = await service.addTask(title: 'first');
    final second = await service.addTask(
      title: 'second',
      blockedBy: [first.id],
    );

    expect(
      await repository.listDependencies(),
      contains(TaskLink(second.id, first.id)),
    );
  });

  // AddTask_WithUnknownBlocker_Throws
  test('addTask rejects an unknown blocker', () {
    expect(
      () => service.addTask(title: 't', blockedBy: const [999]),
      throwsArgumentError,
    );
  });

  // Complete_BlockedTask_Throws_ForceWins
  test('a blocked task refuses completion unless forced', () async {
    final first = await service.addTask(title: 'first');
    final second = await service.addTask(
      title: 'second',
      blockedBy: [first.id],
    );

    await expectLater(
      service.complete('${second.id}'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('blocked by open task(s): #${first.id}'),
        ),
      ),
    );

    final forced = await service.complete('${second.id}', force: true);
    expect(forced.completed.state, TaskState.done);
  });

  // Complete_UnblockedAfterBlockerIsDone
  test('finishing the blocker unblocks the task', () async {
    final first = await service.addTask(title: 'first');
    final second = await service.addTask(
      title: 'second',
      blockedBy: [first.id],
    );
    await service.complete('${first.id}');

    expect(await service.complete('${second.id}'), isA<CompleteResult>());
  });

  // AddLink_RejectsUnknown_Self_AndCycles
  test('addLink rejects unknown ids, self-links, and cycles', () async {
    final a = await service.addTask(title: 'a');
    final b = await service.addTask(title: 'b');
    await service.addLink('${b.id}', '${a.id}');

    await expectLater(
      service.addLink('999', '1'),
      throwsA(isA<TaskNotFoundException>()),
    );
    await expectLater(
      service.addLink('${a.id}', '${a.id}'),
      throwsArgumentError,
    );
    await expectLater(service.addLink('${a.id}', '${b.id}'), throwsStateError);
  });

  // RemoveLinks_ClearsBothDirections
  test('removeLinks clears edges in both directions', () async {
    final a = await service.addTask(title: 'a');
    final b = await service.addTask(title: 'b');
    await service.addLink('${b.id}', '${a.id}');

    await service.removeLinks('${a.id}');

    expect(await repository.listDependencies(), isEmpty);
  });

  // NextFocus_SkipsBlockedTasks
  test('nextFocus skips blocked tasks and advances as they unblock', () async {
    final first = await service.addTask(title: 'first', priorityName: 'low');
    final second = await service.addTask(
      title: 'second',
      blockedBy: [first.id],
    );
    final third = await service.addTask(title: 'third', priorityName: 'high');

    expect((await service.nextFocus())!.title, 'third');

    await service.complete('${first.id}');
    expect(
      (await service.nextFocus())!.title,
      'third',
    ); // still outranks "second"

    await service.complete('${third.id}');
    expect((await service.nextFocus())!.title, 'second');
    expect(second.id, isNot(first.id));
  });

  // Remove_CleansUpLinks
  test('removing a task cleans up its links', () async {
    final a = await service.addTask(title: 'a');
    final b = await service.addTask(title: 'b');
    await service.addLink('${b.id}', '${a.id}');

    await service.remove('${a.id}');

    expect(await repository.listDependencies(), isEmpty);
  });

  // ── Undo ──

  // Undo_RevertsAdd_Remove_Start_Done_AndClearDone
  test('undo reverts add, start, done and clear-done', () async {
    final task = await service.addTask(
      title: 'labour',
      notes: 'n',
      priorityName: 'high',
    );

    expect((await service.undo()).operation, 'add');
    expect(await repository.find(task.id), isNull); // add reverted

    final reloaded = await service.addTask(title: 'labour2');
    await service.start('${reloaded.id}');
    await service.undo();
    expect((await repository.find(reloaded.id))!.state, TaskState.todo);

    await service.complete('${reloaded.id}');
    await service.undo();
    final restored = (await repository.find(reloaded.id))!;
    expect(restored.state, TaskState.todo);
    expect(restored.completedAt, isNull);

    await service.complete('${reloaded.id}');
    expect(await service.clearCompleted(), 1);
    await service.undo();
    expect((await repository.find(reloaded.id))!.state, TaskState.done);
  });

  // Undo_RevertsRemoveWithTags
  test('undo restores a removed task with its tags', () async {
    final task = await service.addTask(title: 'tagged', tagsCsv: 'alpha,beta');
    await service.remove('${task.id}');

    await service.undo();

    expect((await repository.find(task.id))!.tags, ['alpha', 'beta']);
  });

  // Undo_RevertsRespawnChain
  test('undo reverts a respawn, then the completion that caused it', () async {
    final task = await service.addTask(title: 'daily', recurrenceName: 'daily');

    await service.complete('${task.id}');
    await service.undo(); // reverts respawn: the spawned occurrence is deleted
    expect(await repository.listAll(), hasLength(1));

    await service.undo(); // reverts done: the original is open again
    final original = (await repository.find(task.id))!;
    expect(original.state, TaskState.todo);
    expect(await repository.listAll(), hasLength(1));
  });

  // Undo_EmptyHistory_Throws
  test('undo with no history throws', () {
    expect(service.undo, throwsStateError);
  });

  // UndoDepth_IsConfigurable
  test('the undo depth is configurable', () async {
    final repo = MemoryTaskRepository();
    final scoped = HaftKhanService(
      repository: repo,
      clock: () => now,
      options: const HaftKhanOptions(maxUndoDepth: 1),
    );
    await scoped.addTask(title: 'one');
    await scoped.addTask(title: 'two');
    await scoped.addTask(title: 'three');

    await scoped.undo(); // reverts "three"
    await expectLater(
      scoped.undo(),
      throwsStateError,
    ); // "one" was trimmed away
  });

  // ── Views ──

  // Board_SplitsColumns_AndCapsDone
  test('board splits three columns and caps the done column', () async {
    final service = HaftKhanService(
      repository: MemoryTaskRepository(),
      clock: () => now,
      options: const HaftKhanOptions(boardTasksPerColumn: 2),
    );
    await service.addTask(title: 'todo');
    final doing = await service.addTask(title: 'doing');
    await service.start('${doing.id}');
    for (var index = 1; index <= 3; index++) {
      final done = await service.addTask(title: 'done$index');
      await service.complete('${done.id}');
    }

    final columns = await service.board();

    expect(columns.map((column) => column.title), ['TODO', 'DOING', 'DONE']);
    expect(columns[0].tasks.map((task) => task.title), ['todo']);
    expect(columns[1].tasks.map((task) => task.title), ['doing']);
    expect(columns[2].tasks, hasLength(2)); // capped at the configured width
  });

  // Matrix_PutsTasksInEisenhowerQuadrants
  test('matrix places tasks in the Eisenhower quadrants', () async {
    await service.addTask(
      title: 'crisis',
      priorityName: 'critical',
      dueDateText: '2026-09-19',
    );
    await service.addTask(title: 'strategy', priorityName: 'high');
    await service.addTask(
      title: 'alarm',
      priorityName: 'low',
      dueDateText: '2026-09-01',
    );
    await service.addTask(title: 'noise');

    final quadrants = await service.matrix();

    expect(quadrants[0].tasks.map((task) => task.title), ['crisis']);
    expect(quadrants[1].tasks.map((task) => task.title), ['strategy']);
    expect(quadrants[2].tasks.map((task) => task.title), ['alarm']);
    expect(quadrants[3].tasks.map((task) => task.title), ['noise']);
  });

  // Report_TracksCompletionsAndStreaks
  test('the report tracks completions and streaks', () async {
    final first = await repository.add(NewTask(title: 'yesterday'));
    await repository.update(
      first.copyWith(
        state: TaskState.done,
        completedAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ),
    );
    final second = await repository.add(NewTask(title: 'today'));
    await repository.update(
      second.copyWith(state: TaskState.done, completedAt: now, updatedAt: now),
    );
    await service.addTask(title: 'open');

    final report = await service.report();

    expect(report.doneToday, 1);
    expect(report.doneLast7Days, 2);
    expect(report.currentStreak, 2);
    expect(report.bestStreak, 2);
    expect(report.focus, hasLength(1));
  });

  // Report_StreakBreaksCorrectly
  test('a gap breaks the current streak but not the best one', () async {
    final old = await repository.add(NewTask(title: 'old'));
    await repository.update(
      old.copyWith(
        state: TaskState.done,
        completedAt: now.subtract(const Duration(days: 3)),
        updatedAt: now,
      ),
    );

    expect((await service.report()).currentStreak, 0);
    expect((await service.report()).bestStreak, 1);
  });

  // ── Import / export ──

  // ExportImport_RoundTripsTasksTagsAndLinks
  test('export then import round-trips tasks, tags and links', () async {
    final source = MemoryTaskRepository();
    final sourceService = HaftKhanService(repository: source, clock: () => now);
    final first = await sourceService.addTask(
      title: 'first',
      notes: 'n1',
      priorityName: 'high',
      dueDateText: '2026-10-01',
      project: 'p',
      tagsCsv: 'x,y',
      effortName: 'l',
      recurrenceName: 'weekly',
    );
    await sourceService.addTask(title: 'second', blockedBy: [first.id]);

    final exported = await sourceService.exportData();
    final backup = BackupFile(
      version: Backup.currentVersion,
      exportedAt: '2026-09-19T00:00:00+00:00',
      tasks: exported.tasks.map(Backup.toDto).toList(),
      dependencies: exported.dependencies
          .map(
            (link) => DependencyDto(
              taskId: link.taskId,
              dependsOnId: link.dependsOnId,
            ),
          )
          .toList(),
    );

    final result = await service.importBackup(backup, replace: false);

    expect(result.tasks, 2);
    expect(result.links, 1);
    final restoredFirst = (await repository.find(
      1,
    ))!; // fresh store: ids restart at 1
    expect(restoredFirst.title, 'first');
    expect(restoredFirst.tags, ['x', 'y']);
    expect(restoredFirst.dueDate, DateOnly(2026, 10, 1));
    expect((await repository.listDependencies()).map((link) => link.taskId), [
      2,
    ]);
  });

  // Import_Replace_ClearsExisting_AndIsUndoable
  test('import with replace clears the store and stays undoable', () async {
    await service.addTask(title: 'old');
    final backup = BackupFile(
      version: Backup.currentVersion,
      exportedAt: '2026-09-19T00:00:00+00:00',
      tasks: [Backup.toDto(makeTask(1, 'imported'))],
      dependencies: const [],
    );

    final result = await service.importBackup(backup, replace: true);

    expect(result.tasks, 1);
    expect((await repository.listAll()).map((task) => task.title), [
      'imported',
    ]);

    await service.undo(); // removes the imported tasks
    expect(await repository.listAll(), isEmpty);

    await service.undo(); // restores what the replace had cleared
    expect((await repository.listAll()).map((task) => task.title), ['old']);
  });

  // Import_RejectsTooManyTasks
  test('import is capped by the configured task rail', () async {
    final service = HaftKhanService(
      repository: repository,
      clock: () => now,
      options: const HaftKhanOptions(maxImportTasks: 1),
    );
    final backup = BackupFile(
      version: Backup.currentVersion,
      exportedAt: '2026-09-19T00:00:00+00:00',
      tasks: [Backup.toDto(makeTask(1, 'a')), Backup.toDto(makeTask(2, 'b'))],
      dependencies: const [],
    );

    await expectLater(
      service.importBackup(backup, replace: false),
      throwsA(isA<RangeError>()),
    );
  });
}

HaftKhanTask makeTask(int id, String title) {
  final now = DateTime.utc(2026, 9, 19);
  return HaftKhanTask(id: id, title: title, createdAt: now, updatedAt: now);
}
