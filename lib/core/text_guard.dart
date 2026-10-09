/// Shared text safety — the Dart port of `JameJam.Text.TextGuard`.
///
/// Strips control characters (keeping `\n` and `\t`), trims, and enforces length caps.
/// Used by every layer that accepts untrusted text, so the rules are identical everywhere:
/// a title typed in Haft Khan, a note body in Divan, and an AI prompt in Soroush all pass
/// through this one funnel.
library;

/// The shared, portable sanitizer.
abstract final class TextGuard {
  /// Control characters that are stripped: every C0 control character except `\n` and `\t`,
  /// plus DEL (`\u007f`).
  static bool isStrippedControl(int codeUnit) {
    if (codeUnit == 0x0A || codeUnit == 0x09) return false;
    if (codeUnit <= 0x1F) return true;
    return codeUnit == 0x7F;
  }

  /// Returns true when [value] contains at least one character that would be stripped.
  static bool hasControlChars(String value) {
    for (var i = 0; i < value.length; i++) {
      if (isStrippedControl(value.codeUnitAt(i))) return true;
    }
    return false;
  }

  /// Sanitizes a required, non-empty single field.
  ///
  /// Throws [ArgumentError] when the value is empty, whitespace-only, or holds no readable
  /// characters; throws [RangeError] when it exceeds [maxLength] after sanitization.
  static String sanitizeRequired(
    String? value,
    int maxLength,
    String paramName,
  ) {
    if (maxLength < 1) {
      throw RangeError.range(maxLength, 1, null, 'maxLength');
    }

    final result = _sanitize(value, maxLength);
    if (result.text.isEmpty) {
      throw ArgumentError.value(value, paramName, 'Value must not be empty');
    }
    if (result.overTheLimit) {
      throw RangeError.value(
        maxLength,
        paramName,
        'Value exceeds the maximum length of $maxLength characters',
      );
    }
    return result.text;
  }

  /// Sanitizes an optional field: null or whitespace becomes an empty string.
  ///
  /// Throws [RangeError] when the sanitized value exceeds [maxLength].
  static String sanitizeOptional(
    String? value,
    int maxLength,
    String paramName,
  ) {
    if (maxLength < 1) {
      throw RangeError.range(maxLength, 1, null, 'maxLength');
    }
    if (value == null || value.trim().isEmpty) return '';

    final result = _sanitize(value, maxLength);
    if (result.overTheLimit) {
      throw RangeError.value(
        maxLength,
        paramName,
        'Value exceeds the maximum length of $maxLength characters',
      );
    }
    return result.text;
  }

  /// Clips without throwing — the behaviour AI prompt builders rely on.
  static String clip(String? value, int maxLength) {
    if (value == null || value.isEmpty) return '';
    final sanitized = _sanitize(value, maxLength).text;
    return sanitized.length <= maxLength
        ? sanitized
        : sanitized.substring(0, maxLength);
  }

  static _SanitizeResult _sanitize(String? value, int maxLength) {
    if (value == null || value.isEmpty) {
      return const _SanitizeResult('', overTheLimit: false);
    }

    final trimmed = value.trim();

    // Fast path: nothing to filter — return the trimmed slice untouched.
    if (!hasControlChars(trimmed)) {
      final over = trimmed.length > maxLength;
      return _SanitizeResult(
        over ? trimmed.substring(0, maxLength) : trimmed,
        overTheLimit: over,
      );
    }

    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      final unit = trimmed.codeUnitAt(i);
      if (!isStrippedControl(unit)) buffer.writeCharCode(unit);
    }

    var result = buffer.toString().trim();
    var over = false;
    if (result.length > maxLength) {
      over = true;
      result = result.substring(0, maxLength);
    }
    return _SanitizeResult(result, overTheLimit: over);
  }
}

class _SanitizeResult {
  const _SanitizeResult(this.text, {required this.overTheLimit});

  final String text;
  final bool overTheLimit;
}
