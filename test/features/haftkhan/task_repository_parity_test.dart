// Parity port of tests/JameJam.Tests/HaftKhan/MemoryTaskRepositoryTests.cs (3 cases) and
// HaftKhan/SqliteTaskRepositoryTests.cs (16 cases).
//
// The .NET suite has one file per store; where the two overlap the shared contract runs
// against both, and the store-specific cases follow — the same coverage without writing
// every case twice. The SQLite half uses a real file, exactly like the original
// TempDatabase fixture, because "undo survives a restart" is the behaviour under test.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/core/sqlite_database.dart';
import 'package:jamejam/features/haftkhan/models.dart';
import 'package:jamejam/features/haftkhan/sqlite_task_repository.dart';
import 'package:jamejam/features/haftkhan/task_repository.dart';

/// Everything a task store must do, run against both implementations.
void sharedRepositoryContract(
  String name,
  Future<TaskRepository> Function() create, {
  required Future<void> Function(TaskRepository repository) dispose,
}) {
  group('$name repository contract', () {
    late TaskRepository repository;

    setUp(() async => repository = await create());
    tearDown(() async => dispose(repository));

    // Add_AssignsSequentialIds / Add_AssignsSequentialIds_AndStoresFields
    test('add assigns sequential ids starting at one', () async {
      final first = await repository.add(
        NewTask(
          title: 'first',
          notes: 'notes',
          priority: TaskPriority.high,
          dueDate: const DateOnly(2026, 9, 25),
        ),
      );
      final second = await repository.add(NewTask(title: 'second'));

      expect(first.id, 1);
      expect(second.id, 2);
    });

    // Find_Missing_ReturnsNull
    test('find on a missing id returns null', () async {
      expect(await repository.find(123), isNull);
    });

    // Update_PersistsEveryField
    test('update persists every field', () async {
      final added = await repository.add(NewTask(title: 'before'));
      final completedAt = DateTime.utc(2026, 9, 19, 10);

      await repository.update(
        added.copyWith(
          title: 'after',
          notes: 'now with notes',
          priority: TaskPriority.critical,
          state: TaskState.done,
          dueDate: const DateOnly(2026, 12, 1),
          updatedAt: completedAt,
          completedAt: completedAt,
        ),
      );
      final stored = (await repository.find(added.id))!;

      expect(stored.title, 'after');
      expect(stored.notes, 'now with notes');
      expect(stored.priority, TaskPriority.critical);
      expect(stored.state, TaskState.done);
      expect(stored.dueDate, const DateOnly(2026, 12, 1));
      expect(stored.completedAt, completedAt);
    });

    // Update_MissingTask_ThrowsNotFound / Update_UnknownTask_ThrowsNotFound
    test('updating a missing task throws not-found', () async {
      await expectLater(
        repository.update(makeTask(id: 555)),
        throwsA(isA<TaskNotFoundException>()),
      );
    });

    // Remove_ReportsExistence
    test('remove reports whether the task existed', () async {
      final task = await repository.add(NewTask(title: 't'));

      expect(await repository.remove(task.id), isTrue);
      expect(await repository.remove(task.id), isFalse);
      expect(await repository.find(task.id), isNull);
    });

    // RemoveCompleted_RemovesOnlyDoneTasks
    test('removeCompleted deletes only finished tasks', () async {
      final open = await repository.add(NewTask(title: 'open'));
      final done = await repository.add(NewTask(title: 'done'));
      await repository.update(
        done.copyWith(
          state: TaskState.done,
          completedAt: DateTime.utc(2026, 9, 19),
        ),
      );

      expect(await repository.removeCompleted(), 1);
      expect(await repository.find(open.id), isNotNull);
      expect(await repository.find(done.id), isNull);
    });

    // ListOpen_SortsByPriorityThenDue
    test('the open list sorts by priority, then due date, then id', () async {
      final low = await repository.add(
        NewTask(title: 'low', priority: TaskPriority.low),
      );
      final criticalLater = await repository.add(
        NewTask(
          title: 'crit-later',
          priority: TaskPriority.critical,
          dueDate: const DateOnly(2026, 10, 1),
        ),
      );
      final criticalSooner = await repository.add(
        NewTask(
          title: 'crit-sooner',
          priority: TaskPriority.critical,
          dueDate: const DateOnly(2026, 9, 20),
        ),
      );

      expect((await repository.listOpen()).map((task) => task.id), [
        criticalSooner.id,
        criticalLater.id,
        low.id,
      ]);
    });

    // ListOpen_ExcludesDone
    test('the open list excludes finished tasks', () async {
      final open = await repository.add(NewTask(title: 'open'));
      final done = await repository.add(NewTask(title: 'done'));
      await repository.update(
        done.copyWith(
          state: TaskState.done,
          completedAt: DateTime.utc(2026, 9, 19),
        ),
      );

      expect((await repository.listOpen()).map((task) => task.id), [open.id]);
    });

    // ListAll_GroupsByStateThenPriority
    test('the full list groups by state, then priority', () async {
      final open = await repository.add(
        NewTask(title: 'open', priority: TaskPriority.low),
      );
      final done = await repository.add(
        NewTask(title: 'done', priority: TaskPriority.critical),
      );
      await repository.update(
        done.copyWith(
          state: TaskState.done,
          completedAt: DateTime.utc(2026, 9, 19),
        ),
      );

      expect(
        (await repository.listAll()).map((task) => task.id),
        [open.id, done.id], // open (todo) sorts before done
      );
    });

    // ListDueOnOrBefore_RangeQuery_IsSortedAndFiltered
    test('the due-range query is sorted and filtered', () async {
      final overdue = await repository.add(
        NewTask(title: 'overdue', dueDate: const DateOnly(2026, 9, 1)),
      );
      final boundary = await repository.add(
        NewTask(
          title: 'boundary',
          priority: TaskPriority.high,
          dueDate: const DateOnly(2026, 9, 19),
        ),
      );
      await repository.add(
        NewTask(
          title: 'future',
          priority: TaskPriority.critical,
          dueDate: const DateOnly(2026, 9, 30),
        ),
      );
      final donePast = await repository.add(
        NewTask(title: 'done-past', dueDate: const DateOnly(2026, 8, 1)),
      );
      await repository.update(
        donePast.copyWith(
          state: TaskState.done,
          completedAt: DateTime.utc(2026, 9, 19),
        ),
      );

      expect(
        (await repository.listDueOnOrBefore(
          const DateOnly(2026, 9, 19),
        )).map((task) => task.id),
        [overdue.id, boundary.id],
      );
    });

    // CountByState_GroupsStates_CountsOverdue
    test('counting groups states and counts overdue tasks', () async {
      await repository.add(
        NewTask(title: 'todo', dueDate: const DateOnly(2026, 8, 1)),
      ); // overdue
      final doing = await repository.add(
        NewTask(title: 'doing', dueDate: const DateOnly(2026, 8, 2)),
      ); // overdue
      await repository.update(
        doing.copyWith(
          state: TaskState.doing,
          updatedAt: DateTime.utc(2026, 9, 19),
        ),
      );
      await repository.add(
        NewTask(title: 'open', dueDate: const DateOnly(2026, 12, 1)),
      ); // not overdue
      final done = await repository.add(
        NewTask(title: 'done', dueDate: const DateOnly(2026, 8, 3)),
      );
      await repository.update(
        done.copyWith(
          state: TaskState.done,
          completedAt: DateTime.utc(2026, 9, 19),
        ),
      );

      final counts = await repository.countByState(const DateOnly(2026, 9, 19));

      expect(
        (counts.todo, counts.doing, counts.done, counts.overdue),
        (2, 1, 1, 2),
      );
      expect(counts.total, 4);
    });

    // AddDependency_ValidatesExistenceAndSelf
    test('adding a dependency validates existence and self-links', () async {
      final task = await repository.add(NewTask(title: 't'));

      await expectLater(
        repository.addDependency(task.id, 999),
        throwsArgumentError,
      );
      await expectLater(
        repository.addDependency(999, task.id),
        throwsArgumentError,
      );
      expect(
        () => repository.addDependency(task.id, task.id),
        throwsArgumentError,
      );
    });

    // Tags_Dependencies_AndUndo_PersistAcrossInstances (the store-agnostic half)
    test('tags round-trip with their task', () async {
      final first = await repository.add(
        NewTask(
          title: 'tagged',
          priority: TaskPriority.high,
          tags: const ['one', 'two'],
          project: 'home',
          effort: TaskEffort.medium,
          recurrence: RecurrenceKind.weekly,
          recurrenceInterval: 3,
        ),
      );

      final stored = (await repository.find(first.id))!;

      expect(stored.tags, ['one', 'two']);
      expect(stored.project, 'home');
      expect(stored.effort, TaskEffort.medium);
      expect(stored.recurrence, RecurrenceKind.weekly);
      expect(stored.recurrenceInterval, 3);
      expect(await repository.getTags(first.id), ['one', 'two']);
    });

    // Undo_EmptyHistory_Throws
    test('undo with no history throws', () async {
      await expectLater(repository.undo(), throwsA(isA<StateError>()));
    });
  });
}

void main() {
  sharedRepositoryContract(
    'memory',
    () async => MemoryTaskRepository(),
    dispose: (repository) async {},
  );

  late Directory root;
  SqliteBootstrap.ensure();

  sharedRepositoryContract(
    'SQLite',
    () async {
      root = Directory.systemTemp.createTempSync('jamejam-haftkhan-parity');
      return SqliteTaskRepository('${root.path}/tasks.db');
    },
    dispose: (repository) async {
      await (repository as SqliteTaskRepository).close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    },
  );

  group('SqliteTaskRepository parity — file-backed behaviours', () {
    late Directory temp;
    late SqliteTaskRepository repository;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('jamejam-haftkhan-sqlite');
      repository = SqliteTaskRepository('${temp.path}/tasks.db');
    });

    tearDown(() async {
      await repository.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    // Data_PersistsAcrossRepositoryInstances
    test('data persists across repository instances', () async {
      final task = await repository.add(
        NewTask(title: 'durable', priority: TaskPriority.high),
      );

      final reopened = SqliteTaskRepository('${temp.path}/tasks.db');
      addTearDown(reopened.close);

      expect((await reopened.find(task.id))!.title, 'durable');
    });

    // Tags_Dependencies_AndUndo_PersistAcrossInstances
    test('tags, dependencies and undo persist across instances', () async {
      final first = await repository.add(
        NewTask(
          title: 'tagged',
          priority: TaskPriority.high,
          tags: const ['one', 'two'],
          project: 'home',
          effort: TaskEffort.medium,
          recurrence: RecurrenceKind.weekly,
          recurrenceInterval: 3,
        ),
      );
      final second = await repository.add(NewTask(title: 'blocked'));
      await repository.addDependency(second.id, first.id);

      final reopened = SqliteTaskRepository('${temp.path}/tasks.db');
      addTearDown(reopened.close);
      final stored = (await reopened.find(first.id))!;
      expect(stored.tags, ['one', 'two']);
      expect(stored.project, 'home');
      expect(stored.effort, TaskEffort.medium);
      expect(stored.recurrence, RecurrenceKind.weekly);
      expect(stored.recurrenceInterval, 3);
      expect(
        await reopened.listDependencies(),
        contains(TaskLink(second.id, first.id)),
      );
      expect(await reopened.getTags(first.id), ['one', 'two']);

      // Undo persists too: push a removal snapshot, reopen, undo → task restored.
      await reopened.pushUndo(
        UndoSnapshot(
          operation: 'remove',
          tasks: [stored],
          tags: {
            first.id: const ['one', 'two'],
          },
          dependencies: [TaskLink(second.id, first.id)],
          createdTaskIds: const [],
          replaceAll: false,
        ),
        maxDepth: 50,
      );
      expect(await reopened.remove(first.id), isTrue);

      final reuser = SqliteTaskRepository('${temp.path}/tasks.db');
      addTearDown(reuser.close);
      final result = await reuser.undo();
      expect(result.operation, 'remove');
      expect(await reuser.find(first.id), isNotNull);
      expect(await reuser.getTags(first.id), ['one', 'two']);
      expect(
        await reuser.listDependencies(),
        contains(TaskLink(second.id, first.id)),
      );
    });

    // RecurrenceFields_RoundTrip
    test('recurrence fields round-trip', () async {
      final added = await repository.add(
        NewTask(
          title: 'daily',
          recurrence: RecurrenceKind.daily,
          recurrenceInterval: 4,
        ),
      );
      final startedAt = DateTime.utc(2026, 9, 19, 10);
      await repository.update(
        added.copyWith(
          state: TaskState.doing,
          startedAt: startedAt,
          updatedAt: startedAt,
        ),
      );

      final stored = (await repository.find(added.id))!;
      expect(stored.recurrence, RecurrenceKind.daily);
      expect(stored.recurrenceInterval, 4);
      expect(stored.startedAt, isNotNull);
    });

    // DatabaseFile_IsOwnerOnly_OnUnix
    test('the database file is readable by the owner only', () async {
      await repository.add(NewTask(title: 'touch')); // forces file creation

      if (!Platform.isLinux && !Platform.isMacOS) {
        return; // Unix-only hardening check
      }

      final mode = File('${temp.path}/tasks.db').statSync().mode & 0x1FF;
      expect(
        mode & 0x077,
        0,
        reason:
            'The task database must be readable/writable by the owner only.',
      );
    });

    // Schema versioning — the migration seam the .NET store calls SchemaFactory.
    test('the schema is stamped at version 3', () async {
      await repository.add(NewTask(title: 'touch'));

      expect(await repository.schemaVersionOnDisk(), 3);
      expect(SqliteTaskRepository.currentSchemaVersion, 3);
    });

    test('a version-2 database gains uids and the current schema on open', () async {
      // Build a v2 store by hand: every column except the sync identity.
      final raw = SqliteDatabase('${temp.path}/legacy.db');
      final db = await raw.open();
      await db.execute(
        'CREATE TABLE tasks ('
        'id INTEGER PRIMARY KEY, title TEXT NOT NULL, notes TEXT NOT NULL, '
        'priority INTEGER NOT NULL, state INTEGER NOT NULL, due_date TEXT, '
        'created_at TEXT NOT NULL, updated_at TEXT NOT NULL, completed_at TEXT, '
        "project TEXT NOT NULL DEFAULT '', effort INTEGER NOT NULL DEFAULT 0, "
        'recurrence_kind INTEGER NOT NULL DEFAULT 0, '
        'recurrence_interval INTEGER NOT NULL DEFAULT 1, started_at TEXT)',
      );
      await db.execute(
        'INSERT INTO tasks(id, title, notes, priority, state, created_at, updated_at) '
        "VALUES(1, 'legacy', '', 1, 0, "
        "'2026-09-19T00:00:00.000Z', '2026-09-19T00:00:00.000Z')",
      );
      await db.execute('PRAGMA user_version = 2');
      await raw.close();

      final migrated = SqliteTaskRepository('${temp.path}/legacy.db');
      addTearDown(migrated.close);
      final tasks = await migrated.listAll();

      expect(await migrated.schemaVersionOnDisk(), 3);
      expect(tasks, hasLength(1));
      expect(tasks.single.title, 'legacy');
      // The migration backfills a sync identity so the row can take part in sync.
      expect(tasks.single.uid, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(await migrated.findByUid(tasks.single.uid), isNotNull);
    });

    // A database from a newer build must be refused, not silently downgraded.
    test('a newer schema than this build supports is refused', () async {
      final raw = SqliteDatabase('${temp.path}/future.db');
      final db = await raw.open();
      await db.execute('PRAGMA user_version = 99');
      await raw.close();

      final future = SqliteTaskRepository('${temp.path}/future.db');
      addTearDown(future.close);

      await expectLater(future.listAll(), throwsA(isA<StateError>()));
    });
  });
}

HaftKhanTask makeTask({required int id}) {
  final now = DateTime.utc(2026, 9, 19);
  return HaftKhanTask(id: id, title: 't', createdAt: now, updatedAt: now);
}
