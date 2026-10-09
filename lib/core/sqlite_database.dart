import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Selects the right SQLite backend once per process.
///
/// Mobile uses the bundled `sqflite` implementation; desktop and tests use the FFI
/// factory (backed by `sqlite3_flutter_libs` in a real app build, and by the host's
/// `libsqlite3` under `flutter test`). Port of the platform split the .NET side got
/// for free from `Microsoft.Data.Sqlite`.
abstract final class SqliteBootstrap {
  static bool _initialized = false;

  static void ensure() {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      throw UnsupportedError(
        'JameJam stores its data in SQLite and does not support web builds.',
      );
    }

    final inTest = Platform.environment['FLUTTER_TEST'] == 'true';
    if (inTest || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }
}

/// Shared, safety-hardened access to one local SQLite database file.
///
/// The Dart port of `JameJam.Data.SqliteDatabase`:
/// * parameterized statements only (callers still parameterize every query),
/// * WAL journaling and foreign keys enabled on open,
/// * schema creation executed exactly once per lifetime (memoized future — the
///   single-isolate equivalent of the double-checked lock),
/// * owner-only file permissions on Unix, best-effort elsewhere.
class SqliteDatabase {
  SqliteDatabase(this.databasePath);

  /// Path of the SQLite database file (created on first use).
  final String databasePath;

  Database? _database;
  Future<void>? _initialization;

  /// Opens a short-lived handle to the database, creating the file if needed.
  Future<Database> open() async {
    final existing = _database;
    if (existing != null) return existing;

    SqliteBootstrap.ensure();
    await _ensureParentDirectory();
    final opened = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        singleInstance: true,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    _database = opened;
    return opened;
  }

  /// Creates the directory, enables WAL, and runs the schema exactly once.
  ///
  /// [schemaStatements] is an idempotent script (`CREATE TABLE IF NOT EXISTS …`,
  /// `PRAGMA user_version = N`). It runs once per store lifetime, mirroring the
  /// .NET `Initialize(schemaFactory)` contract.
  Future<void> initialize(List<String> schemaStatements) {
    return _initialization ??= _initializeOnce(schemaStatements);
  }

  Future<void> _initializeOnce(List<String> schemaStatements) async {
    final db = await open();
    await db.execute('PRAGMA journal_mode = WAL');
    for (final statement in schemaStatements) {
      await db.execute(statement);
    }
    await _restrictPermissions(databasePath, isDirectory: false);
  }

  /// Reads the `user_version` pragma — the migration seam every store uses.
  Future<int> schemaVersion() async {
    final db = await open();
    final rows = await db.rawQuery('PRAGMA user_version');
    if (rows.isEmpty) return 0;
    return (rows.first.values.first as int?) ?? 0;
  }

  /// Closes the handle. Safe to call more than once.
  Future<void> close() async {
    final db = _database;
    _database = null;
    _initialization = null;
    if (db != null) await db.close();
  }

  Future<void> _ensureParentDirectory() async {
    final directory = p.dirname(p.absolute(databasePath));
    if (directory.isEmpty) return;

    final dir = Directory(directory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      await _restrictPermissions(directory, isDirectory: true);
    }
  }

  /// Grants only the owner access (best-effort; a no-op on Windows and on mobile,
  /// where the app sandbox already isolates the file).
  static Future<void> _restrictPermissions(
    String path, {
    required bool isDirectory,
  }) async {
    if (!Platform.isLinux && !Platform.isMacOS) return;
    try {
      await Process.run('chmod', [
        isDirectory ? '700' : '600',
        p.absolute(path),
      ]);
    } on ProcessException {
      // Best-effort, exactly like the .NET implementation.
    }
  }
}
