/// haftkhan — see doc/haftkhan.md and AGENTS.md
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/date_only.dart';
import '../../core/sqlite_database.dart';
import '../../core/uids.dart';
import 'backup.dart';
import 'models.dart';
import 'task_repository.dart';

class SqliteTaskRepository implements TaskRepository {
  SqliteTaskRepository(String databasePath)
    : _database = SqliteDatabase(databasePath);

  /// Current schema version written by this build.
  static const int currentSchemaVersion = 3;

  static const String _selectColumns = '''
id, title, notes, priority, state, due_date, created_at, updated_at, completed_at,
project, effort, recurrence_kind, recurrence_interval, started_at, uid''';

  static const String _createTasksTableSql = '''
CREATE TABLE IF NOT EXISTS tasks (
    id                  INTEGER PRIMARY KEY,
    title               TEXT NOT NULL,
    notes               TEXT NOT NULL,
    priority            INTEGER NOT NULL,
    state               INTEGER NOT NULL,
    due_date            TEXT,
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL,
    completed_at        TEXT,
    project             TEXT NOT NULL DEFAULT '',
    effort              INTEGER NOT NULL DEFAULT 0,
    recurrence_kind     INTEGER NOT NULL DEFAULT 0,
    recurrence_interval INTEGER NOT NULL DEFAULT 1,
    started_at          TEXT,
    uid                 TEXT
);
CREATE INDEX IF NOT EXISTS ix_tasks_state_due ON tasks(state, due_date);''';

  static const String _createAuxTablesSql = '''
CREATE TABLE IF NOT EXISTS task_tags (
    task_id INTEGER NOT NULL,
    tag     TEXT NOT NULL,
    UNIQUE(task_id, tag)
);
CREATE INDEX IF NOT EXISTS ix_task_tags_tag ON task_tags(tag);
CREATE TABLE IF NOT EXISTS task_dependencies (
    task_id     INTEGER NOT NULL,
    depends_on  INTEGER NOT NULL,
    PRIMARY KEY (task_id, depends_on)
);
CREATE TABLE IF NOT EXISTS undo_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    payload    TEXT NOT NULL
);''';

  final SqliteDatabase _database;

  /// Path of the SQLite database file.
  String get databasePath => _database.databasePath;

  /// Opens the store, running the migration script when the on-disk version is older.
  Future<Database> _db() async {
    await _ensureSchema();
    return _database.open();
  }

  Future<void> _ensureSchema() async {
    final db = await _database.open();
    final rows = await db.rawQuery('PRAGMA user_version');
    final current = rows.isEmpty ? 0 : (rows.first.values.first as int?) ?? 0;
    await _database.initialize(_schemaScript(current));
  }

  /// Builds the schema/migration script for a database currently stamped [current].
  static List<String> _schemaScript(int current) {
    if (current > currentSchemaVersion) {
      throw StateError(
        'The database schema (v$current) is newer than this build supports '
        '(v$currentSchemaVersion).',
      );
    }

    final script = <String>[
      ..._splitStatements('$_createTasksTableSql\n$_createAuxTablesSql'),
    ];

    if (current == 1) {
      // Version 1 lacked tags/links/undo and the new task columns — ALTER them in.
      script.addAll(
        _splitStatements('''
ALTER TABLE tasks ADD COLUMN project TEXT NOT NULL DEFAULT '';
ALTER TABLE tasks ADD COLUMN effort INTEGER NOT NULL DEFAULT 0;
ALTER TABLE tasks ADD COLUMN recurrence_kind INTEGER NOT NULL DEFAULT 0;
ALTER TABLE tasks ADD COLUMN recurrence_interval INTEGER NOT NULL DEFAULT 1;
ALTER TABLE tasks ADD COLUMN started_at TEXT;
ALTER TABLE tasks ADD COLUMN uid TEXT;'''),
      );
    } else if (current == 2) {
      // Version 2 predates sync identities — add the uid column.
      script.add('ALTER TABLE tasks ADD COLUMN uid TEXT');
    }

    if (current >= 1 && current < currentSchemaVersion) {
      // Backfill sync identities for rows that predate them, then enforce uniqueness.
      script.addAll(
        _splitStatements('''
UPDATE tasks SET uid = lower(hex(randomblob(16))) WHERE uid IS NULL OR uid = '';
CREATE UNIQUE INDEX IF NOT EXISTS ix_tasks_uid ON tasks(uid);'''),
      );
    }

    script.add('PRAGMA user_version = $currentSchemaVersion');
    return script;
  }

  static List<String> _splitStatements(String script) => script
      .split(';')
      .map((statement) => statement.trim())
      .where((statement) => statement.isNotEmpty)
      .toList();

  /// Reads the schema version stamped in the database (migration diagnostics).
  Future<int> schemaVersionOnDisk() => _database.schemaVersion();

  /// Closes the handle.
  Future<void> close() => _database.close();

  @override
  Future<HaftKhanTask> add(NewTask task) async {
    final db = await _db();
    final now = DateTime.now().toUtc();
    final uid = (task.uid == null || task.uid!.isEmpty)
        ? Uids.newUid()
        : task.uid!;

    late int id;
    await db.transaction((txn) async {
      id = await txn.insert('tasks', {
        'title': task.title,
        'notes': task.notes,
        'priority': task.priority.code,
        'state': TaskState.todo.code,
        'due_date': task.dueDate?.toIso(),
        'created_at': encodeInstant(now),
        'updated_at': encodeInstant(now),
        'completed_at': null,
        'project': task.project,
        'effort': task.effort.code,
        'recurrence_kind': task.recurrence.code,
        'recurrence_interval': task.recurrenceInterval,
        'started_at': null,
        'uid': uid,
      });
      await _insertTags(txn, id, task.tags);
    });

    // Dependency links are validated against the store, so they go in after the task row.
    for (final blocker in task.blockedBy) {
      await addDependency(id, blocker);
    }

    return HaftKhanTask(
      id: id,
      title: task.title,
      notes: task.notes,
      priority: task.priority,
      state: TaskState.todo,
      dueDate: task.dueDate,
      createdAt: now,
      updatedAt: now,
      project: task.project,
      tags: List.unmodifiable(task.tags),
      effort: task.effort,
      recurrence: task.recurrence,
      recurrenceInterval: task.recurrenceInterval,
      uid: uid,
    );
  }

  @override
  Future<HaftKhanTask?> find(int id) async {
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT $_selectColumns FROM tasks WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final task = _mapRow(rows.first);
    return task.copyWith(tags: await _loadTags(db, id));
  }

  @override
  Future<void> update(HaftKhanTask task) async {
    final db = await _db();
    await db.transaction((txn) async {
      final updated = await txn.rawUpdate(
        '''
UPDATE tasks
SET title = ?, notes = ?, priority = ?, state = ?, due_date = ?, updated_at = ?,
    completed_at = ?, project = ?, effort = ?, recurrence_kind = ?,
    recurrence_interval = ?, started_at = ?
WHERE id = ?''',
        [
          task.title,
          task.notes,
          task.priority.code,
          task.state.code,
          task.dueDate?.toIso(),
          encodeInstant(task.updatedAt),
          task.completedAt == null ? null : encodeInstant(task.completedAt!),
          task.project,
          task.effort.code,
          task.recurrence.code,
          task.recurrenceInterval,
          task.startedAt == null ? null : encodeInstant(task.startedAt!),
          task.id,
        ],
      );

      if (updated == 0) {
        throw TaskNotFoundException(task.id);
      }

      await txn.delete('task_tags', where: 'task_id = ?', whereArgs: [task.id]);
      await _insertTags(txn, task.id, task.tags);
    });
  }

  @override
  Future<bool> remove(int id) async {
    final db = await _db();
    var removed = false;
    await db.transaction((txn) async {
      removed = await _exists(txn, id);
      if (removed) {
        await _deleteTask(txn, id);
      }
    });
    return removed;
  }

  @override
  Future<int> removeCompleted() async {
    final db = await _db();
    return db.delete(
      'tasks',
      where: 'state = ?',
      whereArgs: [TaskState.done.code],
    );
  }

  @override
  Future<List<HaftKhanTask>> listOpen() async {
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT $_selectColumns FROM tasks WHERE state != ? '
      'ORDER BY priority DESC, (due_date IS NULL), due_date, id',
      [TaskState.done.code],
    );
    return _readAll(db, rows);
  }

  @override
  Future<List<HaftKhanTask>> listAll() async {
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT $_selectColumns FROM tasks '
      'ORDER BY state, priority DESC, (due_date IS NULL), due_date, id',
    );
    return _readAll(db, rows);
  }

  @override
  Future<List<HaftKhanTask>> listDueOnOrBefore(DateOnly dueDate) async {
    final db = await _db();
    // Rides ix_tasks_state_due: a state range plus a due-date range, no full scan.
    final rows = await db.rawQuery(
      'SELECT $_selectColumns FROM tasks '
      'WHERE state != ? AND due_date IS NOT NULL AND due_date <= ? '
      'ORDER BY due_date, priority DESC, id',
      [TaskState.done.code, dueDate.toIso()],
    );
    return _readAll(db, rows);
  }

  @override
  Future<TaskCounts> countByState(DateOnly today) async {
    final db = await _db();
    final rows = await db.rawQuery(
      '''
SELECT state,
       COUNT(*),
       SUM(CASE WHEN due_date IS NOT NULL AND due_date < ? THEN 1 ELSE 0 END)
FROM tasks
WHERE state != ?
GROUP BY state''',
      [today.toIso(), TaskState.done.code],
    );

    var todo = 0;
    var doing = 0;
    var overdue = 0;
    for (final row in rows) {
      final count = (row.values.elementAt(1) as num).toInt();
      final overdueCount = (row.values.elementAt(2) as num?)?.toInt() ?? 0;
      switch ((row.values.elementAt(0) as num).toInt()) {
        case 0:
          todo = count;
          overdue += overdueCount;
        case 1:
          doing = count;
          overdue += overdueCount;
      }
    }

    final doneRows = await db.rawQuery(
      'SELECT COUNT(*) FROM tasks WHERE state = ?',
      [TaskState.done.code],
    );
    final done = (doneRows.first.values.first as num).toInt();

    return TaskCounts(todo: todo, doing: doing, done: done, overdue: overdue);
  }

  @override
  Future<HaftKhanTask?> findByUid(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'The uid must not be empty.');
    }
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT $_selectColumns FROM tasks WHERE uid = ?',
      [uid],
    );
    if (rows.isEmpty) return null;
    final task = _mapRow(rows.first);
    return task.copyWith(tags: await _loadTags(db, task.id));
  }

  @override
  Future<HaftKhanTask> upsert(HaftKhanTask task) async {
    final db = await _db();
    final uid = task.uid.isEmpty ? Uids.newUid() : task.uid;

    return db.transaction((txn) async {
      final existing = await _findByUidWithin(txn, uid);
      if (existing == null) {
        final idRows = await txn.rawQuery(
          'SELECT COALESCE(MAX(id), 0) + 1 FROM tasks',
        );
        final newId = (idRows.first.values.first as num).toInt();
        await _insertTaskWithId(txn, task.copyWith(id: newId, uid: uid));
        return task.copyWith(id: newId, uid: uid);
      }

      await txn.rawUpdate(
        '''
UPDATE tasks
SET title = ?, notes = ?, priority = ?, state = ?, due_date = ?, created_at = ?, updated_at = ?,
    completed_at = ?, project = ?, effort = ?, recurrence_kind = ?, recurrence_interval = ?,
    started_at = ?
WHERE uid = ?''',
        [
          task.title,
          task.notes,
          task.priority.code,
          task.state.code,
          task.dueDate?.toIso(),
          encodeInstant(task.createdAt),
          encodeInstant(task.updatedAt),
          task.completedAt == null ? null : encodeInstant(task.completedAt!),
          task.project,
          task.effort.code,
          task.recurrence.code,
          task.recurrenceInterval,
          task.startedAt == null ? null : encodeInstant(task.startedAt!),
          uid,
        ],
      );

      await txn.delete(
        'task_tags',
        where: 'task_id = ?',
        whereArgs: [existing.id],
      );
      await _insertTags(txn, existing.id, task.tags);
      return task.copyWith(id: existing.id, uid: uid);
    });
  }

  @override
  Future<void> setDependencies(List<TaskLink> links) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete('task_dependencies');
      final seen = <String>{};
      for (final link in links) {
        final key = '${link.taskId}->${link.dependsOnId}';
        if (!seen.add(key)) continue;
        await txn.insert('task_dependencies', {
          'task_id': link.taskId,
          'depends_on': link.dependsOnId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  @override
  Future<void> addDependency(int taskId, int dependsOnId) async {
    if (taskId == dependsOnId) {
      throw ArgumentError.value(
        dependsOnId,
        'dependsOnId',
        'A task cannot block itself.',
      );
    }

    final db = await _db();
    await db.transaction((txn) async {
      if (!await _exists(txn, taskId) || !await _exists(txn, dependsOnId)) {
        throw ArgumentError(
          'Both tasks must exist to link $taskId → $dependsOnId.',
        );
      }
      await txn.insert('task_dependencies', {
        'task_id': taskId,
        'depends_on': dependsOnId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  @override
  Future<List<TaskLink>> listDependencies() async {
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT task_id, depends_on FROM task_dependencies ORDER BY task_id, depends_on',
    );
    return List.unmodifiable(
      rows.map(
        (row) => TaskLink(
          (row['task_id']! as num).toInt(),
          (row['depends_on']! as num).toInt(),
        ),
      ),
    );
  }

  @override
  Future<void> removeDependenciesFor(int taskId) async {
    final db = await _db();
    await db.rawDelete(
      'DELETE FROM task_dependencies WHERE task_id = ? OR depends_on = ?',
      [taskId, taskId],
    );
  }

  @override
  Future<List<String>> getTags(int taskId) async {
    final db = await _db();
    return _loadTags(db, taskId);
  }

  @override
  Future<void> pushUndo(UndoSnapshot snapshot, {required int maxDepth}) async {
    final db = await _db();
    final payload = jsonEncode(_toSnapshotJson(snapshot));

    await db.transaction((txn) async {
      await txn.insert('undo_log', {
        'created_at': encodeInstant(DateTime.now().toUtc()),
        'payload': payload,
      });

      // Keep only the newest `maxDepth` snapshots.
      await txn.rawDelete(
        '''
DELETE FROM undo_log WHERE id NOT IN (
    SELECT id FROM undo_log ORDER BY id DESC LIMIT ?)''',
        [maxDepth],
      );
    });
  }

  @override
  Future<UndoResult> undo() async {
    final db = await _db();

    return db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT id, payload FROM undo_log ORDER BY id DESC LIMIT 1',
      );
      if (rows.isEmpty) {
        throw StateError('Nothing to undo.');
      }

      final undoId = (rows.first['id']! as num).toInt();
      final snapshot = _fromSnapshotJson(
        jsonDecode(rows.first['payload']! as String) as Map<String, dynamic>,
      );

      for (final createdId in snapshot.createdTaskIds) {
        await _deleteTask(txn, createdId);
      }

      if (snapshot.replaceAll) {
        await txn.delete('tasks');
      }

      final touchedIds = <int>{};
      for (final task in snapshot.tasks) {
        touchedIds.add(task.id);
        await _deleteTask(txn, task.id);
        await _insertTaskWithId(
          txn,
          task,
          tags: snapshot.tags[task.id] ?? task.tags,
        );
      }
      touchedIds.addAll(snapshot.createdTaskIds);

      for (final touchedId in touchedIds) {
        await txn.rawDelete(
          'DELETE FROM task_dependencies WHERE task_id = ? OR depends_on = ?',
          [touchedId, touchedId],
        );
      }

      for (final link in snapshot.dependencies) {
        await txn.insert('task_dependencies', {
          'task_id': link.taskId,
          'depends_on': link.dependsOnId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await txn.rawDelete('DELETE FROM undo_log WHERE id = ?', [undoId]);

      return UndoResult(
        snapshot.operation,
        snapshot.tasks.length + snapshot.createdTaskIds.length,
      );
    });
  }

  // --- helpers -----------------------------------------------------------------

  Future<List<HaftKhanTask>> _readAll(
    DatabaseExecutor db,
    List<Map<String, Object?>> rows,
  ) async {
    final tasks = <HaftKhanTask>[];
    for (final row in rows) {
      final task = _mapRow(row);
      tasks.add(task.copyWith(tags: await _loadTags(db, task.id)));
    }
    return List.unmodifiable(tasks);
  }

  Future<List<String>> _loadTags(DatabaseExecutor db, int taskId) async {
    final rows = await db.query(
      'task_tags',
      columns: ['tag'],
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'tag',
    );
    return List.unmodifiable(rows.map((row) => row['tag']! as String));
  }

  Future<void> _insertTags(
    DatabaseExecutor db,
    int taskId,
    List<String> tags,
  ) async {
    for (final tag in tags) {
      await db.insert('task_tags', {
        'task_id': taskId,
        'tag': tag,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _insertTaskWithId(
    DatabaseExecutor db,
    HaftKhanTask task, {
    List<String>? tags,
  }) async {
    await db.insert('tasks', {
      'id': task.id,
      'title': task.title,
      'notes': task.notes,
      'priority': task.priority.code,
      'state': task.state.code,
      'due_date': task.dueDate?.toIso(),
      'created_at': encodeInstant(task.createdAt),
      'updated_at': encodeInstant(task.updatedAt),
      'completed_at': task.completedAt == null
          ? null
          : encodeInstant(task.completedAt!),
      'project': task.project,
      'effort': task.effort.code,
      'recurrence_kind': task.recurrence.code,
      'recurrence_interval': task.recurrenceInterval,
      'started_at': task.startedAt == null
          ? null
          : encodeInstant(task.startedAt!),
      'uid': task.uid.isEmpty ? Uids.newUid() : task.uid,
    });
    await _insertTags(db, task.id, tags ?? task.tags);
  }

  Future<void> _deleteTask(DatabaseExecutor db, int id) async {
    await db.delete('task_tags', where: 'task_id = ?', whereArgs: [id]);
    await db.rawDelete(
      'DELETE FROM task_dependencies WHERE task_id = ? OR depends_on = ?',
      [id, id],
    );
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> _exists(DatabaseExecutor db, int id) async {
    final rows = await db.rawQuery('SELECT COUNT(*) FROM tasks WHERE id = ?', [
      id,
    ]);
    return (rows.first.values.first as num).toInt() > 0;
  }

  Future<HaftKhanTask?> _findByUidWithin(
    DatabaseExecutor db,
    String uid,
  ) async {
    final rows = await db.rawQuery(
      'SELECT $_selectColumns FROM tasks WHERE uid = ?',
      [uid],
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  static HaftKhanTask _mapRow(Map<String, Object?> row) {
    String? text(Object? value) => value as String?;

    return HaftKhanTask(
      id: (row['id']! as num).toInt(),
      title: row['title']! as String,
      notes: (row['notes'] as String?) ?? '',
      priority: TaskPriority.fromCode((row['priority']! as num).toInt()),
      state: TaskState.fromCode((row['state']! as num).toInt()),
      dueDate: text(row['due_date']) == null
          ? null
          : DateOnly.parseIso(text(row['due_date'])!),
      createdAt: decodeInstant(row['created_at']! as String),
      updatedAt: decodeInstant(row['updated_at']! as String),
      completedAt: text(row['completed_at']) == null
          ? null
          : decodeInstant(text(row['completed_at'])!),
      startedAt: text(row['started_at']) == null
          ? null
          : decodeInstant(text(row['started_at'])!),
      project: (row['project'] as String?) ?? '',
      tags: const [],
      effort: TaskEffort.fromCode((row['effort']! as num).toInt()),
      recurrence: RecurrenceKind.fromCode(
        (row['recurrence_kind']! as num).toInt(),
      ),
      recurrenceInterval: (row['recurrence_interval']! as num).toInt(),
      uid: (row['uid'] as String?) ?? '',
    );
  }

  static Map<String, Object?> _toSnapshotJson(UndoSnapshot snapshot) => {
    'operation': snapshot.operation,
    'tasks': snapshot.tasks.map((task) => Backup.toDto(task).toJson()).toList(),
    'tags': snapshot.tags.map(
      (taskId, tags) => MapEntry(taskId.toString(), tags),
    ),
    'dependencies': snapshot.dependencies
        .map(
          (link) => DependencyDto(
            taskId: link.taskId,
            dependsOnId: link.dependsOnId,
          ).toJson(),
        )
        .toList(),
    'createdTaskIds': snapshot.createdTaskIds,
    'replaceAll': snapshot.replaceAll,
  };

  static UndoSnapshot _fromSnapshotJson(Map<String, dynamic> json) =>
      UndoSnapshot(
        operation: json['operation'] as String,
        tasks: ((json['tasks'] as List?) ?? const [])
            .map(
              (task) => Backup.fromDto(
                TaskDto.fromJson((task as Map).cast<String, dynamic>()),
              ),
            )
            .toList(),
        tags: ((json['tags'] as Map?) ?? const {}).map(
          (key, value) => MapEntry(
            int.parse(key as String),
            (value as List).cast<String>(),
          ),
        ),
        dependencies: ((json['dependencies'] as List?) ?? const [])
            .map(
              (link) => TaskLink(
                ((link as Map)['taskId']! as num).toInt(),
                (link['dependsOnId']! as num).toInt(),
              ),
            )
            .toList(),
        createdTaskIds: ((json['createdTaskIds'] as List?) ?? const [])
            .map((id) => (id as num).toInt())
            .toList(),
        replaceAll: (json['replaceAll'] as bool?) ?? false,
      );

  /// Stores an instant the way the .NET side does: ISO-8601, UTC, culture-invariant.
  static String encodeInstant(DateTime value) =>
      value.toUtc().toIso8601String();

  /// Reads an instant written by [encodeInstant] (or by the .NET `"O"` formatter).
  static DateTime decodeInstant(String value) => DateTime.parse(value).toUtc();
}
