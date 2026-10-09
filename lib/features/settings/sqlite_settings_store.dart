/// settings — see doc/settings.md and AGENTS.md
import 'package:sqflite/sqflite.dart';

import '../../core/sqlite_database.dart';
import 'setting_guard.dart';
import 'settings_store.dart';

class SqliteSettingsStore implements SettingsStore {
  SqliteSettingsStore(String databasePath, {SettingsOptions? options})
    : options = options ?? const SettingsOptions(),
      _database = SqliteDatabase(databasePath) {
    this.options.validate();
  }

  /// Schema v1 — identical columns to the .NET store.
  static const List<String> createSchemaStatements = [
    '''
CREATE TABLE IF NOT EXISTS settings (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    updated_at TEXT NOT NULL
)''',
    'PRAGMA user_version = 1',
  ];

  /// Validated limits in effect.
  final SettingsOptions options;

  final SqliteDatabase _database;

  /// Path of the SQLite database file.
  String get databasePath => _database.databasePath;

  @override
  Future<String?> getValue(String key) async {
    SettingGuard.validateKey(key, options.maxKeyLength);
    final db = await _initialized();

    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<List<SettingsEntry>> getAll() async {
    final db = await _initialized();

    // ORDER BY walks the primary-key index — sorted output without a separate sort step.
    final rows = await db.query('settings', orderBy: 'key');
    return List.unmodifiable(
      rows.map(
        (row) => SettingsEntry(
          key: row['key']! as String,
          value: row['value']! as String,
          updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
        ),
      ),
    );
  }

  @override
  Future<void> setValue(String key, String? value) async {
    SettingGuard.validateKey(key, options.maxKeyLength);
    SettingGuard.ensureNotSecretKey(key, options.secretKeyNeedles);
    final safeValue = SettingGuard.validateValue(value, options.maxValueLength);
    final db = await _initialized();

    await db.transaction((txn) async {
      await txn.rawInsert(
        '''
INSERT INTO settings(key, value, updated_at)
VALUES(?, ?, ?)
ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
''',
        [key, safeValue, DateTime.now().toUtc().toIso8601String()],
      );
    });
  }

  @override
  Future<bool> remove(String key) async {
    SettingGuard.validateKey(key, options.maxKeyLength);
    final db = await _initialized();
    final removed = await db.delete(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return removed > 0;
  }

  @override
  Future<int> clear() async {
    final db = await _initialized();
    return db.delete('settings');
  }

  /// Closes the underlying handle (used when the app container is torn down).
  Future<void> close() => _database.close();

  /// Reads the schema version stamped in the database — used by the parity test to prove
  /// the port writes the same `PRAGMA user_version` the .NET store does.
  Future<int> schemaVersionForTest() => _database.schemaVersion();

  Future<Database> _initialized() async {
    await _database.initialize(createSchemaStatements);
    return _database.open();
  }
}
