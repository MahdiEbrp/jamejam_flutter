// Parity port of tests/JameJam.Tests/Settings/SettingGuardTests.cs (11 cases) and
// Settings/SettingsOptionsTests.cs (7 cases).
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/exceptions.dart';
import 'package:jamejam/features/settings/setting_guard.dart';

void main() {
  group('SettingGuardTests parity', () {
    // EnsureNotSecretKey_RejectsSecretLookingKeys  [5 inline]
    test('rejects secret-looking keys', () {
      for (final key in [
        'openai.apiKey',
        'soroush.API_KEY',
        'xg.token',
        'user.password',
        'a.credential.b',
      ]) {
        expect(
          () => SettingGuard.ensureNotSecretKey(key),
          throwsA(isA<JameJamValidationException>()),
          reason: key,
        );
      }
    });

    // EnsureNotSecretKey_AllowsNormalKeys  [4 inline]
    test('allows normal keys', () {
      for (final key in [
        'greeter.defaultName',
        'anahita.location',
        'soroush.model',
        'divan.notebook',
      ]) {
        expect(
          () => SettingGuard.ensureNotSecretKey(key),
          returnsNormally,
          reason: key,
        );
      }
    });

    // ValidateKey_LongKey_Throws
    test('rejects an over-long key', () {
      expect(
        () => SettingGuard.validateKey('k' * 129),
        throwsA(isA<JameJamException>()),
      );
      expect(SettingGuard.validateKey('k' * 128), 'k' * 128);
    });

    // ValidateValue_LongValue_Throws
    test('rejects an over-long value', () {
      expect(
        () => SettingGuard.validateValue('v' * 8193),
        throwsA(isA<JameJamException>()),
      );
      expect(SettingGuard.validateValue('v' * 8192).length, 8192);
    });

    // Contract detail the .NET guard enforces on keys.
    test('rejects null, empty and whitespace keys', () {
      for (final key in <String?>[null, '', '   ']) {
        expect(
          () => SettingGuard.validateKey(key),
          throwsA(isA<JameJamException>()),
        );
      }
    });

    // Custom needle sets — the organization-specific key naming seam.
    test('honours a custom needle set, including an empty one', () {
      expect(
        () => SettingGuard.ensureNotSecretKey('org.private', {'private'}),
        throwsA(isA<JameJamException>()),
      );
      expect(
        () => SettingGuard.ensureNotSecretKey('openai.apiKey', const {}),
        returnsNormally,
      );
    });
  });

  group('SettingsOptionsTests parity', () {
    // Defaults_AreValid
    test('defaults are valid', () {
      expect(const SettingsOptions().validate, returnsNormally);
      const options = SettingsOptions();
      expect(options.maxKeyLength, SettingGuard.defaultMaxKeyLength);
      expect(options.maxValueLength, SettingGuard.defaultMaxValueLength);
      expect(options.secretKeyNeedles, SettingGuard.defaultSecretKeyNeedles);
    });

    // Validate_RejectsOutOfRangeKeyLimit  [3 inline: 0, -1, rail+1]
    test('rejects out-of-range key limits', () {
      for (final limit in [0, -1, SettingGuard.maxKeyLengthBound + 1]) {
        expect(
          () => SettingsOptions(maxKeyLength: limit).validate(),
          throwsA(isA<JameJamException>()),
          reason: 'maxKeyLength = $limit',
        );
      }
    });

    // Validate_RejectsOutOfRangeValueLimit  [2 inline]
    test('rejects out-of-range value limits', () {
      for (final limit in [0, SettingGuard.maxValueLengthBound + 1]) {
        expect(
          () => SettingsOptions(maxValueLength: limit).validate(),
          throwsA(isA<JameJamException>()),
          reason: 'maxValueLength = $limit',
        );
      }
    });

    // Validate_RejectsNullNeedles — Dart has no null in a non-nullable Set, so the
    // equivalent contract is that the needles collection is present and usable.
    test('the needle collection is present and usable', () {
      const options = SettingsOptions();
      expect(options.secretKeyNeedles, isNotEmpty);
      SettingsOptions(
        secretKeyNeedles: const {'private'},
      ).validate(); // an empty set is legal, a missing one is not expressible
    });
  });
}
