/// raz — see doc/raz.md and AGENTS.md
abstract final class RazDefaults {
  // ── Crypto ──

  /// Salt length for PBKDF2 (256 bits).
  static const int saltSizeBytes = 32;

  /// Derived key length (AES-256).
  static const int keySizeBytes = 32;

  /// GCM nonce length (the standard 96 bits).
  static const int nonceSizeBytes = 12;

  /// GCM authentication tag length (128 bits).
  static const int tagSizeBytes = 16;

  /// Lowest acceptable PBKDF2 iteration count.
  static const int minIterations = 100000;

  /// Default PBKDF2-HMAC-SHA512 iteration count (OWASP guidance).
  static const int defaultIterations = 210000;

  /// Highest acceptable PBKDF2 iteration count.
  static const int maxIterations = 10000000;

  /// Plaintext check token encrypted on init and verified on unlock.
  static const String keyCheckPlaintext = 'raz-key-check-v1';

  /// Current backup format version.
  static const int backupVersion = 1;

  // ── Password generation ──

  /// Default generated password length.
  static const int defaultPasswordLength = 20;

  /// Shortest allowed generated password.
  static const int minPasswordLength = 8;

  /// Longest allowed generated password.
  static const int maxPasswordLength = 256;

  /// Default number of passwords produced by `raz generate`.
  static const int defaultGenerateCount = 1;

  /// Highest number of passwords a single `raz generate` may produce.
  static const int maxGenerateCount = 50;

  // ── TOTP (RFC 6238) ──

  /// Default TOTP code length.
  static const int defaultTotpDigits = 6;

  /// Shortest TOTP code.
  static const int minTotpDigits = 6;

  /// Longest TOTP code.
  static const int maxTotpDigits = 8;

  /// Default TOTP time step (seconds).
  static const int defaultTotpPeriodSeconds = 30;

  /// Shortest allowed time step.
  static const int minTotpPeriodSeconds = 15;

  /// Longest allowed time step.
  static const int maxTotpPeriodSeconds = 120;

  // ── Vault policy ──

  /// Undo snapshots kept (parity with the wallet; snapshots are ciphertext).
  static const int undoDepth = 20;

  /// Upper rail for the undo depth.
  static const int undoDepthBound = 100;

  /// A secret older than this many days shows up in audits as "rotate me".
  static const int oldAfterDays = 365;

  /// "Expiring soon" window for reminders and audits.
  static const int expiringSoonDays = 30;

  /// Upper rail for the expiring-soon window.
  static const int expiringSoonDaysBound = 3650;

  /// Maximum number of entries in one vault.
  static const int maxEntries = 5000;

  /// Strength scores at or below this are flagged as weak (scale 0–4).
  static const int weakScoreThreshold = 1;

  // ── Field bounds ──

  /// Longest entry title.
  static const int maxTitleLength = 100;

  /// Longest username / url / notes / tags field.
  static const int maxFieldLength = 400;

  /// Maximum tags per entry.
  static const int maxTagsPerEntry = 10;

  /// Longest passphrase the app accepts.
  static const int maxPassphraseLength = 1024;

  /// Longest AI question accepted from the user.
  static const int maxAiQuestionChars = 400;

  // ── Settings ──

  /// Where the reminder window, auto-lock minutes, and passphrase hint live.
  static const String passphraseSettingKey = 'raz.passphrase';

  /// Auto-lock after this many idle minutes (0 disables). Never stored in the vault DB.
  static const String autoLockMinutesSettingKey = 'raz.autoLockMinutes';

  /// Default auto-lock window.
  static const int defaultAutoLockMinutes = 5;

  /// Upper rail for the auto-lock window (0 = off).
  static const int maxAutoLockMinutes = 120;

  /// Vault database file name, under the app data directory.
  static const String databaseFileName = 'vault.db';
}
