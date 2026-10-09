/// raz — see doc/raz.md and AGENTS.md
import 'dart:math';

import 'models.dart';

abstract final class PasswordGenerator {
  /// Look-alike characters removed when `excludeAmbiguous` is set.
  static const String ambiguous = 'Il1|O0oQ';

  /// Printable ASCII symbol range without space or delete-prone characters.
  static const int _symbolStart = 0x21; // '!'
  static const int _symbolEnd = 0x7E; // '~'

  static const List<int> _lower = [
    0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, //
    0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
    0x79, 0x7A,
  ];

  static const List<int> _upper = [
    0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, //
    0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
    0x59, 0x5A,
  ];

  static const List<int> _digit = [
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, //
  ];

  /// Generates one password under the policy.
  static String generate(PasswordPolicy policy) {
    policy.validate();

    final random = Random.secure();
    List<int> strip(List<int> source) => source
        .where((c) => !ambiguous.contains(String.fromCharCode(c)))
        .toList();

    var lower = _lower;
    var upper = _upper;
    var digit = _digit;
    var symbol = _symbols();
    if (policy.excludeAmbiguous) {
      lower = strip(lower);
      upper = strip(upper);
      digit = strip(digit);
      symbol = strip(symbol);
    }

    final classes = <List<int>>[
      if (policy.lower) lower,
      if (policy.upper) upper,
      if (policy.digit) digit,
      if (policy.symbol) symbol,
    ];

    final union = <int>{for (final klass in classes) ...klass}.toList();
    final result = List<int>.filled(policy.length, 0);

    // Guarantee one character per class (as many classes as fit).
    final guaranteed = min(classes.length, policy.length);
    for (var i = 0; i < guaranteed; i++) {
      result[i] = classes[i][random.nextInt(classes[i].length)];
    }

    for (var i = guaranteed; i < policy.length; i++) {
      result[i] = union[random.nextInt(union.length)];
    }

    _shuffle(result, random);
    return String.fromCharCodes(result);
  }

  static List<int> _symbols() => [
    for (var c = _symbolStart; c <= _symbolEnd; c++)
      if (!_isAsciiLetterOrDigit(c)) c,
  ];

  static bool _isAsciiLetterOrDigit(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A);

  static void _shuffle(List<int> values, Random random) {
    for (var i = values.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final swap = values[i];
      values[i] = values[j];
      values[j] = swap;
    }
  }
}
