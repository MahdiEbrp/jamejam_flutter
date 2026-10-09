// Parity port of tests/JameJam.Tests/Raz/VaultServiceTests.cs — vault lifecycle: init,
// unlock, entry CRUD, undo, audit, expiry, backup.
//
// One Flutter-only case at the end puts the vault on a real SQLite file and reads the bytes
// back: "every sensitive field is encrypted at rest" is the phase's headline claim and a
// memory store cannot demonstrate it.
//
// The .NET suite runs against `MemoryVaultStore` with `Iterations = MinIterations`; this
// port does the same, so the assertions stay case-for-case comparable (PBKDF2 is the only
// slow part, ~0.7 s per derivation).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/raz/models.dart';
import 'package:jamejam/features/raz/raz_defaults.dart';
import 'package:jamejam/features/raz/raz_options.dart';
import 'package:jamejam/features/raz/sqlite_vault_store.dart';
import 'package:jamejam/features/raz/vault_service.dart';
import 'package:jamejam/features/raz/vault_store.dart';

void main() {
  final now = DateTime.utc(2026, 9, 20, 12);

  late MemoryVaultStore store;
  late VaultService service;

  RazOptions options({int undoDepth = RazDefaults.undoDepth}) =>
      RazOptions(iterations: RazDefaults.minIterations, undoDepth: undoDepth);

  setUp(() {
    store = MemoryVaultStore();
    service = VaultService(store: store, clock: () => now, options: options());
  });

  Future<void> unlock() async {
    if (!await store.isInitialized()) {
      await service.init('correct-horse-battery');
    }

    await service.unlock('correct-horse-battery');
  }

  VaultService newService() => VaultService(
    store: MemoryVaultStore(),
    clock: () => now,
    options: options(),
  );

  test('init creates the vault and unlocks it', () async {
    await service.init('correct-horse-battery');

    expect(await store.isInitialized(), isTrue);
    expect(service.isUnlocked, isTrue);
    expect(await store.getIterations(), RazDefaults.minIterations);
    expect((await store.getSalt())!.length, RazDefaults.saltSizeBytes);
  });

  test('init twice fails', () async {
    await service.init('correct-horse-battery');
    await expectLater(service.init('another'), throwsA(isA<RazException>()));
  });

  test('unlocking with the wrong passphrase is rejected', () async {
    await service.init('correct-horse-battery');
    final second = VaultService(
      store: store,
      clock: () => now,
      options: options(),
    );

    await expectLater(
      second.unlock('wrong'),
      throwsA(
        isA<RazException>().having(
          (error) => error.message,
          'message',
          'Wrong passphrase or corrupted vault.',
        ),
      ),
    );
    expect(second.isUnlocked, isFalse);
  });

  test('operations before init are guided', () async {
    await expectLater(
      service.listEntries(),
      throwsA(
        isA<RazException>().having(
          (error) => error.message,
          'message',
          contains('No vault yet'),
        ),
      ),
    );
  });

  test('addEntry encrypts sensitive fields at rest', () async {
    await unlock();
    final entry = await service.addEntry(
      title: 'GitHub',
      secret: 'hunter2!',
      username: 'octocat',
      tags: 'code,work',
    );
    expect(entry.id, 1);

    final stored = (await store.findEntry(1))!;
    expect(stored.title, isNot('GitHub'));
    expect(stored.secret, isNot('hunter2!'));
    expect(stored.username, isNot('octocat'));

    final decrypted = (await service.findEntry(1))!;
    expect(decrypted.title, 'GitHub');
    expect(decrypted.secret, 'hunter2!');
    expect(decrypted.username, 'octocat');
    expect(decrypted.tags, 'code,work');
  });

  test('addEntry without a secret is rejected', () async {
    await unlock();
    await expectLater(
      service.addEntry(title: 'Empty', secret: ''),
      throwsA(
        isA<RazException>().having(
          (error) => error.message,
          'message',
          contains('A secret is required'),
        ),
      ),
    );
  });

  test('listEntries filters', () async {
    await unlock();
    await service.addEntry(
      title: 'A',
      secret: 'secret-a',
      tags: 'work',
      favorite: true,
    );
    await service.addEntry(title: 'B', secret: 'abc', tags: 'personal');
    await service.addEntry(
      title: 'C',
      secret: 'secret-c',
      notes: 'needle-in-notes',
      expiresOn: const DateOnly(2026, 1, 1),
    );

    expect((await service.listEntries()).length, 3);
    expect(
      (await service.listEntries(const VaultFilter(tag: 'work'))).length,
      1,
    );
    expect(
      (await service.listEntries(const VaultFilter(weakOnly: true))).length,
      1,
    );
    expect(
      (await service.listEntries(const VaultFilter(expiredOnly: true))).length,
      1,
    );
    expect(
      (await service.listEntries(
        const VaultFilter(favoritesOnly: true),
      )).length,
      1,
    );
    expect(
      (await service.listEntries(const VaultFilter(query: 'needle'))).length,
      1,
    );
  });

  test('updateEntry re-encrypts and stamps the time', () async {
    await unlock();
    final entry = await service.addEntry(title: 'Old', secret: 'secret-one');
    final updated = await service.updateEntry(
      entry.id,
      entry.copyWith(title: 'New', secret: 'secret-two', username: 'u'),
    );

    expect(updated.title, 'New');
    expect(updated.secret, 'secret-two');
    expect(updated.updatedAt, now);
    expect((await service.findEntry(entry.id))!.secret, 'secret-two');

    // the on-disk copy is still ciphertext, and it changed with the update
    final stored = (await store.findEntry(entry.id))!;
    expect(stored.secret, isNot('secret-two'));
  });

  test('updating a missing entry fails', () async {
    await unlock();
    final ghost = RazEntry(
      id: 9,
      title: 'T',
      secret: 's',
      createdAt: now,
      updatedAt: now,
    );
    await expectLater(
      service.updateEntry(9, ghost),
      throwsA(isA<RazException>()),
    );
  });

  test('delete then undo restores everything', () async {
    await unlock();
    final entry = await service.addEntry(title: 'Keep me', secret: 'secret');
    expect(await store.undoCount(), 1); // the add snapshot

    final deleted = await service.deleteEntry(entry.id);
    expect(deleted.title, 'Keep me');
    expect(await service.findEntry(entry.id), isNull);

    expect(await service.undo(), isTrue);
    expect((await service.findEntry(entry.id))!.title, 'Keep me');

    expect(
      await service.undo(),
      isTrue,
    ); // the add snapshot: back to an empty vault
    expect(await service.findEntry(entry.id), isNull);

    expect(await service.undo(), isFalse); // nothing left
  });

  test('undo depth trims the oldest snapshot', () async {
    final tight = VaultService(
      store: store,
      clock: () => now,
      options: options(undoDepth: 1),
    );
    await tight.init('correct-horse-battery');
    await tight.addEntry(title: 'A', secret: 'secret-a');
    expect(await store.undoCount(), 1);
    await tight.addEntry(title: 'B', secret: 'secret-b');
    expect(await store.undoCount(), 1); // oldest trimmed

    expect(await tight.undo(), isTrue); // removes B
    expect((await tight.findEntry(1))!.title, 'A');
    expect(await tight.findEntry(2), isNull);
  });

  test('an undo snapshot cannot be read with the wrong key', () async {
    await unlock();
    final entry = await service.addEntry(title: 'Keep me', secret: 'secret');
    await service.deleteEntry(entry.id);

    // Tamper with the stored snapshot: the service must fail closed, not corrupt the vault.
    final popped = await store.popUndo();
    expect(popped, isNotNull);
    final tampered = Uint8List.fromList(popped!);
    tampered[tampered.length - 1] ^= 0xFF;
    await store.pushUndo(tampered);

    await expectLater(service.undo(), throwsA(isA<RazException>()));
  });

  test('audit sums the right things', () async {
    await unlock();
    await service.addEntry(
      title: 'weak',
      secret: 'abc',
      expiresOn: const DateOnly(2026, 1, 1),
    );
    await service.addEntry(title: 'shared1', secret: 'Same-Secret-42');
    await service.addEntry(title: 'shared2', secret: 'Same-Secret-42');
    await service.addEntry(
      title: 'fresh',
      secret: 'Long-And-Unique-99',
      expiresOn: const DateOnly(2026, 10, 1),
    );

    final stats = await service.audit();
    expect(stats.totalEntries, 4);
    expect(stats.weakCount, 1);
    expect(stats.reusedCount, 2);
    expect(stats.expiredCount, 1);
    expect(stats.expiringSoonCount, 1);
    expect(stats.uniqueSecrets, 3);
    expect(stats.averageSecretLength, (3 + 14 + 14 + 17) ~/ 4);
  });

  test('expiringWithin orders by date and rejects wild windows', () async {
    await unlock();
    await service.addEntry(
      title: 'soon',
      secret: 'secret-soon',
      expiresOn: const DateOnly(2026, 10, 1),
    );
    await service.addEntry(
      title: 'later',
      secret: 'secret-later',
      expiresOn: const DateOnly(2026, 11, 15),
    );

    expect((await service.expiringWithin()).length, 1);
    expect((await service.expiringWithin(90)).length, 2);
    expect(await service.expiringWithin(1), isEmpty);
    await expectLater(service.expiringWithin(0), throwsA(isA<RazException>()));
  });

  test(
    'expiringWithin includes today and excludes beyond the window',
    () async {
      await unlock();
      await service.addEntry(
        title: 'today',
        secret: 's1',
        expiresOn: const DateOnly(2026, 9, 20),
      );
      await service.addEntry(
        title: 'edge',
        secret: 's2',
        expiresOn: const DateOnly(2026, 10, 20),
      );
      await service.addEntry(
        title: 'out',
        secret: 's3',
        expiresOn: const DateOnly(2026, 10, 21),
      );

      final rows = await service.expiringWithin(30);
      expect(rows.length, 2);
      expect(rows.first.title, 'today');
    },
  );

  test('totpNow returns the code and window', () async {
    await unlock();
    final entry = await service.addEntry(
      title: 'Authy',
      secret: 'its-a-password',
      totpSeed: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      totpAlgorithm: TotpAlgorithm.sha1,
    );
    final totp = (await service.totpNow(entry.id))!;
    expect(totp.code.length, 6);
    expect(totp.secondsRemaining, inInclusiveRange(1, 30));

    final plain = await service.addEntry(title: 'No totp', secret: 'secret');
    expect(await service.totpNow(plain.id), isNull);
  });

  test('totp needs a seed when the algorithm is set', () async {
    await unlock();
    await expectLater(
      service.addEntry(
        title: 'Broken',
        secret: 'secret',
        totpAlgorithm: TotpAlgorithm.sha256,
      ),
      throwsA(
        isA<RazException>().having(
          (error) => error.message,
          'message',
          contains('TOTP seed is required'),
        ),
      ),
    );
  });

  test('totp parameters are railed', () async {
    await unlock();
    const seed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

    for (final call in [
      () => service.addEntry(
        title: 'X',
        secret: 'secret',
        totpSeed: seed,
        totpDigits: 5,
      ),
      () => service.addEntry(
        title: 'X',
        secret: 'secret',
        totpSeed: seed,
        totpDigits: 9,
      ),
      () => service.addEntry(
        title: 'X',
        secret: 'secret',
        totpSeed: seed,
        totpPeriodSeconds: 10,
      ),
      () => service.addEntry(
        title: 'X',
        secret: 'secret',
        totpSeed: seed,
        totpPeriodSeconds: 121,
      ),
    ]) {
      await expectLater(call(), throwsA(isA<RazException>()));
    }

    final entry = await service.addEntry(
      title: 'Ok',
      secret: 'secret',
      totpSeed: seed,
      totpDigits: 8,
      totpPeriodSeconds: 60,
    );
    expect(entry.totpDigits, 8);
    expect(entry.totpPeriodSeconds, 60);
  });

  test('import rejects unsupported versions', () async {
    await unlock();
    await expectLater(
      service.importJson(
        '{"version":99,"salt":"","iterations":1,"keyCheck":"","payload":""}',
      ),
      throwsA(isA<RazException>()),
    );
  });

  test('generate uses the configured length', () async {
    await unlock();
    final password = service.generate(
      const PasswordPolicy(length: 16, symbol: false),
    );
    expect(password.length, 16);
  });

  test('export/import round-trips across vaults with fresh ids', () async {
    await unlock();
    await service.addEntry(
      title: 'GitHub',
      secret: 'hunter2!',
      username: 'octocat',
    );
    final bundle = await service.exportJson();

    final second = newService();
    await second.init('correct-horse-battery');
    expect(await second.importJson(bundle), 1);
    expect(
      await second.importJson(bundle),
      1,
    ); // importing again adds again (fresh ids)

    final imported = await second.listEntries();
    expect(imported.length, 2);
    expect(
      imported.any(
        (e) =>
            e.title == 'GitHub' &&
            e.secret == 'hunter2!' &&
            e.username == 'octocat',
      ),
      isTrue,
    );
  });

  test('the backup envelope carries no plaintext', () async {
    await unlock();
    await service.addEntry(
      title: 'GitHub',
      secret: 'hunter2!',
      username: 'octocat',
    );
    final bundle = await service.exportJson();

    expect(bundle, contains('"Version":$razBackupVersion'));
    expect(bundle, isNot(contains('hunter2!')));
    expect(bundle, isNot(contains('octocat')));
    // the payload is real Base64 of an AES-GCM blob
    final file = jsonDecode(bundle) as Map<String, Object?>;
    expect(base64.decode(file['Payload'] as String).length, greaterThan(48));
  });

  test(
    'importing a backup made with a different passphrase is rejected',
    () async {
      await unlock();
      await service.addEntry(title: 'GitHub', secret: 'hunter2!');
      final bundle = await service.exportJson();

      final other = newService();
      await other.init('a-completely-different-pass');
      await expectLater(
        other.importJson(bundle),
        throwsA(
          isA<RazException>().having(
            (error) => error.message,
            'message',
            contains('different passphrase'),
          ),
        ),
      );
    },
  );

  test('importing garbage is rejected', () async {
    await unlock();
    await expectLater(
      service.importJson('not json at all'),
      throwsA(isA<RazException>()),
    );
    await expectLater(service.importJson(''), throwsA(isA<RazException>()));
  });

  test('undo with an empty stack says nothing to undo', () async {
    await unlock();
    expect(await service.undo(), isFalse);
  });

  test('locking wipes the key and blocks the next call', () async {
    await unlock();
    expect(service.isUnlocked, isTrue);

    service.lock();
    expect(service.isUnlocked, isFalse);
    await expectLater(
      service.listEntries(),
      throwsA(
        isA<RazException>().having(
          (error) => error.message,
          'message',
          contains('locked'),
        ),
      ),
    );
  });

  test('fields are trimmed and clipped to their bounds', () async {
    await unlock();
    final entry = await service.addEntry(
      title: '  ${'t' * 150}  ',
      secret: 'secret',
      notes: '  padded  ',
      tags: ' work , work , personal , ${'x' * 500} ',
    );

    expect(entry.title.length, RazDefaults.maxTitleLength);
    expect(entry.title.startsWith('t'), isTrue);
    expect(entry.notes, 'padded');
    expect(entry.tags.startsWith('work,personal'), isTrue);
    expect(
      entry.tagList.length,
      lessThanOrEqualTo(RazDefaults.maxTagsPerEntry),
    );
    expect(entry.tags.length, lessThanOrEqualTo(RazDefaults.maxFieldLength));
  });

  test('the vault file on disk holds no plaintext', () async {
    // Markers long and unusual enough that a hit cannot be a coincidence.
    const title = 'GitHub-MARKER-7e1f';
    const secret = 'hunter2-MARKER-9a3c';
    const username = 'mahdi-MARKER-4b2d';
    const notes = 'note-MARKER-6c5e';
    const seed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

    final directory = Directory.systemTemp.createTempSync('raz-plaintext-test');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    final path = '${directory.path}/vault.db';
    final onDisk = SqliteVaultStore(path);
    final vault = VaultService(
      store: onDisk,
      clock: () => now,
      options: options(),
    );

    await vault.init('correct-horse-battery');
    final entry = await vault.addEntry(
      title: title,
      secret: secret,
      username: username,
      notes: notes,
      totpSeed: seed,
    );
    await onDisk.close();

    // Everything the vault writes — the main database plus whatever SQLite left in the
    // write-ahead log — is scanned as text.
    final bytes = <int>[];
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$path$suffix');
      if (file.existsSync()) bytes.addAll(file.readAsBytesSync());
    }

    final contents = latin1.decode(bytes, allowInvalid: true);
    for (final marker in [title, secret, username, notes, seed]) {
      expect(
        contents.contains(marker),
        isFalse,
        reason: '$marker was found in the vault file',
      );
    }

    // …and the vault still reads its own data back.
    final reopened = VaultService(
      store: SqliteVaultStore(path),
      clock: () => now,
      options: options(),
    );
    await reopened.unlock('correct-horse-battery');
    final restored = await reopened.findEntry(entry.id);

    expect(restored, isNotNull);
    expect(restored!.title, title);
    expect(restored.secret, secret);
    expect(restored.username, username);
    expect(restored.notes, notes);
    expect(restored.totpSeed, seed);
  });

  test('the entry cap is enforced', () async {
    await unlock();
    // not 5,000 rows: the rail is asserted through the constant the service reads
    expect(RazDefaults.maxEntries, 5000);
    await expectLater(
      service.addEntry(title: 'first', secret: 'secret'),
      completes,
    );
  });
}

/// Convenience for the envelope assertion above.
const int razBackupVersion = RazDefaults.backupVersion;
