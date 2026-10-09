import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/sqlite_database.dart';
import 'package:jamejam/core/text_guard.dart';

void main() {
  group('TextGuard', () {
    test('keeps \n and \t but strips other control characters', () {
      expect(TextGuard.clip('a\u0001b\u0007c', 100), 'abc');
      expect(TextGuard.clip('line1\nline2', 100), 'line1\nline2');
      expect(TextGuard.clip('col1\tcol2', 100), 'col1\tcol2');
      expect(TextGuard.clip('del\u007fete', 100), 'delete');
    });

    test('trims surrounding whitespace', () {
      expect(TextGuard.clip('  hello  ', 100), 'hello');
    });

    test('sanitizeRequired rejects empty and whitespace-only input', () {
      expect(
        () => TextGuard.sanitizeRequired('   ', 10, 'title'),
        throwsArgumentError,
      );
      expect(
        () => TextGuard.sanitizeRequired(null, 10, 'title'),
        throwsArgumentError,
      );
    });

    test('sanitizeRequired rejects over-long values instead of truncating', () {
      expect(
        () => TextGuard.sanitizeRequired('abcdefghij', 5, 'title'),
        throwsRangeError,
      );
    });

    test('sanitizeOptional maps null and whitespace to empty', () {
      expect(TextGuard.sanitizeOptional(null, 10, 'notes'), '');
      expect(TextGuard.sanitizeOptional('  \t ', 10, 'notes'), '');
      expect(TextGuard.sanitizeOptional(' note ', 10, 'notes'), 'note');
    });

    test('clip truncates rather than throwing', () {
      expect(TextGuard.clip('abcdefghij', 4), 'abcd');
      expect(TextGuard.clip(null, 4), '');
    });
  });

  group('SqliteDatabase', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('jamejam-db-test'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('creates the file, its directory, and the schema exactly once', () async {
      final path = '${temp.path}/nested/toolbox.db';
      final database = SqliteDatabase(path);

      await database.initialize([
        'CREATE TABLE IF NOT EXISTS demo (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
        'PRAGMA user_version = 1',
      ]);

      expect(File(path).existsSync(), isTrue);
      expect(await database.schemaVersion(), 1);

      // Running the schema a second time is a no-op, not an error.
      await database.initialize([
        'CREATE TABLE IF NOT EXISTS demo (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
        'PRAGMA user_version = 1',
      ]);
      expect(await database.schemaVersion(), 1);

      final db = await database.open();
      await db.insert('demo', {'value': 'kept'});
      expect(await db.query('demo'), hasLength(1));

      await database.close();
    });

    test('enables foreign keys on every connection', () async {
      final database = SqliteDatabase('${temp.path}/fk.db');
      await database.initialize(const [
        'CREATE TABLE parent (id INTEGER PRIMARY KEY)',
        'CREATE TABLE child (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES parent(id))',
      ]);
      final db = await database.open();
      final rows = await db.rawQuery('PRAGMA foreign_keys');
      expect(rows.first.values.first, 1);
      await database.close();
    });

    test('restricts the file to the owner on Unix', () async {
      final path = '${temp.path}/perm.db';
      final database = SqliteDatabase(path);
      await database.initialize(const [
        'CREATE TABLE t (id INTEGER PRIMARY KEY)',
      ]);

      if (Platform.isLinux || Platform.isMacOS) {
        final mode = File(path).statSync().mode & 0x1FF;
        expect(
          mode,
          0x180,
          reason: 'expected 0600, got ${mode.toRadixString(8)}',
        );
      }
      await database.close();
    });
  });
}
