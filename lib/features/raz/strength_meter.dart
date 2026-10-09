/// raz — see doc/raz.md and AGENTS.md
import 'dart:math';

import 'models.dart';

abstract final class StrengthMeter {
  static const int _lowerPoolSize = 26;
  static const int _upperPoolSize = 26;
  static const int _digitPoolSize = 10;
  static const int _symbolPoolSize = 33; // printable ASCII symbols

  static const int _veryWeakBits = 28;
  static const int _weakBits = 36;
  static const int _fairBits = 60;
  static const int _strongBits = 100;

  static const int _sequencePenaltyBits = 12;
  static const int _repeatPenaltyBits = 12;
  static const int _minPatternRun = 3;

  /// Scores a secret. Empty or whitespace scores 0 with an issue.
  static PasswordStrength score(String secret) {
    if (secret.isEmpty) {
      return const PasswordStrength(
        score: 0,
        entropyBits: 0,
        issues: ['empty secret'],
      );
    }

    final issues = <String>[];
    var poolSize = 0;
    if (secret.contains(RegExp('[a-z]'))) poolSize += _lowerPoolSize;
    if (secret.contains(RegExp('[A-Z]'))) poolSize += _upperPoolSize;
    if (secret.contains(RegExp('[0-9]'))) poolSize += _digitPoolSize;
    if (secret.contains(RegExp('[^A-Za-z0-9]'))) poolSize += _symbolPoolSize;

    if (poolSize == 0) {
      return const PasswordStrength(
        score: 0,
        entropyBits: 0,
        issues: ['no scoreable characters'],
      );
    }

    var entropy = (secret.length * (log(poolSize) / ln2)).floor();

    if (_hasSequence(secret)) {
      issues.add('sequential characters');
      entropy -= _sequencePenaltyBits;
    }

    if (_hasRepeat(secret)) {
      issues.add('repeated characters');
      entropy -= _repeatPenaltyBits;
    }

    entropy = max(0, entropy);
    final score = switch (entropy) {
      < _veryWeakBits => 0,
      < _weakBits => 1,
      < _fairBits => 2,
      < _strongBits => 3,
      _ => 4,
    };

    return PasswordStrength(score: score, entropyBits: entropy, issues: issues);
  }

  static bool _hasSequence(String secret) {
    var run = 1;
    for (var i = 1; i < secret.length; i++) {
      final previous = secret.codeUnitAt(i - 1);
      final current = secret.codeUnitAt(i);
      run = (current == previous + 1 || current == previous - 1) ? run + 1 : 1;
      if (run >= _minPatternRun) return true;
    }

    return false;
  }

  static bool _hasRepeat(String secret) {
    var run = 1;
    for (var i = 1; i < secret.length; i++) {
      run = secret.codeUnitAt(i) == secret.codeUnitAt(i - 1) ? run + 1 : 1;
      if (run >= _minPatternRun) return true;
    }

    return false;
  }
}
