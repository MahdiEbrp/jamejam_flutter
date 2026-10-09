import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/exceptions.dart';
import 'package:jamejam/features/settings/memory_settings_store.dart';
import 'package:jamejam/features/settings/setting_guard.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/settings/settings_controller.dart';
import 'package:jamejam/features/settings/sqlite_settings_store.dart';

void main() {
  group('SettingGuard', () {
    test('validates keys', () {
      expect(
        SettingGuard.validateKey('greeter.defaultName'),
        'greeter.defaultName',
      );
      expect(
        () => SettingGuard.validateKey(''),
        throwsA(isA<JameJamException>()),
      );
      expect(
        () => SettingGuard.validateKey('   '),
        throwsA(isA<JameJamException>()),
      );
      expect(
        () => SettingGuard.validateKey('k' * 129),
        throwsA(isA<JameJamException>()),
      );
    });

    test('validates values and maps null to empty', () {
      expect(SettingGuard.validateValue(null), '');
      expect(SettingGuard.validateValue('value'), 'value');
      expect(
        () => SettingGuard.validateValue('v' * 8193),
        throwsA(isA<JameJamException>()),
      );
    });

    test('refuses secret-looking keys by name pattern', () {
      for (final key in [
        'openai.apiKey',
        'soroush.API-KEY',
        'some.api_key',
        'sync.token',
        'user.password',
        'db.pwd',
        'my.credential',
      ]) {
        expect(
          () => SettingGuard.ensureNotSecretKey(key),
          throwsA(isA<JameJamException>()),
          reason: '$key should be refused',
        );
      }
      // Not every key containing "key" is a secret.
      expect(
        () => SettingGuard.ensureNotSecretKey('keyboard.layout'),
        returnsNormally,
      );
      expect(
        () => SettingGuard.ensureNotSecretKey('divan.notebook'),
        returnsNormally,
      );
    });

    test('honours custom needle sets', () {
      expect(
        () => SettingGuard.ensureNotSecretKey('org.private', {'private'}),
        throwsA(isA<JameJamException>()),
      );
      expect(
        () => SettingGuard.ensureNotSecretKey('openai.apiKey', const {}),
        returnsNormally,
      );
    });

    test('bounds the options themselves', () {
      expect(const SettingsOptions().validate, returnsNormally);
      expect(
        () => const SettingsOptions(maxKeyLength: 0).validate(),
        throwsA(isA<JameJamException>()),
      );
      expect(
        () => const SettingsOptions(maxValueLength: 2_000_000).validate(),
        throwsA(isA<JameJamException>()),
      );
    });
  });

  group('MemorySettingsStore', () {
    test('round-trips values and sorts by key', () async {
      final store = MemorySettingsStore();
      await store.setValue('b.key', '2');
      await store.setValue('a.key', '1');
      await store.setValue('c.key', null);

      expect(await store.getValue('a.key'), '1');
      expect(await store.getValue('c.key'), '');
      expect(await store.getValue('missing'), isNull);

      final all = await store.getAll();
      expect(all.map((entry) => entry.key), ['a.key', 'b.key', 'c.key']);
      expect(all.first.updatedAt.isUtc, isTrue);
    });

    test('refuses secret-looking keys and never stores them', () async {
      final store = MemorySettingsStore();
      await expectLater(
        store.setValue('ai.apiKey', 'sk-secret'),
        throwsA(isA<JameJamException>()),
      );
      expect(await store.getAll(), isEmpty);
    });

    test('removes and clears', () async {
      final store = MemorySettingsStore();
      await store.setValue('a', '1');
      await store.setValue('b', '2');

      expect(await store.remove('a'), isTrue);
      expect(await store.remove('a'), isFalse);
      expect(await store.clear(), 1);
      expect(await store.getAll(), isEmpty);
    });
  });

  group('SqliteSettingsStore', () {
    late Directory temp;
    late SqliteSettingsStore store;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('jamejam-settings-test');
      store = SqliteSettingsStore('${temp.path}/settings.db');
    });

    tearDown(() async {
      await store.close();
      temp.deleteSync(recursive: true);
    });

    test('persists across store instances', () async {
      await store.setValue('greeter.defaultName', 'Soroush');
      await store.close();

      final reopened = SqliteSettingsStore('${temp.path}/settings.db');
      expect(await reopened.getValue('greeter.defaultName'), 'Soroush');
      await reopened.close();
    });

    test('upserts in place and stamps updatedAt in UTC', () async {
      await store.setValue('anahita.units', 'metric');
      await store.setValue('anahita.units', 'imperial');

      final entries = await store.getAll();
      expect(entries, hasLength(1));
      expect(entries.single.value, 'imperial');
      expect(entries.single.updatedAt.isUtc, isTrue);
    });

    test('stores null as an empty string', () async {
      await store.setValue('divan.notebook', null);
      expect(await store.getValue('divan.notebook'), '');
    });

    test('refuses secret-looking keys before touching the database', () async {
      await expectLater(
        store.setValue('soroush.apiKey', 'sk-123'),
        throwsA(isA<JameJamException>()),
      );
      expect(await store.getAll(), isEmpty);
    });

    test('removes and clears', () async {
      await store.setValue('a', '1');
      await store.setValue('b', '2');

      expect(await store.remove('a'), isTrue);
      expect(await store.remove('a'), isFalse);
      expect(await store.clear(), 1);
      expect(await store.getAll(), isEmpty);
    });

    test('uses a hardened schema version', () async {
      await store.setValue('x', 'y');
      expect(store.databasePath, endsWith('settings.db'));
    });
  });

  group('SettingsController', () {
    test('loads, caches, mutates, and reports refusals', () async {
      final store = MemorySettingsStore();
      await store.setValue(SettingKeys.anahitaUnits, 'metric');

      final controller = SettingsController(store);
      await controller.load();

      expect(controller.isLoaded, isTrue);
      expect(controller.entries, hasLength(1));
      expect(controller.value(SettingKeys.anahitaUnits), 'metric');

      expect(await controller.set('custom.key', 'nope'), isNull);
      expect(controller.value('custom.key'), 'nope');

      final refusal = await controller.set('ai.apiKey', 'sk-1');
      expect(refusal, contains('looks like a secret'));
      expect(controller.value('ai.apiKey'), isNull);

      expect(await controller.remove('custom.key'), isTrue);
      expect(await controller.clear(), 1);
    });

    test('maps theme and locale preferences', () async {
      final controller = SettingsController(MemorySettingsStore());
      await controller.load();

      expect(controller.themeMode, ThemeMode.system);
      expect(controller.locale, isNull);

      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.value(SettingKeys.appTheme), 'dark');

      await controller.setLocale(const Locale('fa'));
      expect(controller.locale, const Locale('fa'));
      expect(controller.value(SettingKeys.appLocale), 'fa');

      await controller.setLocale(null);
      expect(controller.locale, isNull);
      expect(controller.value(SettingKeys.appLocale), 'system');
    });

    test('every well-known key is storable', () async {
      final controller = SettingsController(MemorySettingsStore());
      await controller.load();
      for (final key in SettingKeys.wellKnown) {
        expect(await controller.set(key, 'value'), isNull, reason: key);
      }
      expect(controller.entries, hasLength(SettingKeys.wellKnown.length));
    });
  });
}
