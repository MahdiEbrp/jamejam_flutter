/// divan — see doc/divan.md and AGENTS.md
import 'package:sqflite/sqflite.dart';

import '../../core/sqlite_database.dart';
import '../../core/uids.dart';
import 'divan_defaults.dart';
import 'divan_store.dart';
import 'models.dart';

class SqliteDivanStore implements DivanStore {
  SqliteDivanStore(String databasePath)
    : _database = SqliteDatabase(databasePath);

  /// Current schema version written by this build.
  static const int currentSchemaVersion = 3;

  static const String _selectNotes =
      'SELECT id, notebook_id, title, body, tags, pinned, archived, '
      'created_at, updated_at, sync_id FROM notes';

  static const String _baseSchemaSql = '''
CREATE TABLE IF NOT EXISTS notebooks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    created_at  TEXT NOT NULL,
    is_archived INTEGER NOT NULL DEFAULT 0,
    updated_at  TEXT
);
CREATE TABLE IF NOT EXISTS notes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    notebook_id INTEGER NOT NULL,
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    tags        TEXT NOT NULL,
    pinned      INTEGER NOT NULL DEFAULT 0,
    archived    INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    sync_id     TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_notes_notebook ON notes (notebook_id);
CREATE INDEX IF NOT EXISTS idx_notes_sync ON notes (sync_id);
CREATE TABLE IF NOT EXISTS note_tombstones (
    sync_id    TEXT PRIMARY KEY,
    deleted_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS undo_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    payload    TEXT NOT NULL
);
PRAGMA user_version = 3;''';

  static const String _ftsSchemaSql = '''
CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(title, body, content='notes', content_rowid='id');
CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
    INSERT INTO notes_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;
CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
    INSERT INTO notes_fts(notes_fts, rowid, title, body) VALUES ('delete', old.id, old.title, old.body);
END;
CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
    INSERT INTO notes_fts(notes_fts, rowid, title, body) VALUES ('delete', old.id, old.title, old.body);
    INSERT INTO notes_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;''';

  /// v2 → v3: the sync-identity index every sync run was scanning for.
  static const String _migrateToV3Sql = '''
CREATE INDEX IF NOT EXISTS idx_notes_sync ON notes (sync_id);
PRAGMA user_version = 3;''';

  static const String _migrateToV2Sql = '''
ALTER TABLE notes ADD COLUMN sync_id TEXT NOT NULL DEFAULT '';
UPDATE notes SET sync_id = lower(hex(randomblob(16))) WHERE sync_id = '';
ALTER TABLE notebooks ADD COLUMN updated_at TEXT;
UPDATE notebooks SET updated_at = created_at WHERE updated_at IS NULL;
CREATE TABLE IF NOT EXISTS note_tombstones (
    sync_id    TEXT PRIMARY KEY,
    deleted_at TEXT NOT NULL
);
PRAGMA user_version = 2;''';

  final SqliteDatabase _database;
  bool _fts = false;
  int _undoDepthValue = DivanDefaults.undoDepth;

  /// Path of the SQLite database file.
  String get databasePath => _database.databasePath;

  /// True when the FTS5 index is available.
  bool get usesFts => _fts;

  /// Creates the schema (once), probes for FTS5, and reports whether the index is live.
  Future<void> initialize() async {
    final db = await _database.open();

    // A schema v2 database is opened as-is; v1 databases get the sync migration; a fresh
    // one gets the base tables first (the FTS triggers reference `notes`).
    final version = await _database.schemaVersion();
    if (version >= currentSchemaVersion) {
      _fts = await _probeFts(db);
      return;
    }

    if (version == 1) {
      await db.execute(_migrateToV2Sql);
      await db.execute(_migrateToV3Sql);
      _fts = await _probeFts(db);
      return;
    }

    if (version == 2) {
      await db.execute(_migrateToV3Sql);
      _fts = await _probeFts(db);
      return;
    }

    await _database.initialize([_baseSchemaSql]);

    try {
      await db.execute(_ftsSchemaSql);
      _fts = await _probeFts(db);
    } on DatabaseException {
      _fts =
          false; // an engine without FTS5: the LIKE fallback carries the search
    }
  }

  /// Closes the database handle.
  @override
  Future<void> close() => _database.close();

  // ── Notebooks ──

  @override
  Future<Notebook> addNotebook(Notebook notebook) async {
    final db = await _database.open();
    final id = await db.insert('notebooks', {
      'name': notebook.name,
      'created_at': _text(notebook.createdAt),
      'is_archived': notebook.isArchived ? 1 : 0,
      'updated_at': notebook.updatedAt == null
          ? null
          : _text(notebook.updatedAt!),
    });
    return notebook.copyWith(id: id);
  }

  @override
  Future<void> updateNotebook(Notebook notebook) async {
    final db = await _database.open();
    final rows = await db.update(
      'notebooks',
      {
        'name': notebook.name,
        'created_at': _text(notebook.createdAt),
        'is_archived': notebook.isArchived ? 1 : 0,
        'updated_at': notebook.updatedAt == null
            ? null
            : _text(notebook.updatedAt!),
      },
      where: 'id = ?',
      whereArgs: [notebook.id],
    );
    if (rows == 0) {
      throw DivanException('No notebook #${notebook.id}.');
    }
  }

  @override
  Future<bool> removeNotebook(int id) async {
    final db = await _database.open();
    final rows = await db.delete('notebooks', where: 'id = ?', whereArgs: [id]);
    return rows > 0;
  }

  @override
  Future<Notebook?> findNotebook(int id) async {
    final db = await _database.open();
    final rows = await db.query(
      'notebooks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _mapNotebook(rows.first);
  }

  @override
  Future<Notebook?> findNotebookByName(String name) async {
    final db = await _database.open();
    final rows = await db.query(
      'notebooks',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isEmpty ? null : _mapNotebook(rows.first);
  }

  @override
  Future<List<Notebook>> listNotebooks() async {
    final db = await _database.open();
    final rows = await db.query('notebooks', orderBy: 'id');
    return rows.map(_mapNotebook).toList();
  }

  // ── Notes ──

  @override
  Future<Note> addNote(Note note) async {
    final db = await _database.open();
    final identity = note.syncId.isEmpty ? Uids.newUid() : note.syncId;
    final id = await db.insert('notes', _noteValues(note, identity));
    return note.copyWith(id: id, syncId: identity);
  }

  @override
  Future<void> updateNote(Note note) async {
    final db = await _database.open();
    final rows = await db.update(
      'notes',
      _noteValues(note, note.syncId),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    if (rows == 0) {
      throw DivanException('No note #${note.id}.');
    }
  }

  @override
  Future<bool> removeNote(int id, DateTime deletedAt) async {
    final db = await _database.open();
    var affected = 0;

    // The tombstone and the delete happen in one transaction; the `notes_ad` trigger keeps
    // the FTS index in sync — no manual index writes here.
    await db.transaction((txn) async {
      await txn.rawInsert(
        '''
INSERT INTO note_tombstones (sync_id, deleted_at)
SELECT sync_id, ? FROM notes WHERE id = ? AND sync_id != ''
ON CONFLICT (sync_id) DO UPDATE SET deleted_at = excluded.deleted_at
''',
        [_text(deletedAt), id],
      );
      affected = await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
    });

    return affected > 0;
  }

  @override
  Future<void> upsertTombstone(DivanTombstone tombstone) async {
    if (tombstone.syncId.isEmpty) return;

    final db = await _database.open();
    await db.rawInsert(
      '''
INSERT INTO note_tombstones (sync_id, deleted_at) VALUES (?, ?)
ON CONFLICT (sync_id) DO UPDATE SET deleted_at = excluded.deleted_at
''',
      [tombstone.syncId, _text(tombstone.deletedAt)],
    );
  }

  @override
  Future<List<DivanTombstone>> getTombstones() async {
    final db = await _database.open();
    final rows = await db.rawQuery('''
SELECT t.sync_id, t.deleted_at FROM note_tombstones t
WHERE t.sync_id != '' AND NOT EXISTS (SELECT 1 FROM notes n WHERE n.sync_id = t.sync_id)
ORDER BY t.deleted_at
''');
    return [
      for (final row in rows)
        DivanTombstone(
          syncId: row['sync_id']! as String,
          deletedAt: DateTime.parse(row['deleted_at']! as String).toUtc(),
        ),
    ];
  }

  @override
  Future<Note?> findNote(int id) async {
    final db = await _database.open();
    final rows = await db.rawQuery('$_selectNotes WHERE id = ?', [id]);
    return rows.isEmpty ? null : _mapNote(rows.first);
  }

  @override
  Future<List<Note>> listNotes() async {
    final db = await _database.open();
    final rows = await db.rawQuery('$_selectNotes ORDER BY id');
    return rows.map(_mapNote).toList();
  }

  @override
  Future<List<int>> searchIds(String query, int limit) async {
    final db = await _database.open();

    if (_fts) {
      try {
        final rows = await db.rawQuery(
          'SELECT rowid FROM notes_fts WHERE notes_fts MATCH ? ORDER BY rank LIMIT ?',
          [_ftsQuery(query), limit],
        );
        return [for (final row in rows) row['rowid']! as int];
      } on DatabaseException {
        // fall through to the LIKE path (unusual tokenization edge cases)
      }
    }

    final terms = query
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];

    final conditions = [
      for (var i = 0; i < terms.length; i++)
        "(title LIKE ? ESCAPE '[' OR body LIKE ? ESCAPE '[')",
    ].join(' AND ');

    final args = <Object?>[
      for (final term in terms) ...[
        '%${_escapeLike(term)}%',
        '%${_escapeLike(term)}%',
      ],
      limit,
    ];

    final rows = await db.rawQuery(
      '$_selectNotes WHERE $conditions ORDER BY id LIMIT ?',
      args,
    );
    return [for (final row in rows) row['id']! as int];
  }

  @override
  Future<void> replaceNotes(List<Note> notes) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.delete('notes');
      if (_fts) {
        await txn.rawInsert(
          "INSERT INTO notes_fts(notes_fts) VALUES('rebuild')",
        );
      }

      for (final note in notes) {
        final identity = note.syncId.isEmpty ? Uids.newUid() : note.syncId;
        await txn.insert('notes', {
          ..._noteValues(note, identity),
          'id': note.id,
        });
      }

      // Restored notes retract their tombstones.
      await txn.rawDelete(
        "DELETE FROM note_tombstones WHERE sync_id IN "
        "(SELECT sync_id FROM notes WHERE sync_id != '')",
      );
    });
  }

  @override
  Future<void> replaceNotebooks(List<Notebook> notebooks) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.delete('notebooks');
      for (final notebook in notebooks) {
        await txn.insert('notebooks', {
          'id': notebook.id,
          'name': notebook.name,
          'created_at': _text(notebook.createdAt),
          'is_archived': notebook.isArchived ? 1 : 0,
        });
      }
    });
  }

  // ── Undo ──

  @override
  Future<void> pushUndo(String payload) async {
    if (payload.isEmpty) {
      throw ArgumentError.value(payload, 'payload', 'must not be empty');
    }

    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.insert('undo_log', {
        'created_at': _text(DateTime.now().toUtc()),
        'payload': payload,
      });

      if (_undoDepthValue == 0) {
        await txn.delete('undo_log');
        return;
      }

      await txn.rawDelete(
        'DELETE FROM undo_log WHERE id NOT IN '
        '(SELECT id FROM undo_log ORDER BY id DESC LIMIT ?)',
        [_undoDepthValue],
      );
    });
  }

  @override
  Future<String?> popUndo() async {
    final db = await _database.open();
    final rows = await db.rawQuery(
      'SELECT payload FROM undo_log ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) return null;

    await db.delete('undo_log', where: 'id = (SELECT MAX(id) FROM undo_log)');
    return rows.first['payload']! as String;
  }

  @override
  Future<int> get undoCount async {
    final db = await _database.open();
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM undo_log');
    return (rows.first['c'] as int?) ?? 0;
  }

  @override
  set undoDepth(int value) {
    if (value < 0) {
      throw RangeError.value(value, 'undoDepth', 'must not be negative');
    }
    _undoDepthValue = value;
  }

  int get undoDepthValue => _undoDepthValue;

  // ── Internals ──

  Future<bool> _probeFts(Database db) async {
    try {
      await db.rawQuery('SELECT rowid FROM notes_fts LIMIT 1');
      return true;
    } on DatabaseException {
      return false;
    }
  }

  static Map<String, Object?> _noteValues(Note note, String syncId) => {
    'notebook_id': note.notebookId,
    'title': note.title,
    'body': note.body,
    'tags': note.tags,
    'pinned': note.pinned ? 1 : 0,
    'archived': note.archived ? 1 : 0,
    'created_at': _text(note.createdAt),
    'updated_at': _text(note.updatedAt),
    'sync_id': syncId,
  };

  static Notebook _mapNotebook(Map<String, Object?> row) => Notebook(
    id: row['id']! as int,
    name: row['name']! as String,
    createdAt: DateTime.parse(row['created_at']! as String).toUtc(),
    isArchived: (row['is_archived']! as int) != 0,
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.parse(row['updated_at']! as String).toUtc(),
  );

  static Note _mapNote(Map<String, Object?> row) => Note(
    id: row['id']! as int,
    notebookId: row['notebook_id']! as int,
    title: row['title']! as String,
    body: row['body']! as String,
    tags: row['tags']! as String,
    pinned: (row['pinned']! as int) != 0,
    archived: (row['archived']! as int) != 0,
    createdAt: DateTime.parse(row['created_at']! as String).toUtc(),
    updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
    syncId: row['sync_id']! as String,
  );

  /// The round-trip ISO-8601 form the .NET store writes (`DateTimeOffset.ToString("O")`).
  static String _text(DateTime value) => value.toUtc().toIso8601String();

  /// Turns a user query into an FTS5 MATCH expression: every term quoted, AND-ed.
  static String _ftsQuery(String query) {
    final terms = query
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .map((term) => '"${term.replaceAll('"', '""')}"');
    return terms.join(' ');
  }

  /// Escapes the `LIKE` wildcards using `[` as the escape character, like the original.
  static String _escapeLike(String text) =>
      text.replaceAll('[', '[[').replaceAll('%', '[%').replaceAll('_', '[_');
}
