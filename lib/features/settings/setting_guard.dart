/// settings — see doc/settings.md and AGENTS.md
import '../../core/exceptions.dart';

abstract final class SettingGuard {
  /// Rail: default maximum allowed key length.
  static const int defaultMaxKeyLength = 128;

  /// Rail: default maximum allowed value length.
  static const int defaultMaxValueLength = 8192;

  /// Rail: upper bound for any configured key-length limit.
  static const int maxKeyLengthBound = 4096;

  /// Rail: upper bound for any configured value-length limit.
  static const int maxValueLengthBound = 1000000;

  /// Default substrings that mark a key as a secret (matched case-insensitively).
  static const Set<String> defaultSecretKeyNeedles = {
    'apikey',
    'api-key',
    'api_key',
    'secret',
    'token',
    'password',
    'passwd',
    'pwd',
    'credential',
  };

  /// Validates every knob on [options] against its rail.
  static void validateOptions(SettingsOptions options) {
    if (options.maxKeyLength < 1 || options.maxKeyLength > maxKeyLengthBound) {
      throw JameJamValidationException(
        'MaxKeyLength must be between 1 and $maxKeyLengthBound.',
      );
    }
    if (options.maxValueLength < 1 ||
        options.maxValueLength > maxValueLengthBound) {
      throw JameJamValidationException(
        'MaxValueLength must be between 1 and $maxValueLengthBound.',
      );
    }
  }

  /// Validates a setting key against [maxLength].
  static String validateKey(
    String? key, [
    int maxLength = defaultMaxKeyLength,
  ]) {
    if (key == null || key.trim().isEmpty) {
      throw const JameJamValidationException(
        'A setting key must not be empty.',
        service: 'settings',
      );
    }
    if (maxLength < 1) {
      throw JameJamValidationException('Invalid key-length limit: $maxLength.');
    }
    if (key.length > maxLength) {
      throw JameJamValidationException(
        'Setting key exceeds $maxLength characters.',
        service: 'settings',
      );
    }
    return key;
  }

  /// Validates a setting value (null becomes an empty string).
  static String validateValue(
    String? value, [
    int maxLength = defaultMaxValueLength,
  ]) {
    if (maxLength < 1) {
      throw JameJamValidationException(
        'Invalid value-length limit: $maxLength.',
      );
    }
    final safeValue = value ?? '';
    if (safeValue.length > maxLength) {
      throw JameJamValidationException(
        'Setting value exceeds $maxLength characters.',
        service: 'settings',
      );
    }
    return safeValue;
  }

  /// Refuses keys that look like secrets.
  ///
  /// The settings database is plaintext, so secrets belong in the platform keychain
  /// (or an environment variable) instead — refused **by name pattern**, so a mistake
  /// is caught before the value is ever written.
  static void ensureNotSecretKey(String key, [Set<String>? needles]) {
    final markers = needles ?? defaultSecretKeyNeedles;
    if (markers.isEmpty) return;

    final lowerKey = key.toLowerCase();
    for (final marker in markers) {
      if (lowerKey.contains(marker.toLowerCase())) {
        throw JameJamValidationException(
          "Refusing to store '$key': it looks like a secret. The settings database is "
          'plaintext — keep secrets in the secure store or the environment.',
          service: 'settings',
        );
      }
    }
  }
}

class SettingsOptions {
  const SettingsOptions({
    this.maxKeyLength = SettingGuard.defaultMaxKeyLength,
    this.maxValueLength = SettingGuard.defaultMaxValueLength,
    this.secretKeyNeedles = SettingGuard.defaultSecretKeyNeedles,
  });

  /// Maximum allowed key length.
  final int maxKeyLength;

  /// Maximum allowed value length.
  final int maxValueLength;

  /// Substrings that mark a key as a secret (matched case-insensitively).
  final Set<String> secretKeyNeedles;

  /// Throws when any value is outside its rail.
  void validate() => SettingGuard.validateOptions(this);
}
