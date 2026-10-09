/// raz — see doc/raz.md and AGENTS.md
import 'raz_defaults.dart';

class RazOptions {
  const RazOptions({
    this.iterations = RazDefaults.defaultIterations,
    this.undoDepth = RazDefaults.undoDepth,
    this.passwordLength = RazDefaults.defaultPasswordLength,
    this.expiringSoonDays = RazDefaults.expiringSoonDays,
    this.oldAfterDays = RazDefaults.oldAfterDays,
    this.weakScoreThreshold = RazDefaults.weakScoreThreshold,
    this.autoLockMinutes = RazDefaults.defaultAutoLockMinutes,
  });

  /// PBKDF2-HMAC-SHA512 iteration count.
  final int iterations;

  /// How many undo snapshots are kept.
  final int undoDepth;

  /// Default length for generated passwords.
  final int passwordLength;

  /// "Expiring soon" window for reminders and audits.
  final int expiringSoonDays;

  /// Secret age (days) after which audits suggest rotation.
  final int oldAfterDays;

  /// Strength scores at or below this count as weak.
  final int weakScoreThreshold;

  /// Idle minutes before the vault locks itself (0 = never).
  final int autoLockMinutes;

  /// Reads the overridable rails from a map (the app passes `Platform.environment`;
  /// tests pass their own, so no test can mutate the process).
  factory RazOptions.fromEnvironment(Map<String, String> environment) {
    final defaults = const RazOptions();
    int read(String key, int fallback) =>
        int.tryParse(environment[key] ?? '') ?? fallback;

    return RazOptions(
      iterations: read('JAMEJAM_RAZ_ITERATIONS', defaults.iterations),
      undoDepth: read('JAMEJAM_RAZ_UNDO_DEPTH', defaults.undoDepth),
      passwordLength: read(
        'JAMEJAM_RAZ_PASSWORD_LENGTH',
        defaults.passwordLength,
      ),
      expiringSoonDays: read(
        'JAMEJAM_RAZ_EXPIRING_SOON_DAYS',
        defaults.expiringSoonDays,
      ),
      oldAfterDays: read('JAMEJAM_RAZ_OLD_AFTER_DAYS', defaults.oldAfterDays),
      weakScoreThreshold: read(
        'JAMEJAM_RAZ_WEAK_SCORE',
        defaults.weakScoreThreshold,
      ),
      autoLockMinutes: read(
        'JAMEJAM_RAZ_AUTO_LOCK_MINUTES',
        defaults.autoLockMinutes,
      ),
    );
  }

  RazOptions copyWith({
    int? iterations,
    int? undoDepth,
    int? passwordLength,
    int? expiringSoonDays,
    int? oldAfterDays,
    int? weakScoreThreshold,
    int? autoLockMinutes,
  }) => RazOptions(
    iterations: iterations ?? this.iterations,
    undoDepth: undoDepth ?? this.undoDepth,
    passwordLength: passwordLength ?? this.passwordLength,
    expiringSoonDays: expiringSoonDays ?? this.expiringSoonDays,
    oldAfterDays: oldAfterDays ?? this.oldAfterDays,
    weakScoreThreshold: weakScoreThreshold ?? this.weakScoreThreshold,
    autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
  );

  /// Validates every bound against its rail.
  ///
  /// Throws [RangeError] when a value is outside its rail — the Dart equivalent of the
  /// .NET `ArgumentOutOfRangeException`.
  void validate() {
    if (iterations < RazDefaults.minIterations ||
        iterations > RazDefaults.maxIterations) {
      throw RangeError.range(
        iterations,
        RazDefaults.minIterations,
        RazDefaults.maxIterations,
        'iterations',
        'Iterations must be between ${RazDefaults.minIterations} and '
            '${RazDefaults.maxIterations}.',
      );
    }

    if (undoDepth < 0 || undoDepth > RazDefaults.undoDepthBound) {
      throw RangeError.range(
        undoDepth,
        0,
        RazDefaults.undoDepthBound,
        'undoDepth',
        'UndoDepth must be between 0 and ${RazDefaults.undoDepthBound}.',
      );
    }

    if (passwordLength < RazDefaults.minPasswordLength ||
        passwordLength > RazDefaults.maxPasswordLength) {
      throw RangeError.range(
        passwordLength,
        RazDefaults.minPasswordLength,
        RazDefaults.maxPasswordLength,
        'passwordLength',
        'PasswordLength must be between ${RazDefaults.minPasswordLength} and '
            '${RazDefaults.maxPasswordLength}.',
      );
    }

    if (expiringSoonDays < 1 ||
        expiringSoonDays > RazDefaults.expiringSoonDaysBound) {
      throw RangeError.range(
        expiringSoonDays,
        1,
        RazDefaults.expiringSoonDaysBound,
        'expiringSoonDays',
        'ExpiringSoonDays must be between 1 and '
            '${RazDefaults.expiringSoonDaysBound}.',
      );
    }

    if (oldAfterDays < 1 || oldAfterDays > RazDefaults.expiringSoonDaysBound) {
      throw RangeError.range(
        oldAfterDays,
        1,
        RazDefaults.expiringSoonDaysBound,
        'oldAfterDays',
        'OldAfterDays must be between 1 and '
            '${RazDefaults.expiringSoonDaysBound}.',
      );
    }

    if (weakScoreThreshold < 0 || weakScoreThreshold > 3) {
      throw RangeError.range(
        weakScoreThreshold,
        0,
        3,
        'weakScoreThreshold',
        'WeakScoreThreshold must be between 0 and 3.',
      );
    }

    if (autoLockMinutes < 0 ||
        autoLockMinutes > RazDefaults.maxAutoLockMinutes) {
      throw RangeError.range(
        autoLockMinutes,
        0,
        RazDefaults.maxAutoLockMinutes,
        'autoLockMinutes',
        'AutoLockMinutes must be between 0 and '
            '${RazDefaults.maxAutoLockMinutes}.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is RazOptions &&
      other.iterations == iterations &&
      other.undoDepth == undoDepth &&
      other.passwordLength == passwordLength &&
      other.expiringSoonDays == expiringSoonDays &&
      other.oldAfterDays == oldAfterDays &&
      other.weakScoreThreshold == weakScoreThreshold &&
      other.autoLockMinutes == autoLockMinutes;

  @override
  int get hashCode => Object.hash(
    iterations,
    undoDepth,
    passwordLength,
    expiringSoonDays,
    oldAfterDays,
    weakScoreThreshold,
    autoLockMinutes,
  );

  @override
  String toString() =>
      'RazOptions(iterations: $iterations, undoDepth: $undoDepth, '
      'passwordLength: $passwordLength)';
}
