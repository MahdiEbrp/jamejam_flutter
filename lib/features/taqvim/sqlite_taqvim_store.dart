/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/sqlite_database.dart';
import '../../core/uids.dart';
import 'models.dart';
import 'taqvim_defaults.dart';
import 'taqvim_store.dart';

class SqliteTaqvimStore implements TaqvimStore {
  SqliteTaqvimStore(String databasePath)
    : _database = SqliteDatabase(databasePath);

  /// Current schema version written by this build.
  ///
  /// v2 added the two indices the query planner was missing — see [_migrateToV2Sql].
  static const int currentSchemaVersion = 2;

  static const String _tableSql = '''
CREATE TABLE IF NOT EXISTS events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    calendar    TEXT NOT NULL DEFAULT 'Personal',
    title       TEXT NOT NULL,
    location    TEXT NOT NULL DEFAULT '',
    notes       TEXT NOT NULL DEFAULT '',
    tags        TEXT NOT NULL DEFAULT '',
    start_at    TEXT NOT NULL,
    end_at      TEXT NOT NULL,
    is_allday   INTEGER NOT NULL DEFAULT 0,
    rule        TEXT,
    reminders   TEXT NOT NULL DEFAULT '',
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    sync_id     TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_events_start ON events (start_at);
CREATE INDEX IF NOT EXISTS idx_events_sync ON events (sync_id);
CREATE INDEX IF NOT EXISTS idx_events_updated ON events (updated_at);
CREATE TABLE IF NOT EXISTS event_tombstones (
    sync_id    TEXT PRIMARY KEY,
    deleted_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS undo_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    payload    TEXT NOT NULL
);
''';

  /// v1 → v2: the sync and updated-at indices the planner was missing.
  static const String _migrateToV2Sql = '''
CREATE INDEX IF NOT EXISTS idx_events_sync ON events (sync_id);
CREATE INDEX IF NOT EXISTS idx_events_updated ON events (updated_at);
PRAGMA user_version = 2;''';

  static const String _ftsSql = '''
CREATE VIRTUAL TABLE IF NOT EXISTS event_fts USING fts5(title, notes, location, content='events', content_rowid='id');
CREATE TRIGGER IF NOT EXISTS events_ai AFTER INSERT ON events BEGIN
    INSERT INTO event_fts(rowid, title, notes, location) VALUES (new.id, new.title, new.notes, new.location);
END;
CREATE TRIGGER IF NOT EXISTS events_ad AFTER DELETE ON events BEGIN
    INSERT INTO event_fts(event_fts, rowid, title, notes, location) VALUES ('delete', old.id, old.title, old.notes, old.location);
END;
CREATE TRIGGER IF NOT EXISTS events_au AFTER UPDATE ON events BEGIN
    INSERT INTO event_fts(event_fts, rowid, title, notes, location) VALUES ('delete', old.id, old.title, old.notes, old.location);
    INSERT INTO event_fts(rowid, title, notes, location) VALUES (new.id, new.title, new.notes, new.location);
END;
''';

  static const String _selectEvents =
      'SELECT id, calendar, title, location, notes, tags, start_at, end_at, '
      'is_allday, rule, reminders, created_at, updated_at, sync_id FROM events';

  final SqliteDatabase _database;
  Database? _db;

  int _undoDepthValue = TaqvimDefaults.undoDepth;

  /// True while the engine supports FTS5; flipped off permanently the first time it does not.
  bool _fts = true;

  @override
  int get undoDepth => _undoDepthValue;

  @override
  set undoDepth(int value) {
    if (value < 0) {
      throw const TaqvimException('UndoDepth must not be negative.');
    }
    _undoDepthValue = value;
  }

  /// Creates the file, the schema and the FTS index (idempotent).
  ///
  /// Mirrors the .NET `Schema` hook: an existing file (`user_version` at the current schema)
  /// is only *probed* for FTS — the index is never recreated behind a live store, so an engine
  /// whose FTS table went missing degrades to LIKE instead of silently searching an empty index.
  Future<void> initialize() async {
    _db ??= await _database.open();
    final db = _db!;
    final version = await _database.schemaVersion();
    if (version >= currentSchemaVersion) {
      _fts = await _probeFts(db);
      return;
    }

    // A v1 file has the tables but not the indices the planner needs: `sync_id` lookups
    // (every sync run, per event) and the filtered list's `ORDER BY updated_at` were both
    // full scans plus a temporary b-tree. `EXPLAIN QUERY PLAN` before and after is recorded
    // in `test/features/taqvim/taqvim_store_index_test.dart`.
    if (version == 1) {
      await db.execute(_migrateToV2Sql);
      _fts = await _probeFts(db);
      return;
    }

    await _database.initialize([_tableSql, 'PRAGMA user_version = 2']);
    try {
      await db.execute(_ftsSql);
      _fts = await _probeFts(db);
    } on DatabaseException {
      _fts = false; // an engine without FTS5 — the LIKE fallback covers it
    }
  }

  /// Closes the underlying database handle.
  Future<void> close() async {
    await _database.close();
    _db = null;
  }

  // ── Event CRUD ──

  @override
  Future<TaqvimEvent> addEvent(TaqvimEvent event) async {
    final db = await _open();
    final identity = event.syncId.isEmpty ? Uids.newUid() : event.syncId;
    final id = await db.insert('events', {
      'calendar': event.calendar,
      'title': event.title,
      'location': event.location,
      'notes': event.notes,
      'tags': event.tags,
      'start_at': _stamp(event.start),
      'end_at': _stamp(event.end),
      'is_allday': event.isAllDay ? 1 : 0,
      'rule': _ruleToJson(event.rule),
      'reminders': TaqvimText.remindersToCsv(event.reminders),
      'created_at': _stamp(event.createdAt),
      'updated_at': _stamp(event.updatedAt),
      'sync_id': identity,
    });
    return event.copyWith(id: id, syncId: identity);
  }

  @override
  Future<void> updateEvent(TaqvimEvent event) async {
    final db = await _open();
    final rows = await db.update(
      'events',
      {
        'calendar': event.calendar,
        'title': event.title,
        'location': event.location,
        'notes': event.notes,
        'tags': event.tags,
        'start_at': _stamp(event.start),
        'end_at': _stamp(event.end),
        'is_allday': event.isAllDay ? 1 : 0,
        'rule': _ruleToJson(event.rule),
        'reminders': TaqvimText.remindersToCsv(event.reminders),
        'created_at': _stamp(event.createdAt),
        'updated_at': _stamp(event.updatedAt),
        'sync_id': event.syncId,
      },
      where: 'id = ?',
      whereArgs: [event.id],
    );
    if (rows == 0) {
      throw TaqvimException('No event #${event.id}.');
    }
  }

  @override
  Future<bool> removeEvent(int id, DateTime deletedAt) async {
    final db = await _open();
    await db.rawInsert(
      'INSERT INTO event_tombstones (sync_id, deleted_at) '
      "SELECT sync_id, ? FROM events WHERE id = ? AND sync_id != '' "
      'ON CONFLICT (sync_id) DO UPDATE SET deleted_at = excluded.deleted_at',
      [_stamp(deletedAt), id],
    );
    final rows = await db.delete('events', where: 'id = ?', whereArgs: [id]);
    return rows > 0;
  }

  @override
  Future<TaqvimEvent?> findEvent(int id) async {
    final db = await _open();
    final rows = await db.rawQuery('$_selectEvents WHERE id = ?', [id]);
    return rows.isEmpty ? null : _mapEvent(rows.first);
  }

  @override
  Future<List<TaqvimEvent>> listEvents() async {
    final db = await _open();
    final rows = await db.rawQuery('$_selectEvents ORDER BY start_at, id');
    return [for (final row in rows) _mapEvent(row)];
  }

  // ── Search ──

  @override
  Future<List<int>> searchIds(String query, int limit) async {
    if (query.trim().isEmpty) {
      throw const TaqvimException('A search query must not be empty.');
    }

    final db = await _open();
    final terms = query
        .split(' ')
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList();

    if (_fts) {
      try {
        final rows = await db.rawQuery(
          'SELECT rowid FROM event_fts WHERE event_fts MATCH ? ORDER BY rank LIMIT ?',
          [_ftsQuery(terms), limit],
        );
        return [for (final row in rows) (row['rowid'] as num).toInt()];
      } on DatabaseException {
        _fts = false; // engine lost FTS mid-flight — fall through to LIKE
      }
    }

    // LIKE fallback: every term must appear in title/notes/location (AND semantics).
    final conditions = StringBuffer();
    final args = <Object?>[];
    for (var i = 0; i < terms.length; i++) {
      conditions
        ..write(i == 0 ? 'WHERE ' : ' AND ')
        ..write(
          "(title LIKE ? ESCAPE '[' OR notes LIKE ? ESCAPE '[' "
          "OR location LIKE ? ESCAPE '[')",
        );
      final needle = '%${_escapeLike(terms[i])}%';
      args.addAll([needle, needle, needle]);
    }
    args.add(limit);

    final rows = await db.rawQuery(
      'SELECT id FROM events $conditions ORDER BY updated_at DESC LIMIT ?',
      args,
    );
    return [for (final row in rows) (row['id'] as num).toInt()];
  }

  // ── Bulk & undo ──

  @override
  Future<void> replaceEvents(List<TaqvimEvent> events) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('events');
      if (_fts) {
        await txn.rawInsert(
          "INSERT INTO event_fts(event_fts) VALUES('rebuild')",
        );
      }
      for (final event in events) {
        await txn.insert('events', {
          'id': event.id,
          'calendar': event.calendar,
          'title': event.title,
          'location': event.location,
          'notes': event.notes,
          'tags': event.tags,
          'start_at': _stamp(event.start),
          'end_at': _stamp(event.end),
          'is_allday': event.isAllDay ? 1 : 0,
          'rule': _ruleToJson(event.rule),
          'reminders': TaqvimText.remindersToCsv(event.reminders),
          'created_at': _stamp(event.createdAt),
          'updated_at': _stamp(event.updatedAt),
          'sync_id': event.syncId.isEmpty ? Uids.newUid() : event.syncId,
        });
      }

      // Restored events retract their tombstones.
      await txn.rawDelete(
        "DELETE FROM event_tombstones WHERE sync_id IN "
        "(SELECT sync_id FROM events WHERE sync_id != '')",
      );
    });
  }

  @override
  Future<void> pushUndo(String payload) async {
    if (payload.trim().isEmpty) {
      throw const TaqvimException('An undo snapshot must not be empty.');
    }
    final db = await _open();
    await db.insert('undo_log', {
      'created_at': _stamp(DateTime.now().toUtc()),
      'payload': payload,
    });
    if (_undoDepthValue == 0) {
      await db.delete('undo_log');
      return;
    }
    await db.rawDelete(
      'DELETE FROM undo_log WHERE id < '
      '(SELECT MIN(id) FROM (SELECT id FROM undo_log ORDER BY id DESC LIMIT ?))',
      [_undoDepthValue],
    );
  }

  @override
  Future<String?> popUndo() async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT payload FROM undo_log ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) return null;
    final payload = rows.first['payload'] as String;
    await db.rawDelete(
      'DELETE FROM undo_log WHERE id = (SELECT MAX(id) FROM undo_log)',
    );
    return payload;
  }

  @override
  Future<int> get undoCount async {
    final db = await _open();
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM undo_log');
    return (rows.first['n'] as num).toInt();
  }

  // ── Tombstones ──

  @override
  Future<List<TaqvimTombstone>> getTombstones() async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT t.sync_id, t.deleted_at FROM event_tombstones t '
      "WHERE t.sync_id != '' AND NOT EXISTS "
      '(SELECT 1 FROM events e WHERE e.sync_id = t.sync_id) '
      'ORDER BY t.deleted_at',
    );
    return [
      for (final row in rows)
        TaqvimTombstone(
          syncId: row['sync_id'] as String,
          deletedAt: DateTime.parse(row['deleted_at'] as String).toUtc(),
        ),
    ];
  }

  @override
  Future<void> upsertTombstone(TaqvimTombstone tombstone) async {
    if (tombstone.syncId.isEmpty) return;
    final db = await _open();
    await db.rawInsert(
      'INSERT INTO event_tombstones (sync_id, deleted_at) VALUES (?, ?) '
      'ON CONFLICT (sync_id) DO UPDATE SET deleted_at = excluded.deleted_at',
      [tombstone.syncId, _stamp(tombstone.deletedAt)],
    );
  }

  // ── Plumbing ──

  Future<Database> _open() async {
    if (_db == null) await initialize();
    return _db!;
  }

  Future<bool> _probeFts(Database db) async {
    try {
      await db.rawQuery('SELECT rowid FROM event_fts LIMIT 1');
      return true;
    } on DatabaseException {
      return false;
    }
  }

  static String _stamp(DateTime instant) => instant.toUtc().toIso8601String();

  static String? _ruleToJson(Recurrence? rule) =>
      rule == null ? null : jsonEncode(TaqvimJson.ruleToJson(rule));

  static Recurrence? _ruleFromJson(String? json) {
    if (json == null || json.trim().isEmpty) return null;
    try {
      return TaqvimJson.ruleFromJson(jsonDecode(json));
    } on FormatException {
      return null;
    }
  }

  static String _ftsQuery(List<String> terms) =>
      terms.map((term) => '"${term.replaceAll('"', '""')}"').join(' ');

  static String _escapeLike(String text) =>
      text.replaceAll('[', '[[').replaceAll('%', '[%').replaceAll('_', '[_');

  static TaqvimEvent _mapEvent(Map<String, Object?> row) => TaqvimEvent(
    id: (row['id'] as num).toInt(),
    calendar: row['calendar'] as String,
    title: row['title'] as String,
    location: row['location'] as String,
    notes: row['notes'] as String,
    tags: row['tags'] as String,
    start: DateTime.parse(row['start_at'] as String).toUtc(),
    end: DateTime.parse(row['end_at'] as String).toUtc(),
    isAllDay: (row['is_allday'] as num).toInt() != 0,
    rule: _ruleFromJson(row['rule'] as String?),
    reminders: TaqvimText.remindersFromCsv(row['reminders'] as String),
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    syncId: (row['sync_id'] as String?) ?? '',
  );
}
