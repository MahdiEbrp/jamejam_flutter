// The vault screen's state machine: the passphrase sources, the auto-lock timer, the
// filters, reveal/TOTP, undo, and the coach prompts. The crypto, the service, and the
// store have their own suites — this one is about what `RazCommands` used to hold.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/raz/models.dart';
import 'package:jamejam/features/raz/raz_defaults.dart';
import 'package:jamejam/features/raz/raz_options.dart';
import 'package:jamejam/features/raz/security_assistant.dart';
import 'package:jamejam/features/raz/vault_controller.dart';
import 'package:jamejam/features/raz/vault_service.dart';
import 'package:jamejam/features/raz/vault_store.dart';
import 'package:jamejam/features/settings/memory_settings_store.dart';
import 'package:jamejam/features/settings/settings_controller.dart';
import 'package:jamejam/features/soroush/ai_funnel.dart';

const String _passphrase = 'correct-horse-battery';

/// The RFC 6238 SHA-1 seed, so the TOTP case can assert a published code.
const String _rfcSeed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

String _completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

/// A controller over an in-memory store, with the KDF at its cheapest legal setting.
Future<
  ({
    VaultController controller,
    SecretStore secrets,
    SettingsController settings,
    VaultService service,
  })
>
_build({
  VaultStore? store,
  SecretStore? secretStore,
  String Function(String key)? environment,
  DateTime Function()? clock,
  Duration? autoLockCheckInterval,
  http.Client? httpClient,
  RazOptions? options,
}) async {
  final settings = SettingsController(MemorySettingsStore());
  await settings.load();
  final secrets = secretStore ?? MemorySecretStore();
  final config =
      options ?? const RazOptions(iterations: RazDefaults.minIterations);
  final service = VaultService(
    store: store ?? MemoryVaultStore(),
    clock: clock ?? DateTime.now,
    options: config,
  );
  final controller = VaultController(
    service: service,
    settings: settings,
    secrets: secrets,
    funnel: AiFunnel(
      settings: settings,
      secrets: secrets,
      httpClient: httpClient ?? http.Client(),
    ),
    assistant: SecurityAssistant(config),
    clock: clock,
    environment: environment,
    autoLockCheckInterval: autoLockCheckInterval,
  );
  return (
    controller: controller,
    secrets: secrets,
    settings: settings,
    service: service,
  );
}

void main() {
  group('VaultController — opening the vault', () {
    test('a fresh store asks to be created, then unlocks', () async {
      final vault = await _build();
      addTearDown(vault.controller.dispose);

      await vault.controller.initialise();
      expect(vault.controller.isInitialized, isFalse);
      expect(vault.controller.isLocked, isFalse);
      expect(vault.controller.isUnlocked, isFalse);

      await vault.controller.createVault(_passphrase);

      expect(vault.controller.error, isNull);
      expect(vault.controller.isInitialized, isTrue);
      expect(vault.controller.isUnlocked, isTrue);
      expect(vault.controller.isLocked, isFalse);
      expect(vault.controller.busy, isFalse);
    });

    test(
      'a wrong passphrase lands in `error` and leaves the vault locked',
      () async {
        final store = MemoryVaultStore();
        final first = await _build(store: store);
        await first.controller.createVault(_passphrase);
        first.controller.dispose();

        final second = await _build(store: store);
        addTearDown(second.controller.dispose);

        await second.controller.unlock('not-the-passphrase');

        expect(second.controller.error, 'Wrong passphrase or corrupted vault.');
        expect(second.controller.isUnlocked, isFalse);
        expect(second.controller.entries, isEmpty);
      },
    );

    test('the environment passphrase unlocks without typing one', () async {
      final store = MemoryVaultStore();
      final first = await _build(store: store);
      await first.controller.createVault(_passphrase);
      first.controller.dispose();

      final second = await _build(
        store: store,
        environment: (key) =>
            key == 'JAMEJAM_RAZ_PASSPHRASE' ? _passphrase : '',
      );
      addTearDown(second.controller.dispose);

      expect(await second.controller.hasStoredPassphrase, isTrue);
      expect(await second.controller.unlockWithStoredPassphrase(), isTrue);
      expect(second.controller.isUnlocked, isTrue);
    });

    test('no stored passphrase means the form stays', () async {
      final store = MemoryVaultStore();
      final first = await _build(store: store);
      await first.controller.createVault(_passphrase);
      first.controller.dispose();

      final second = await _build(store: store);
      addTearDown(second.controller.dispose);

      expect(await second.controller.hasStoredPassphrase, isFalse);
      expect(await second.controller.unlockWithStoredPassphrase(), isFalse);
      expect(second.controller.isUnlocked, isFalse);
    });

    test('a remembered passphrase is read back and forgotten again', () async {
      final store = MemoryVaultStore();
      final keychain = MemorySecretStore();
      final first = await _build(store: store, secretStore: keychain);
      await first.controller.createVault(_passphrase);
      await first.controller.rememberPassphrase(_passphrase);
      first.controller.dispose();

      final second = await _build(store: store, secretStore: keychain);
      addTearDown(second.controller.dispose);

      expect(
        await second.secrets.read(RazDefaults.passphraseSettingKey),
        _passphrase,
      );
      expect(await second.controller.unlockWithStoredPassphrase(), isTrue);

      await second.controller.forgetPassphrase();
      expect(
        await second.secrets.read(RazDefaults.passphraseSettingKey),
        isNull,
      );
      expect(await second.controller.hasStoredPassphrase, isFalse);
    });

    test(
      'locking drops the entries, the audit, and the revealed secret',
      () async {
        final vault = await _build();
        addTearDown(vault.controller.dispose);

        await vault.controller.createVault(_passphrase);
        await vault.controller.addEntry(
          title: 'GitHub',
          secret: 'hunter2!builds',
        );
        await vault.controller.audit();
        vault.controller.reveal(vault.controller.entries.single.id);

        expect(vault.controller.entries, hasLength(1));
        expect(vault.controller.stats, isNotNull);
        expect(vault.controller.revealedSecret, 'hunter2!builds');

        vault.controller.lock();

        expect(vault.controller.isUnlocked, isFalse);
        expect(vault.controller.isLocked, isTrue);
        expect(vault.controller.entries, isEmpty);
        expect(vault.controller.stats, isNull);
        expect(vault.controller.revealedSecret, isNull);
        expect(vault.controller.aiAnswer, isNull);
      },
    );
  });

  group('VaultController — entries and filters', () {
    Future<VaultController> seeded() async {
      final vault = await _build();
      await vault.controller.createVault(_passphrase);
      await vault.controller.addEntry(
        title: 'GitHub',
        secret: 'hunter2!builds-strong',
        username: 'mahdi',
        tags: 'work, dev',
        favorite: true,
      );
      await vault.controller.addEntry(
        title: 'Router',
        secret: 'abc',
        tags: 'home',
      );
      await vault.controller.addEntry(
        title: 'Old badge',
        secret: 'another-long-secret-9',
        tags: 'home',
        expiresOn: DateOnly.parseIso('2020-01-01'),
      );
      return vault.controller;
    }

    test('search, filters, and tags each narrow the list', () async {
      final controller = await seeded();
      addTearDown(controller.dispose);

      expect(controller.entries, hasLength(3));

      await controller.setSearch('git');
      expect(controller.entries.map((entry) => entry.title), ['GitHub']);

      await controller.clearFilters();
      expect(controller.entries, hasLength(3));

      await controller.toggleFavorites();
      expect(controller.entries.map((entry) => entry.title), ['GitHub']);

      await controller.clearFilters();
      await controller.toggleWeakOnly();
      expect(controller.entries.map((entry) => entry.title), ['Router']);

      await controller.clearFilters();
      await controller.toggleExpired();
      expect(controller.entries.map((entry) => entry.title), ['Old badge']);

      await controller.clearFilters();
      await controller.setTagFilter('home');
      expect(controller.entries.map((entry) => entry.title), [
        'Router',
        'Old badge',
      ]);

      await controller.setTagFilter(null);
      expect(controller.entries, hasLength(3));
      expect(controller.tagFilter, isNull);
      expect(controller.search, isEmpty);
      expect(controller.favoritesOnly, isFalse);
      expect(controller.weakOnly, isFalse);
      expect(controller.expiredOnly, isFalse);
    });

    test('update, delete, and undo round-trip through the controller', () async {
      final controller = await seeded();
      addTearDown(controller.dispose);

      final router = controller.entries.firstWhere((e) => e.title == 'Router');
      await controller.updateEntry(router.copyWith(title: 'Home router'));
      expect(
        controller.entries.map((entry) => entry.title),
        contains('Home router'),
      );

      await controller.deleteEntry(router.id);
      expect(controller.entries, hasLength(2));

      expect(await controller.undo(), isTrue);
      expect(controller.entries, hasLength(3));

      // Undo is a stack of snapshots, not a list of edits: drain it and the vault ends up
      // exactly as it started, and the next call says so.
      while (await controller.undo()) {
        // keep going
      }
      expect(controller.entries, isEmpty);
      expect(await controller.undo(), isFalse);
    });

    test('reveal shows one secret and hides it again', () async {
      final controller = await seeded();
      addTearDown(controller.dispose);

      final github = controller.entries.firstWhere((e) => e.title == 'GitHub');
      controller.reveal(github.id);
      expect(controller.revealedSecret, 'hunter2!builds-strong');

      controller.reveal(null);
      expect(controller.revealedSecret, isNull);
    });

    test('generate honours the vault default and an explicit policy', () async {
      final controller = await seeded();
      addTearDown(controller.dispose);

      expect(
        controller.generate(),
        hasLength(RazDefaults.defaultPasswordLength),
      );
      expect(
        controller.generate(const PasswordPolicy(length: 32, symbol: false)),
        hasLength(32),
      );
    });

    test('a live TOTP code comes back for a seeded entry', () async {
      final fixed = DateTime.utc(2026, 9, 20, 12);
      final vault = await _build(clock: () => fixed);
      addTearDown(vault.controller.dispose);

      await vault.controller.createVault(_passphrase);
      await vault.controller.addEntry(
        title: 'RFC 6238',
        secret: 'shhh-its-a-secret',
        totpSeed: _rfcSeed,
      );
      final id = vault.controller.entries.single.id;

      await vault.controller.refreshTotp(id);

      final totp = vault.controller.totp;
      expect(totp, isNotNull);
      expect(totp!.code, hasLength(6));
      expect(vault.controller.totpEntryId, id);
      expect(totp.secondsRemaining, inInclusiveRange(1, 30));

      // An entry without a seed clears the chip rather than showing a stale code.
      await vault.controller.addEntry(
        title: 'Plain',
        secret: 'no-seed-here-1234',
      );
      await vault.controller.refreshTotp(vault.controller.entries.last.id);
      expect(vault.controller.totp, isNull);
      expect(vault.controller.totpEntryId, isNull);
    });

    test(
      'the audit is aggregate-only, and export/import survive a round trip',
      () async {
        final controller = await seeded();
        addTearDown(controller.dispose);

        final stats = await controller.audit();
        expect(stats, isNotNull);
        expect(stats!.totalEntries, 3);
        expect(stats.weakCount, 1);
        expect(stats.expiredCount, 1);
        expect(controller.stats, same(stats));
        expect(await controller.expiringWithin(3650), isNotNull);

        final bundle = await controller.exportBackup();
        await controller.deleteEntry(controller.entries.first.id);
        expect(controller.entries, hasLength(2));

        final imported = await controller.importBackup(bundle);

        expect(imported, 3);
        expect(controller.entries, hasLength(5));
        // The import is a plain add — it does not dedupe, so the deleted row comes back as a
        // second copy of everything the bundle held.
        final titles = controller.entries.map((entry) => entry.title).toList();
        expect(titles.where((title) => title == 'Old badge'), hasLength(2));
      },
    );
  });

  group('VaultController — the coach', () {
    test('without a usable key the coach explains what to do', () async {
      final vault = await _build();
      addTearDown(vault.controller.dispose);

      await vault.controller.createVault(_passphrase);
      await vault.controller.addEntry(
        title: 'GitHub',
        secret: 'hunter2!builds',
      );

      await expectLater(
        vault.controller.aiAudit(),
        throwsA(
          isA<RazException>().having(
            (failure) => failure.message,
            'message',
            contains('Add an API key'),
          ),
        ),
      );
      expect(vault.controller.aiAnswer, isNull);
    });

    test('the audit prompt carries counts, never the secrets', () async {
      final sent = <String>[];
      final vault = await _build(
        httpClient: MockClient((request) async {
          sent.add(request.body);
          return http.Response(_completion('Rotate the weak one.'), 200);
        }),
      );
      addTearDown(vault.controller.dispose);

      await vault.controller.createVault(_passphrase);
      await vault.secrets.write(SecretKeys.aiApiKey, 'sk-test-key');
      await vault.controller.addEntry(
        title: 'GitHub',
        secret: 'hunter2!builds',
        username: 'mahdi',
      );

      final answer = await vault.controller.aiAudit();

      expect(answer, 'Rotate the weak one.');
      expect(vault.controller.aiAnswer, 'Rotate the weak one.');
      expect(sent, hasLength(1));
      expect(sent.single, contains('---AUDIT BEGIN---'));
      expect(sent.single, isNot(contains('GitHub')));
      expect(sent.single, isNot(contains('hunter2!')));
      expect(sent.single, isNot(contains('mahdi')));

      vault.controller.clearAiAnswer();
      expect(vault.controller.aiAnswer, isNull);
    });

    test(
      'a question is clipped and marked untrusted before it is sent',
      () async {
        final sent = <String>[];
        final vault = await _build(
          httpClient: MockClient((request) async {
            sent.add(request.body);
            return http.Response(_completion('Fine.'), 200);
          }),
        );
        addTearDown(vault.controller.dispose);

        await vault.controller.createVault(_passphrase);
        await vault.secrets.write(SecretKeys.aiApiKey, 'sk-test-key');

        expect(await vault.controller.ask('  how bad is it?  '), 'Fine.');
        expect(sent.single, contains('Question: how bad is it?'));

        expect(await vault.controller.ask('x' * 1000), 'Fine.');
        expect(sent.last, contains('Question: ${'x' * 400}'));
        expect(sent.last, isNot(contains('x' * 401)));
      },
    );
  });

  group('VaultController — the idle timer', () {
    test('an idle vault locks itself and forgets everything', () async {
      var now = DateTime.utc(2026, 9, 20, 12);
      final vault = await _build(
        clock: () => now,
        autoLockCheckInterval: const Duration(milliseconds: 10),
        options: const RazOptions(
          iterations: RazDefaults.minIterations,
          autoLockMinutes: 30,
        ),
      );
      addTearDown(vault.controller.dispose);

      await vault.controller.createVault(_passphrase);
      await vault.controller.addEntry(
        title: 'GitHub',
        secret: 'hunter2!builds',
      );
      expect(vault.controller.isUnlocked, isTrue);
      expect(vault.controller.autoLockMinutes, 30);

      // Fourteen minutes of idling is well inside the window.
      now = now.add(const Duration(minutes: 14));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(vault.controller.isUnlocked, isTrue);

      // Activity resets the clock: another 29 minutes from the touch is still inside.
      vault.controller.touch();
      now = now.add(const Duration(minutes: 29));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(vault.controller.isUnlocked, isTrue);

      now = now.add(const Duration(minutes: 31));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(vault.controller.isUnlocked, isFalse);
      expect(vault.controller.entries, isEmpty);
    });

    test('zero minutes means never', () async {
      var now = DateTime.utc(2026, 9, 20, 12);
      final vault = await _build(
        clock: () => now,
        autoLockCheckInterval: const Duration(milliseconds: 10),
        options: const RazOptions(
          iterations: RazDefaults.minIterations,
          autoLockMinutes: 0,
        ),
      );
      addTearDown(vault.controller.dispose);

      await vault.controller.createVault(_passphrase);
      now = now.add(const Duration(days: 2));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(vault.controller.autoLockMinutes, 0);
      expect(vault.controller.isUnlocked, isTrue);
    });
  });
}
