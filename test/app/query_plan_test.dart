/// Query plans, pinned — the phase-11 performance pass.
///
/// A store's schema is only as good as its indices: `SELECT … WHERE sync_id = ?` on a table
/// with no index on `sync_id` is a full scan, and sync runs it **once per event** on every
/// device. This suite records the plans the planner actually chooses, so a query that quietly
/// loses its index (a new `WHERE` clause, a dropped migration) fails here rather than in a
/// user's week-long calendar.
///
/// Before phase 11 the calendar's `sync_id` lookup and filtered list, and the pad's `sync_id`
/// lookup, were `SCAN <table>` (the filtered list also built a temporary B-tree for its
/// `ORDER BY updated_at`). The v2/v3 migrations in `sqlite_taqvim_store.dart` and
/// `sqlite_divan_store.dart` added those indices; the cases below pin the result.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/sqlite_database.dart';
import 'package:jamejam/features/divan/sqlite_divan_store.dart';
import 'package:jamejam/features/taqvim/sqlite_taqvim_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The plan SQLite would run for [sql], as one line.
Future<String> _plan(String path, String sql) async {
  final db = await databaseFactoryFfi.openDatabase(path);
  final rows = await db.rawQuery('EXPLAIN QUERY PLAN $sql', [
    ...List.filled('?'.allMatches(sql).length, 'x'),
  ]);
  await db.close();
  return rows.map((row) => row['detail']).join(' | ');
}

void main() {
  late Directory directory;
  late String calendarPath;
  late String padPath;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('jamejam-plan');
    calendarPath = '${directory.path}/taqvim.db';
    padPath = '${directory.path}/divan.db';
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  group('the calendar', () {
    setUp(() async {
      SqliteBootstrap.ensure();
      final store = SqliteTaqvimStore(calendarPath);
      await store.initialize();
      await store.close();
    });

    test('a sync-identity lookup uses the sync index', () async {
      final plan = await _plan(
        calendarPath,
        "SELECT id FROM events WHERE sync_id = ? AND sync_id != ''",
      );
      expect(plan, contains('idx_events_sync'));
      expect(plan, isNot(startsWith('SCAN events')));
    });

    test(
      'the filtered list is indexed and orders without a temporary B-tree',
      () async {
        final plan = await _plan(
          calendarPath,
          'SELECT id FROM events WHERE calendar = ? ORDER BY updated_at DESC LIMIT 50',
        );
        expect(plan, contains('idx_events_updated'));
        expect(plan, isNot(contains('TEMP B-TREE')));
      },
    );

    test('the whole agenda still comes out of the start-time index', () async {
      final plan = await _plan(
        calendarPath,
        'SELECT id FROM events ORDER BY start_at, id',
      );
      expect(plan, contains('idx_events_start'));
    });

    test('the tombstone sweep reaches events through the sync index', () async {
      final plan = await _plan(
        calendarPath,
        "SELECT sync_id FROM event_tombstones t WHERE t.sync_id != '' AND NOT EXISTS "
        '(SELECT 1 FROM events e WHERE e.sync_id = t.sync_id) ORDER BY t.deleted_at',
      );
      expect(plan, contains('idx_events_sync'));
    });

    test('a v1 file is migrated to v2 and gains the indices', () async {
      // A database as the phase-10 build left it: the tables and one index, stamped v1.
      final v1Path = '${directory.path}/taqvim-v1.db';
      final db = await databaseFactoryFfi.openDatabase(v1Path);
      await db.execute('''
CREATE TABLE events (
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
CREATE INDEX idx_events_start ON events (start_at);
CREATE TABLE event_tombstones (sync_id TEXT PRIMARY KEY, deleted_at TEXT NOT NULL);
CREATE TABLE undo_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    payload    TEXT NOT NULL
);
PRAGMA user_version = 1;
''');
      // One row survives the migration untouched.
      await db.insert('events', {
        'calendar': 'Work',
        'title': 'Standup',
        'start_at': '2026-09-21T09:00:00.000Z',
        'end_at': '2026-09-21T09:15:00.000Z',
        'created_at': '2026-09-01T00:00:00.000Z',
        'updated_at': '2026-09-01T00:00:00.000Z',
        'sync_id': 'abc',
      });
      await db.close();

      final store = SqliteTaqvimStore(v1Path);
      await store.initialize();
      final events = await store.listEvents();
      await store.close();
      expect(events.single.title, 'Standup');

      final version = await _plan(v1Path, 'SELECT 1');
      expect(version, isNotEmpty);
      final db2 = await databaseFactoryFfi.openDatabase(v1Path);
      final rows = await db2.rawQuery('PRAGMA user_version');
      expect(rows.first.values.first, SqliteTaqvimStore.currentSchemaVersion);
      await db2.close();

      final plan = await _plan(
        v1Path,
        "SELECT id FROM events WHERE sync_id = ? AND sync_id != ''",
      );
      expect(plan, contains('idx_events_sync'));
    });
  });

  group('the pad', () {
    setUp(() async {
      SqliteBootstrap.ensure();
      final store = SqliteDivanStore(padPath);
      await store.initialize();
      await store.close();
    });

    test('a sync-identity lookup uses the sync index', () async {
      final plan = await _plan(
        padPath,
        "SELECT id FROM notes WHERE sync_id = ? AND sync_id != ''",
      );
      expect(plan, contains('idx_notes_sync'));
      expect(plan, isNot(startsWith('SCAN notes')));
    });

    test('the tombstone sweep reaches notes through the sync index', () async {
      final plan = await _plan(
        padPath,
        "SELECT sync_id FROM note_tombstones t WHERE t.sync_id != '' AND NOT EXISTS "
        '(SELECT 1 FROM notes n WHERE n.sync_id = t.sync_id) ORDER BY t.deleted_at',
      );
      expect(plan, contains('idx_notes_sync'));
    });

    test('the notebook filter keeps its covering index', () async {
      final plan = await _plan(
        padPath,
        'SELECT id FROM notes WHERE notebook_id = ? ORDER BY id LIMIT 50',
      );
      expect(plan, contains('idx_notes_notebook'));
    });
  });
}
