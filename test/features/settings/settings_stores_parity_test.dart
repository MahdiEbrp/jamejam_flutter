// Parity port of tests/JameJam.Tests/Settings/MemorySettingsStoreTests.cs (12 cases) and
// Settings/SqliteSettingsStoreTests.cs (19 cases).
//
// The .NET suite has one file per store with overlapping cases. Here the overlapping part is
// a shared contract run against both stores, and each file's *unique* cases follow it — the
// same coverage, without writing every case twice.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/exceptions.dart';
import 'package:jamejam/features/settings/memory_settings_store.dart';
import 'package:jamejam/features/settings/setting_guard.dart';
import 'package:jamejam/features/settings/settings_store.dart';
import 'package:jamejam/features/settings/sqlite_settings_store.dart';

/// The behaviours every settings store must satisfy.
void sharedStoreContract(
  String name,
  Future<SettingsStore> Function() create, {
  Future<SettingsStore> Function(SettingsOptions options)? createWithOptions,
}) {
  group('$name store contract', () {
    late SettingsStore store;

    setUp(() async => store = await create());

    // Set_ThenGet_RoundTrips
    test('set then get round-trips', () async {
      await store.setValue('greeter.defaultName', 'Soroush');
      expect(await store.getValue('greeter.defaultName'), 'Soroush');
    });

    // Set_OverwritesExistingValue
    test('set overwrites an existing value', () async {
      await store.setValue('k', 'first');
      await store.setValue('k', 'second');
      expect(await store.getValue('k'), 'second');
      expect(await store.getAll(), hasLength(1));
    });

    // Set_NullValue_StoresEmptyString
    test('null is stored as an empty string', () async {
      await store.setValue('k', null);
      expect(await store.getValue('k'), '');
    });

    // Get_MissingKey_ReturnsNull
    test('get on a missing key returns null', () async {
      expect(await store.getValue('nope'), isNull);
    });

    // GetAll_IsSortedByKey
    test('getAll is sorted by key', () async {
      await store.setValue('c', '3');
      await store.setValue('a', '1');
      await store.setValue('b', '2');
      expect((await store.getAll()).map((e) => e.key), ['a', 'b', 'c']);
    });

    // Remove_RemovesAndReportsExistence
    test('remove removes and reports existence', () async {
      await store.setValue('k', 'v');
      expect(await store.remove('k'), isTrue);
      expect(await store.remove('k'), isFalse);
      expect(await store.getValue('k'), isNull);
    });

    // Clear_RemovesEverything
    test('clear removes everything and returns the count', () async {
      await store.setValue('a', '1');
      await store.setValue('b', '2');
      expect(await store.clear(), 2);
      expect(await store.getAll(), isEmpty);
    });

    // SecretLookingKey_IsRefused
    test('a secret-looking key is refused', () async {
      await expectLater(
        store.setValue('ai.apiKey', 'sk-123'),
        throwsA(isA<JameJamException>()),
      );
      expect(await store.getAll(), isEmpty);
    });

    // InvalidKey_Throws — the empty/whitespace half of the .NET theory. (The null half is
    // not expressible through a non-nullable Dart parameter; the guard is tested with null
    // directly in setting_guard_parity_test.dart.)
    test('an empty or whitespace key throws', () async {
      for (final key in ['', '   ']) {
        await expectLater(
          store.setValue(key, 'value'),
          throwsA(isA<JameJamException>()),
        );
      }
    });

    // TooLongKey_Throws / TooLongValue_Throws
    test('an over-long key or value throws', () async {
      await expectLater(
        store.setValue('k' * 129, 'value'),
        throwsA(isA<JameJamException>()),
      );
      await expectLater(
        store.setValue('k', 'v' * 8193),
        throwsA(isA<JameJamException>()),
      );
    });

    // EmptyValue_RoundTrips
    test('an empty value round-trips', () async {
      await store.setValue('k', '');
      expect(await store.getValue('k'), '');
      expect((await store.getAll()).single.value, '');
    });

    if (createWithOptions != null) {
      // CustomValueLimit_IsEnforced
      test('a custom value limit is enforced', () async {
        final limited = await createWithOptions(
          const SettingsOptions(maxValueLength: 5),
        );
        await limited.setValue('k', '12345');
        await expectLater(
          limited.setValue('k', '123456'),
          throwsA(isA<JameJamException>()),
        );
      });

      // CustomSecretNeedles_AreEnforced (a custom set replaces the defaults, as in .NET)
      test('custom secret needles are enforced', () async {
        final custom = await createWithOptions(
          const SettingsOptions(secretKeyNeedles: {'private', 'salary'}),
        );
        await expectLater(
          custom.setValue('org.private', 'x'),
          throwsA(isA<JameJamException>()),
        );
        await expectLater(
          custom.setValue('wallet.salary', '1'),
          throwsA(isA<JameJamException>()),
        );
        await custom.setValue('openai.apiKey', 'x');
        expect(await custom.getValue('openai.apiKey'), 'x');
      });
    }
  });
}

void main() {
  sharedStoreContract(
    'Memory',
    () async => MemorySettingsStore(),
    createWithOptions: (options) async => MemorySettingsStore(options: options),
  );

  late Directory sqliteRoot;
  sharedStoreContract(
    'SQLite',
    () async {
      sqliteRoot = Directory.systemTemp.createTempSync(
        'jamejam-parity-contract',
      );
      return SqliteSettingsStore('${sqliteRoot.path}/settings.db');
    },
    createWithOptions: (options) async =>
        SqliteSettingsStore('${sqliteRoot.path}/custom.db', options: options),
  );

  group('SettingsOptionsTests parity — construction-time rejection', () {
    test('invalid options are rejected at construction', () {
      expect(
        () => SettingsOptions(maxKeyLength: 0).validate(),
        throwsA(isA<JameJamException>()),
      );
      expect(
        () => SettingsOptions(maxValueLength: 0).validate(),
        throwsA(isA<JameJamException>()),
      );
    });

    test('a store built with an invalid limit refuses at construction', () {
      expect(
        () => MemorySettingsStore(options: SettingsOptions(maxKeyLength: 0)),
        throwsA(isA<JameJamException>()),
      );
      expect(
        () => SqliteSettingsStore(
          '/tmp/never-created.db',
          options: SettingsOptions(maxValueLength: 0),
        ),
        throwsA(isA<JameJamException>()),
      );
    });
  });

  group('SqliteSettingsStoreTests-only cases', () {
    late Directory temp;
    late SqliteSettingsStore store;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('jamejam-sqlite-parity');
      store = SqliteSettingsStore('${temp.path}/settings.db');
    });

    tearDown(() async {
      await store.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    // GetAll_IsSortedByKey_WithTimestamps
    test('getAll carries round-trippable UTC timestamps', () async {
      await store.setValue('k', 'v');
      final entry = (await store.getAll()).single;
      expect(entry.updatedAt.isUtc, isTrue);
      expect(
        entry.updatedAt.difference(DateTime.now().toUtc()).inMinutes.abs(),
        lessThan(1),
      );
    });

    // Data_PersistsAcrossStoreInstances
    test('data persists across store instances', () async {
      await store.setValue('greeter.defaultName', 'Rostam');
      await store.close();

      final reopened = SqliteSettingsStore('${temp.path}/settings.db');
      expect(await reopened.getValue('greeter.defaultName'), 'Rostam');
      await reopened.close();
    });

    // DatabaseFile_IsOwnerOnly_OnUnix
    test('the database file is owner-only on Unix', () async {
      await store.setValue('k', 'v');
      if (Platform.isLinux || Platform.isMacOS) {
        final mode = File(store.databasePath).statSync().mode & 0x1FF;
        expect(
          mode,
          0x180,
          reason: 'expected 0600, got ${mode.toRadixString(8)}',
        );
      }
    });

    // Custom key-length limit (the .NET suite's TooLongKey case with a custom rail)
    test('a custom key-length limit is enforced', () async {
      final custom = SqliteSettingsStore(
        '${temp.path}/limited.db',
        options: const SettingsOptions(maxKeyLength: 4),
      );
      await custom.setValue('abcd', 'v');
      await expectLater(
        custom.setValue('abcde', 'v'),
        throwsA(isA<JameJamException>()),
      );
      await custom.close();
    });

    // The schema version the .NET store stamps.
    test('the schema is stamped version 1', () async {
      await store.setValue('k', 'v');
      final rows = await store.schemaVersionForTest();
      expect(rows, 1);
    });
  });
}
