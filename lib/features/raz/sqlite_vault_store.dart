/// raz — see doc/raz.md and AGENTS.md
import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/date_only.dart';
import '../../core/sqlite_database.dart';
import 'models.dart';
import 'raz_defaults.dart';
import 'vault_store.dart';

class SqliteVaultStore implements VaultStore {
  SqliteVaultStore(String databasePath)
    : _database = SqliteDatabase(databasePath);

  /// Current schema version written by this build.
  static const int currentSchemaVersion = 1;

  static const String _schemaSql = '''
CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value BLOB NOT NULL
);
CREATE TABLE IF NOT EXISTS entries (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    title         BLOB NOT NULL,
    secret        BLOB NOT NULL,
    username      BLOB NOT NULL,
    url           BLOB NOT NULL,
    notes         BLOB NOT NULL,
    tags          BLOB NOT NULL,
    totp_seed     BLOB NOT NULL,
    totp_algo     INTEGER NOT NULL,
    totp_digits   INTEGER NOT NULL,
    totp_period   INTEGER NOT NULL,
    expires_on    TEXT,
    favorite      INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_entries_expires ON entries (expires_on);
CREATE TABLE IF NOT EXISTS undo_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    payload    BLOB NOT NULL
);
PRAGMA user_version = $currentSchemaVersion''';

  final SqliteDatabase _database;

  /// Path of the SQLite database file.
  String get databasePath => _database.databasePath;

  int _undoDepthValue = RazDefaults.undoDepth;

  @override
  int get undoDepth => _undoDepthValue;

  @override
  set undoDepth(int value) {
    if (value < 0) {
      throw RangeError.value(
        value,
        'undoDepth',
        'UndoDepth cannot be negative.',
      );
    }

    _undoDepthValue = value;
  }

  /// Opens the store, running the schema script when the on-disk version is older.
  Future<Database> _db() async {
    final db = await _database.open();
    final rows = await db.rawQuery('PRAGMA user_version');
    final current = rows.isEmpty ? 0 : (rows.first.values.first as int?) ?? 0;
    if (current > currentSchemaVersion) {
      throw StateError(
        'The vault schema (v$current) is newer than this build supports '
        '(v$currentSchemaVersion).',
      );
    }

    await _database.initialize(
      current >= currentSchemaVersion ? const [] : _statements(),
    );
    return _database.open();
  }

  static List<String> _statements() => _schemaSql
      .split(';')
      .map((statement) => statement.trim())
      .where((statement) => statement.isNotEmpty)
      .toList();

  /// Reads the schema version stamped in the database (migration diagnostics).
  Future<int> schemaVersionOnDisk() => _database.schemaVersion();

  /// Closes the handle.
  Future<void> close() => _database.close();

  @override
  Future<bool> isInitialized() async => await getSalt() != null;

  @override
  Future<void> setMeta(
    Uint8List salt,
    int iterations,
    Uint8List keyCheck,
  ) async {
    final db = await _db();
    await db.transaction((txn) async {
      for (final row in {
        'salt': salt,
        'iterations': Uint8List.fromList(utf8.encode('$iterations')),
        'key_check': keyCheck,
      }.entries) {
        await txn.insert('meta', {
          'key': row.key,
          'value': row.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<Uint8List?> getSalt() => _metaBlob('salt');

  @override
  Future<int> getIterations() async {
    final value = await _metaText('iterations');
    return int.tryParse(value ?? '') ?? 0;
  }

  @override
  Future<Uint8List?> getKeyCheck() => _metaBlob('key_check');

  @override
  Future<RazEntry> addEntry(RazEntry entry) async {
    final db = await _db();
    return db.transaction((txn) async {
      final id = await txn.insert('entries', _row(entry));
      return entry.copyWith(id: id);
    });
  }

  @override
  Future<void> updateEntry(RazEntry entry) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.update(
        'entries',
        _row(entry),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    });
  }

  @override
  Future<bool> removeEntry(int id) async {
    final db = await _db();
    return db.transaction((txn) async {
      final affected = await txn.delete(
        'entries',
        where: 'id = ?',
        whereArgs: [id],
      );
      return affected > 0;
    });
  }

  @override
  Future<RazEntry?> findEntry(int id) async {
    final db = await _db();
    final rows = await db.query('entries', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _mapEntry(rows.first);
  }

  @override
  Future<List<RazEntry>> listEntries() async {
    final db = await _db();
    final rows = await db.query('entries', orderBy: 'id');
    return rows.map(_mapEntry).toList();
  }

  @override
  Future<void> replaceEntries(List<RazEntry> entries) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete('entries');
      for (final entry in entries) {
        await txn.insert('entries', {'id': entry.id, ..._row(entry)});
      }
    });
  }

  @override
  Future<int> count() async {
    final db = await _db();
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM entries');
    return (rows.first['n'] as int?) ?? 0;
  }

  @override
  Future<void> pushUndo(Uint8List payload) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.insert('undo_log', {
        'created_at': _iso(DateTime.now().toUtc()),
        'payload': payload,
      });
      await txn.rawDelete(
        '''
DELETE FROM undo_log WHERE id NOT IN (
    SELECT id FROM undo_log ORDER BY id DESC LIMIT ?
)''',
        [_undoDepthValue],
      );
    });
  }

  @override
  Future<Uint8List?> popUndo() async {
    final db = await _db();
    return db.transaction((txn) async {
      final rows = await txn.query(
        'undo_log',
        columns: ['id', 'payload'],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;

      await txn.delete(
        'undo_log',
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
      return Uint8List.fromList(rows.first['payload'] as List<int>);
    });
  }

  @override
  Future<int> undoCount() async {
    final db = await _db();
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM undo_log');
    return (rows.first['n'] as int?) ?? 0;
  }

  // ── Helpers ──

  Future<Uint8List?> _metaBlob(String key) async {
    final db = await _db();
    final rows = await db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'];
    if (value == null) return null;
    return Uint8List.fromList(value as List<int>);
  }

  Future<String?> _metaText(String key) async {
    final db = await _db();
    final rows = await db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return utf8.decode(rows.first['value'] as List<int>);
  }

  /// Maps an entry to its row: the seven sensitive columns are stored as raw ciphertext
  /// bytes (the service hands them Base64), bookkeeping stays plain.
  Map<String, Object?> _row(RazEntry entry) => {
    'title': _bytes(entry.title),
    'secret': _bytes(entry.secret),
    'username': _bytes(entry.username),
    'url': _bytes(entry.url),
    'notes': _bytes(entry.notes),
    'tags': _bytes(entry.tags),
    'totp_seed': _bytes(entry.totpSeed),
    'totp_algo': entry.totpAlgorithm.code,
    'totp_digits': entry.totpDigits,
    'totp_period': entry.totpPeriodSeconds,
    'expires_on': entry.expiresOn?.toIso(),
    'favorite': entry.favorite ? 1 : 0,
    'created_at': _iso(entry.createdAt),
    'updated_at': _iso(entry.updatedAt),
  };

  static RazEntry _mapEntry(Map<String, Object?> row) => RazEntry(
    id: (row['id'] as int?) ?? 0,
    title: _text(row['title']),
    secret: _text(row['secret']),
    username: _text(row['username']),
    url: _text(row['url']),
    notes: _text(row['notes']),
    tags: _text(row['tags']),
    totpSeed: _text(row['totp_seed']),
    totpAlgorithm: TotpAlgorithm.fromCode((row['totp_algo'] as int?) ?? 0),
    totpDigits: (row['totp_digits'] as int?) ?? 0,
    totpPeriodSeconds: (row['totp_period'] as int?) ?? 0,
    expiresOn: switch (row['expires_on']) {
      final String day when day.isNotEmpty => DateOnly.parseIso(day),
      _ => null,
    },
    favorite: ((row['favorite'] as int?) ?? 0) != 0,
    createdAt: DateTime.parse('${row['created_at']}'),
    updatedAt: DateTime.parse('${row['updated_at']}'),
  );

  static List<int> _bytes(String base64Text) => base64.decode(base64Text);

  static String _text(Object? blob) =>
      blob == null ? '' : base64.encode((blob as List).cast<int>());

  static String _iso(DateTime value) => value.toUtc().toIso8601String();
}
