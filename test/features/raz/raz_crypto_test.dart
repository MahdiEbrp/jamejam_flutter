// Parity port of tests/JameJam.Tests/Raz/RazCoreTests.cs — option rails, Base32, the RFC
// 6238 TOTP vectors, the strength meter, generator policy, and the AES-GCM/PBKDF2 core.
//
// The crypto assertions are deliberately implementation-independent: every derived key is
// cross-checked against PointyCastle (a second, unrelated implementation), so a silent
// behaviour change in the PBKDF2 backend cannot pass unnoticed.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/raz/base32.dart';
import 'package:jamejam/features/raz/models.dart';
import 'package:jamejam/features/raz/password_generator.dart';
import 'package:jamejam/features/raz/raz_defaults.dart';
import 'package:jamejam/features/raz/raz_options.dart';
import 'package:jamejam/features/raz/strength_meter.dart';
import 'package:jamejam/features/raz/totp.dart';
import 'package:jamejam/features/raz/vault_crypto.dart';
import 'package:pointycastle/export.dart' as pointycastle;

void main() {
  group('RazOptions rails', () {
    test('the defaults are valid', () {
      expect(const RazOptions().validate, returnsNormally);
    });

    test('iterations have rails', () {
      expect(
        () => const RazOptions(iterations: 99999).validate(),
        throwsRangeError,
      );
      expect(
        () => const RazOptions(iterations: 10000001).validate(),
        throwsRangeError,
      );
      expect(
        () =>
            const RazOptions(iterations: RazDefaults.minIterations).validate(),
        returnsNormally,
      );
    });

    test('undo depth has rails', () {
      expect(
        () => const RazOptions(undoDepth: -1).validate(),
        throwsRangeError,
      );
      expect(
        () => const RazOptions(undoDepth: 101).validate(),
        throwsRangeError,
      );
    });

    test('password length has rails', () {
      expect(
        () => const RazOptions(passwordLength: 7).validate(),
        throwsRangeError,
      );
      expect(
        () => const RazOptions(passwordLength: 257).validate(),
        throwsRangeError,
      );
    });

    test('expiring-soon window has rails', () {
      expect(
        () => const RazOptions(expiringSoonDays: 0).validate(),
        throwsRangeError,
      );
      expect(
        () => const RazOptions(expiringSoonDays: 3651).validate(),
        throwsRangeError,
      );
    });

    test('rotation age has rails', () {
      expect(
        () => const RazOptions(oldAfterDays: 0).validate(),
        throwsRangeError,
      );
      expect(
        () => const RazOptions(oldAfterDays: 3651).validate(),
        throwsRangeError,
      );
    });

    test('weak-score threshold has rails', () {
      expect(
        () => const RazOptions(weakScoreThreshold: -1).validate(),
        throwsRangeError,
      );
      expect(
        () => const RazOptions(weakScoreThreshold: 4).validate(),
        throwsRangeError,
      );
    });

    test('auto-lock window has rails', () {
      expect(
        () => const RazOptions(autoLockMinutes: -1).validate(),
        throwsRangeError,
      );
      expect(
        () => const RazOptions(
          autoLockMinutes: RazDefaults.maxAutoLockMinutes + 1,
        ).validate(),
        throwsRangeError,
      );
      expect(
        () => const RazOptions(autoLockMinutes: 0).validate(),
        returnsNormally,
      );
    });

    test(
      'environment overrides are read from the map, and copyWith keeps the rest',
      () {
        final fromEnv = RazOptions.fromEnvironment(const {
          'JAMEJAM_RAZ_ITERATIONS': '150000',
          'JAMEJAM_RAZ_AUTO_LOCK_MINUTES': '15',
        });

        expect(fromEnv.iterations, 150000);
        expect(fromEnv.autoLockMinutes, 15);
        expect(fromEnv.undoDepth, RazDefaults.undoDepth);
        expect(fromEnv.copyWith(iterations: 120000).iterations, 120000);
        expect(fromEnv.copyWith(iterations: 120000).autoLockMinutes, 15);
      },
    );
  });

  group('Base32', () {
    test('encode matches the RFC vector', () {
      final seed = utf8.encode('12345678901234567890');
      expect(Base32.encode(seed), 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      expect(Base32.encode(const []), '');
    });

    for (final text in const [
      'hello',
      's3cret-data-42',
      '\u0001\u0002\u0003',
    ]) {
      test('decode reverses encode: $text', () {
        final bytes = utf8.encode(text);
        expect(Base32.decode(Base32.encode(bytes)), bytes);
      });
    }

    test('decode ignores case, padding and whitespace', () {
      final expected = Base32.decode('GEZDGNBV');
      expect(Base32.decode('gezdgnbv'), expected);
      expect(Base32.decode('GEZDGNBV======'), expected);
      expect(Base32.decode(' GEZD GNBV '), expected);
    });

    test('decode rejects invalid characters and empty input', () {
      expect(() => Base32.decode('abc123!'), throwsFormatException);
      expect(() => Base32.decode(''), throwsArgumentError);
    });
  });

  group('TOTP (RFC 6238)', () {
    final t59 = DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true);
    const sha1Seed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

    test('SHA-1 vector at T=59', () async {
      expect(await Totp.computeCode(sha1Seed, t59, digits: 8), '94287082');
    });

    test('six digits is the truncation of the RFC value', () async {
      final code = await Totp.computeCode(sha1Seed, t59);
      expect(code, hasLength(6));
      expect(code, '287082');
    });

    test('SHA-256 vector at T=59', () async {
      final seed = Base32.encode(
        utf8.encode('12345678901234567890123456789012'),
      );
      expect(
        await Totp.computeCode(
          seed,
          t59,
          digits: 8,
          algorithm: TotpAlgorithm.sha256,
        ),
        '46119246',
      );
    });

    test('SHA-512 vector at T=59', () async {
      final secret64 = '12345678901234567890' * 3 + '1234';
      final seed = Base32.encode(ascii.encode(secret64));
      expect(
        await Totp.computeCode(
          seed,
          t59,
          digits: 8,
          algorithm: TotpAlgorithm.sha512,
        ),
        '90693936',
      );
    });

    test('the counter rolls over with the period', () async {
      final early = await Totp.computeCode(
        sha1Seed,
        DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true),
      );
      final late = await Totp.computeCode(
        sha1Seed,
        DateTime.fromMillisecondsSinceEpoch(88 * 1000, isUtc: true),
      );
      expect(early, isNot(late));
    });

    test('seconds remaining counts down', () {
      final time = DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true);
      expect(Totp.secondsRemaining(time), 1);
      expect(
        Totp.secondsRemaining(time.subtract(const Duration(seconds: 29))),
        30,
      );
    });

    test(
      'codeFor is null without a seed, and matches computeCode with one',
      () async {
        final now = DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true);
        final plain = RazEntry(
          title: 'x',
          secret: 's',
          createdAt: now,
          updatedAt: now,
        );
        expect(await Totp.codeFor(plain, now), isNull);

        final withSeed = plain.copyWith(
          totpSeed: sha1Seed,
          totpAlgorithm: TotpAlgorithm.sha1,
          totpDigits: 6,
          totpPeriodSeconds: 30,
        );
        expect(
          await Totp.codeFor(withSeed, now),
          await Totp.computeCode(
            sha1Seed,
            now,
            periodSeconds: 30,
            digits: 6,
            algorithm: TotpAlgorithm.sha1,
          ),
        );
      },
    );
  });

  group('StrengthMeter', () {
    test('empty is zero', () {
      expect(StrengthMeter.score('').score, 0);
      expect(StrengthMeter.score('').issues, ['empty secret']);
    });

    test('a long mixed secret scores excellent', () {
      final strength = StrengthMeter.score('Correct-Horse-Battery-42!');
      expect(strength.score, 4);
      expect(strength.label, 'excellent');
      expect(strength.issues, isEmpty);
    });

    test('repeats and sequences are penalized', () {
      expect(
        StrengthMeter.score('aaaaaaaa').issues,
        contains('repeated characters'),
      );
      expect(
        StrengthMeter.score('Xabc1234').issues,
        contains('sequential characters'),
      );
    });

    test('a short numeric secret is very weak', () {
      final strength = StrengthMeter.score('1234');
      expect(strength.score, 0);
      expect(strength.label, 'very weak');
    });
  });

  group('PasswordGenerator', () {
    test('honors the length and includes every class', () {
      final password = PasswordGenerator.generate(
        const PasswordPolicy(length: 24),
      );
      expect(password.length, 24);
      expect(password.contains(RegExp('[a-z]')), isTrue);
      expect(password.contains(RegExp('[A-Z]')), isTrue);
      expect(password.contains(RegExp('[0-9]')), isTrue);
      expect(password.contains(RegExp('[^A-Za-z0-9]')), isTrue);
    });

    test('a no-symbols policy is honored', () {
      final password = PasswordGenerator.generate(
        const PasswordPolicy(length: 32, symbol: false),
      );
      expect(password, matches(RegExp('^[A-Za-z0-9]+\$')));
    });

    test('excludeAmbiguous drops look-alikes', () {
      for (var i = 0; i < 10; i++) {
        final password = PasswordGenerator.generate(
          const PasswordPolicy(length: 64, excludeAmbiguous: true),
        );
        for (final char in password.split('')) {
          expect(
            PasswordGenerator.ambiguous.contains(char),
            isFalse,
            reason: char,
          );
        }
      }
    });

    test('digits only still generates', () {
      final password = PasswordGenerator.generate(
        const PasswordPolicy(
          length: 12,
          lower: false,
          upper: false,
          symbol: false,
        ),
      );
      expect(password, matches(RegExp('^[0-9]+\$')));
    });

    test('the length is railed and a class-less policy is rejected', () {
      expect(
        () => PasswordGenerator.generate(const PasswordPolicy(length: 7)),
        throwsRangeError,
      );
      expect(
        () => PasswordGenerator.generate(const PasswordPolicy(length: 257)),
        throwsRangeError,
      );
      expect(
        () => PasswordGenerator.generate(
          const PasswordPolicy(
            lower: false,
            upper: false,
            digit: false,
            symbol: false,
          ),
        ),
        throwsRangeError,
      );
    });

    test('two draws differ (the CSPRNG is actually consulted)', () {
      final a = PasswordGenerator.generate(const PasswordPolicy(length: 32));
      final b = PasswordGenerator.generate(const PasswordPolicy(length: 32));
      expect(a, isNot(b));
    });
  });

  group('VaultCrypto', () {
    final key = Uint8List.fromList(
      List<int>.generate(
        RazDefaults.keySizeBytes,
        (_) => Random().nextInt(256),
      ),
    );

    for (final plaintext in const ['hunter2!', '', 'unicode-سلام']) {
      test('round-trips "$plaintext"', () async {
        final payload = await VaultCrypto.encrypt(key, plaintext);
        expect(await VaultCrypto.decrypt(key, payload), plaintext);
      });
    }

    test('the wire format is nonce || ciphertext || tag', () async {
      final payload = await VaultCrypto.encrypt(key, 'secret');
      expect(
        payload.length,
        RazDefaults.nonceSizeBytes + 'secret'.length + RazDefaults.tagSizeBytes,
      );
      expect(await VaultCrypto.decrypt(key, payload), 'secret');
    });

    test('a tampered payload fails authentication', () async {
      final payload = await VaultCrypto.encrypt(key, 'secret');
      payload[payload.length - 1] ^= 0xFF;
      await expectLater(
        VaultCrypto.decrypt(key, payload),
        throwsA(isA<VaultCryptoException>()),
      );
    });

    test('a wrong key fails authentication', () async {
      final payload = await VaultCrypto.encrypt(key, 'secret');
      await expectLater(
        VaultCrypto.decrypt(Uint8List(RazDefaults.keySizeBytes), payload),
        throwsA(isA<VaultCryptoException>()),
      );
    });

    test('a truncated payload is rejected', () async {
      await expectLater(
        VaultCrypto.decrypt(key, const [1, 2, 3]),
        throwsA(isA<VaultCryptoException>()),
      );
    });

    test('a fixed nonce makes the ciphertext reproducible', () async {
      final nonce = List<int>.generate(RazDefaults.nonceSizeBytes, (i) => i);
      final first = await VaultCrypto.encryptWithNonce(key, 'same', nonce);
      final second = await VaultCrypto.encryptWithNonce(key, 'same', nonce);
      expect(first, second);

      // …and a different nonce changes it, exactly as a fresh draw would.
      final other = await VaultCrypto.encryptWithNonce(
        key,
        'same',
        List<int>.generate(RazDefaults.nonceSizeBytes, (i) => i + 1),
      );
      expect(other, isNot(first));
    });

    test('wipe zeroes key material', () {
      final material = Uint8List(8)..fillRange(0, 8, 7);
      VaultCrypto.wipe(material);
      expect(material.every((byte) => byte == 0), isTrue);
      expect(() => VaultCrypto.wipe(null), returnsNormally);
    });

    test('Base64 helpers round-trip', () async {
      final payload = await VaultCrypto.encrypt(key, 'text');
      expect(VaultCrypto.fromText(VaultCrypto.toText(payload)), payload);
    });

    test('the salt length and iteration floor are enforced', () async {
      await expectLater(
        VaultCrypto.deriveKey('passphrase', List<int>.filled(16, 1), 100000),
        throwsRangeError,
      );
      await expectLater(
        VaultCrypto.deriveKey(
          'passphrase',
          List<int>.filled(RazDefaults.saltSizeBytes, 1),
          99999,
        ),
        throwsRangeError,
      );
      await expectLater(
        VaultCrypto.deriveKey('   ', List<int>.filled(32, 1), 100000),
        throwsA(isA<RazCryptoArgumentException>()),
      );
    });

    test(
      'derivation is deterministic per salt and strongly different across salts',
      () async {
        final salt = Uint8List.fromList(
          List<int>.generate(RazDefaults.saltSizeBytes, (i) => i),
        );
        final again = await VaultCrypto.deriveKey(
          'passphrase',
          salt,
          RazDefaults.minIterations,
        );
        expect(
          await VaultCrypto.deriveKey(
            'passphrase',
            salt,
            RazDefaults.minIterations,
          ),
          again,
        );

        final otherSalt = Uint8List.fromList(
          List<int>.generate(RazDefaults.saltSizeBytes, (i) => i + 1),
        );
        expect(
          await VaultCrypto.deriveKey(
            'passphrase',
            otherSalt,
            RazDefaults.minIterations,
          ),
          isNot(again),
        );
        expect(
          await VaultCrypto.deriveKey(
            'Passphrase',
            salt,
            RazDefaults.minIterations,
          ),
          isNot(again),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'an independent implementation derives the same key',
      () async {
        // PointyCastle is a second, unrelated PBKDF2-HMAC-SHA512 implementation: if
        // `package:cryptography` ever changes behaviour, this fails loudly.
        final salt = Uint8List.fromList(List<int>.filled(32, 9));
        final ours = await VaultCrypto.deriveKey('passphrase', salt, 100000);

        final derivator = pointycastle.PBKDF2KeyDerivator(
          pointycastle.HMac(pointycastle.SHA512Digest(), 128),
        )..init(pointycastle.Pbkdf2Parameters(salt, 100000, 32));
        final theirs = derivator.process(
          Uint8List.fromList(utf8.encode('passphrase')),
        );

        expect(ours, theirs);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
