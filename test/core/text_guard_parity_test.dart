// Parity port of tests/JameJam.Tests/Text/TextGuardTests.cs (7 facts + 2 theories, 14 cases).
//
// Every case in the .NET file has a counterpart below; the comment on each test names the
// original so a reviewer can diff the two suites side by side.
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/text_guard.dart';

void main() {
  group('TextGuardTests parity', () {
    // SanitizeRequired_StripsControlChars_Trims_AndKeepsFormatting
    test('required strips control chars, trims, and keeps formatting', () {
      expect(
        TextGuard.sanitizeRequired(
          '  \u0001Hello\u0002\nWorld\t!  ',
          100,
          'value',
        ),
        'Hello\nWorld\t!',
      );
      expect(
        TextGuard.sanitizeRequired('line1\nline2', 100, 'value'),
        'line1\nline2',
      );
      expect(TextGuard.sanitizeRequired('a\tb', 100, 'value'), 'a\tb');
    });

    // SanitizeRequired_EmptyOrUnreadable_Throws  [4 inline: null, "", "   ", "\u0000\u0001"]
    test(
      'required throws on null, empty, whitespace, and unreadable input',
      () {
        for (final input in <String?>[null, '', '   ', '\u0000\u0001']) {
          expect(
            () => TextGuard.sanitizeRequired(input, 100, 'value'),
            throwsArgumentError,
            reason:
                'input ${input == null ? 'null' : '"$input"'} must be refused',
          );
        }
      },
    );

    // SanitizeRequired_TooLong_Throws
    test('required rejects an over-long value instead of truncating', () {
      expect(
        () => TextGuard.sanitizeRequired('x' * 101, 100, 'value'),
        throwsRangeError,
      );
      expect(TextGuard.sanitizeRequired('x' * 100, 100, 'value'), 'x' * 100);
    });

    // SanitizeRequired_CleanValue_ReturnsUnchanged_NoAllocations
    test('required returns a clean value unchanged', () {
      const clean = 'a perfectly clean value';
      expect(TextGuard.sanitizeRequired(clean, 100, 'value'), same(clean));
    });

    // SanitizeOptional_EmptyBecomesEmptyString  [3 inline: null, "", "   "]
    test('optional maps null, empty, and whitespace to an empty string', () {
      for (final input in <String?>[null, '', '   ']) {
        expect(TextGuard.sanitizeOptional(input, 100, 'value'), '');
      }
    });

    // SanitizeOptional_StripsControlChars
    test('optional strips control characters and trims', () {
      expect(
        TextGuard.sanitizeOptional(' \u0007abc\u0008 ', 100, 'value'),
        'abc',
      );
      expect(TextGuard.sanitizeOptional('a\nb', 100, 'value'), 'a\nb');
    });

    // SanitizeOptional_TooLong_Throws
    test('optional rejects an over-long value', () {
      expect(
        () => TextGuard.sanitizeOptional('y' * 101, 100, 'value'),
        throwsRangeError,
      );
    });

    // SanitizeRequired_ControlCharsAndTooLong_Throws
    // Exact input from the .NET case: "ab\u0002cdef" with a cap of 5 → the sanitized
    // "abcdef" is 6 characters, so the slow path must also enforce the limit.
    test('required throws when control chars hide an over-long value', () {
      expect(
        () => TextGuard.sanitizeRequired('ab\u0002cdef', 5, 'input'),
        throwsRangeError,
      );
    });

    // SanitizeOptional_ControlCharsAndTooLong_Throws
    test('optional throws when control chars hide an over-long value', () {
      expect(
        () => TextGuard.sanitizeOptional('ab\u0002cdef', 5, 'input'),
        throwsRangeError,
      );
    });

    // Not in the .NET suite: the clip mode the Flutter port added for prompt building.
    test('clip truncates silently — the mode prompt builders rely on', () {
      expect(TextGuard.clip('x' * 10, 4), 'xxxx');
      expect(TextGuard.clip('  spaced  ', 100), 'spaced');
      expect(TextGuard.clip(null, 4), '');
      expect(TextGuard.clip('a\u0000b', 100), 'ab');
    });

    // Delete character handling, shared by every mode.
    test('the DEL character is stripped in every mode', () {
      expect(TextGuard.sanitizeRequired('a\u007fb', 10, 'v'), 'ab');
      expect(TextGuard.sanitizeOptional('a\u007fb', 10, 'v'), 'ab');
      expect(TextGuard.clip('a\u007fb', 10), 'ab');
    });
  });
}
