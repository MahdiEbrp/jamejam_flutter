import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where a secret lives: **never** in the plaintext settings database.
///
/// The .NET toolbox keeps secrets in environment variables only. A GUI app cannot ask the
/// user to set an env var before tapping "Send", so the Flutter port keeps the same promise
/// with the platform keychain instead — and still prefers an environment variable when one is
/// set, so scripted and desktop runs behave exactly like the CLI.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Well-known secret slots and their environment-variable equivalents.
abstract final class SecretKeys {
  /// AI provider API key — `JAMEJAM_AI_API_KEY` in the CLI.
  static const String aiApiKey = 'jamejam.ai.apiKey';

  /// Bearer token for the sync transport (Step 9) — `JAMEJAM_SYNC_TOKEN`.
  static const String syncToken = 'jamejam.sync.token';

  /// Vault passphrase cache slot (Step 7) — the CLI prompts or reads `JAMEJAM_RAZ_PASSPHRASE`.
  static const String razPassphrase = 'jamejam.raz.passphrase';

  /// Environment variable that may satisfy [aiApiKey].
  static const String aiApiKeyEnv = 'JAMEJAM_AI_API_KEY';

  /// Environment variable that may satisfy [syncToken].
  static const String syncTokenEnv = 'JAMEJAM_SYNC_TOKEN';

  /// Environment variable that may satisfy [razPassphrase].
  static const String razPassphraseEnv = 'JAMEJAM_RAZ_PASSPHRASE';

  static String? environmentVariableFor(String key) => switch (key) {
    aiApiKey => aiApiKeyEnv,
    syncToken => syncTokenEnv,
    razPassphrase => razPassphraseEnv,
    _ => null,
  };
}

/// Non-persistent store for tests, previews, and platforms without a keychain backend.
class MemorySecretStore implements SecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Keychain-backed store: Android Keystore, iOS/macOS Keychain, Windows Credential
/// Manager, and libsecret on Linux.
class KeychainSecretStore implements SecretStore {
  KeychainSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Reads an environment variable first, then falls back to the wrapped store.
///
/// This mirrors the CLI's "token from the environment only" rule while keeping the GUI
/// usable on devices that have no shell.
class EnvironmentFirstSecretStore implements SecretStore {
  EnvironmentFirstSecretStore(
    this._fallback, {
    Map<String, String>? environment,
  }) : _environment = environment ?? Platform.environment;

  final SecretStore _fallback;
  final Map<String, String> _environment;

  @override
  Future<String?> read(String key) async {
    final envName = SecretKeys.environmentVariableFor(key);
    if (envName != null) {
      final fromEnvironment = _environment[envName];
      if (fromEnvironment != null && fromEnvironment.trim().isNotEmpty) {
        return fromEnvironment.trim();
      }
    }
    return _fallback.read(key);
  }

  @override
  Future<void> write(String key, String value) => _fallback.write(key, value);

  @override
  Future<void> delete(String key) => _fallback.delete(key);
}

/// Reads/writes secrets, catching keychain failures and degrading to a clear message
/// instead of crashing the screen that asked for a key.
class SafeSecretStore implements SecretStore {
  SafeSecretStore(this._inner);

  final SecretStore _inner;

  @override
  Future<String?> read(String key) async {
    try {
      return await _inner.read(key);
    } catch (error) {
      debugPrint('Secret store read failed for "$key": $error');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _inner.write(key, value);
    } catch (error) {
      throw SecretStoreUnavailable(error);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _inner.delete(key);
    } catch (error) {
      throw SecretStoreUnavailable(error);
    }
  }
}

/// Raised when the platform keychain refused a write — surfaced to the user verbatim,
/// because silently dropping a key would be a security-relevant lie.
class SecretStoreUnavailable implements Exception {
  const SecretStoreUnavailable(this.cause);

  final Object cause;

  @override
  String toString() =>
      'The platform secure store is unavailable, so the secret was not saved '
      '(set the matching JAMEJAM_* environment variable instead). Cause: $cause';
}
