// Parity port of tests/JameJam.Tests/Soroush/SoroushGuardTests.cs (17 facts + 9 theories,
// 44 cases). Every case name below traces to the original.
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/soroush/soroush_guard.dart';
import 'package:jamejam/features/soroush/soroush_options.dart';

void main() {
  group('SoroushGuardTests parity — prompt sanitizing', () {
    // SanitizePrompt_WithEmptyInput_Throws  [3 inline: null, "", "   "]
    test('empty input throws', () {
      for (final input in <String?>[null, '', '   ']) {
        expect(() => SoroushGuard.sanitizePrompt(input), throwsArgumentError);
      }
    });

    // SanitizePrompt_WithOnlyControlCharacters_Throws
    test('input made only of control characters throws', () {
      expect(
        () => SoroushGuard.sanitizePrompt('\u0000\u0001\u0002'),
        throwsArgumentError,
      );
    });

    // SanitizePrompt_TooLong_Throws
    test('an over-long prompt throws', () {
      expect(
        () => SoroushGuard.sanitizePrompt('p' * 8001),
        throwsA(isA<SoroushException>()),
      );
      expect(SoroushGuard.sanitizePrompt('p' * 8000).length, 8000);
    });

    // SanitizePrompt_TrimsAndKeepsFormatting  [2 inline]
    test('trims but keeps newlines and tabs', () {
      expect(SoroushGuard.sanitizePrompt('  hello  '), 'hello');
      expect(SoroushGuard.sanitizePrompt('a\n\tb'), 'a\n\tb');
    });

    // SanitizePrompt_StripsControlCharactersButKeepsNewlines
    test('strips control characters but keeps newlines', () {
      expect(SoroushGuard.sanitizePrompt('a\u0000\u0007b\nc'), 'ab\nc');
    });

    // SanitizePrompt_StripsDelCharacter
    test('strips the DEL character', () {
      expect(SoroushGuard.sanitizePrompt('a\u007fb'), 'ab');
    });

    // SanitizePrompt_LongCleanString_IsO1AllocationAndUnchanged
    // (The .NET case asserts allocation behaviour; Dart verifies the value contract.)
    test('a long clean prompt is returned unchanged', () {
      const clean = 'a long clean prompt with no control characters at all';
      expect(SoroushGuard.sanitizePrompt(clean, 1000), same(clean));
    });

    // The configured cap is honoured, not just the default.
    test('a custom prompt cap is enforced', () {
      expect(SoroushGuard.sanitizePrompt('x' * 10, 10), 'x' * 10);
      expect(
        () => SoroushGuard.sanitizePrompt('x' * 11, 10),
        throwsA(isA<SoroushException>()),
      );
    });
  });

  group('SoroushGuardTests parity — endpoint policy', () {
    // ValidateEndpoint_AcceptsHttpsAndLoopbackHttp  [3 inline]
    test('accepts HTTPS and loopback HTTP', () {
      expect(
        SoroushGuard.validateEndpoint('https://api.example.com/v1').host,
        'api.example.com',
      );
      expect(
        SoroushGuard.validateEndpoint('http://localhost:11434/v1').host,
        'localhost',
      );
      expect(
        SoroushGuard.validateEndpoint('http://127.0.0.1:8080/v1').host,
        '127.0.0.1',
      );
    });

    // ValidateEndpoint_RejectsInsecureOrInvalid  [4 inline]
    test('rejects insecure or invalid endpoints', () {
      for (final endpoint in <String?>[
        'http://api.example.com/v1',
        'ftp://api.example.com/v1',
        'not a url',
        null,
      ]) {
        expect(
          () => SoroushGuard.validateEndpoint(endpoint),
          throwsA(isA<SoroushException>()),
          reason: 'endpoint = $endpoint',
        );
      }
    });

    // IPv6 loopback, which the .NET Uri.IsLoopback also accepts.
    test('accepts IPv6 loopback', () {
      expect(SoroushGuard.validateEndpoint('http://[::1]:8080/v1').host, '::1');
    });
  });

  group('SoroushGuardTests parity — options validation', () {
    // ValidateOptions_AcceptsTheDefaults
    test('accepts the defaults', () {
      expect(
        () => SoroushGuard.validateOptions(const SoroushOptions()),
        returnsNormally,
      );
    });

    // ValidateOptions_RejectsOutOfRangeMaxTokens  [3 inline]
    test('rejects out-of-range MaxTokens', () {
      for (final tokens in [0, -1, SoroushLimits.maxTokensBound + 1]) {
        expect(
          () => SoroushGuard.validateOptions(SoroushOptions(maxTokens: tokens)),
          throwsA(isA<SoroushException>()),
          reason: 'maxTokens = $tokens',
        );
      }
    });

    // ValidateOptions_RejectsZeroTimeout
    test('rejects a zero (and negative, and too-large) timeout', () {
      for (final timeout in [
        Duration.zero,
        const Duration(seconds: -1),
        const Duration(minutes: 11),
      ]) {
        expect(
          () => SoroushGuard.validateOptions(
            SoroushOptions(requestTimeout: timeout),
          ),
          throwsA(isA<SoroushException>()),
        );
      }
    });

    // ValidateOptions_RejectsTooManyRetries
    test('rejects too many retries', () {
      for (final retries in [-1, SoroushLimits.maxRetriesBound + 1]) {
        expect(
          () =>
              SoroushGuard.validateOptions(SoroushOptions(maxRetries: retries)),
          throwsA(isA<SoroushException>()),
        );
      }
      expect(
        () => SoroushGuard.validateOptions(
          SoroushOptions(maxRetries: SoroushLimits.maxRetriesBound),
        ),
        returnsNormally,
      );
    });

    // ValidateOptions_RejectsInsecureEndpoint
    test('rejects an insecure endpoint', () {
      expect(
        () => SoroushGuard.validateOptions(
          const SoroushOptions(endpoint: 'http://api.example.com/v1'),
        ),
        throwsA(isA<SoroushException>()),
      );
    });

    // ValidateOptions_RejectsTooSmallErrorBodyLength
    test('rejects a too-small error-body length', () {
      expect(
        () => SoroushGuard.validateOptions(
          SoroushOptions(
            maxErrorBodyLength: SoroushLimits.minErrorBodyLength - 1,
          ),
        ),
        throwsA(isA<SoroushException>()),
      );
    });

    // ValidateOptions_RejectsHugeErrorBodyLength
    test('rejects a huge error-body length', () {
      expect(
        () => SoroushGuard.validateOptions(
          SoroushOptions(
            maxErrorBodyLength: SoroushLimits.maxErrorBodyLengthBound + 1,
          ),
        ),
        throwsA(isA<SoroushException>()),
      );
    });

    // ValidateOptions_RejectsJitterOutsideUnitRange  [2 inline: -0.1, 1.1]
    test('rejects jitter outside the unit range', () {
      for (final jitter in [-0.1, 1.1]) {
        expect(
          () =>
              SoroushGuard.validateOptions(SoroushOptions(jitterScale: jitter)),
          throwsA(isA<SoroushException>()),
          reason: 'jitterScale = $jitter',
        );
      }
      for (final jitter in [0.0, 1.0]) {
        expect(
          () =>
              SoroushGuard.validateOptions(SoroushOptions(jitterScale: jitter)),
          returnsNormally,
        );
      }
    });

    // ValidateOptions_RejectsNullRetryableStatusCodes — non-nullable in Dart, so the
    // equivalent contract is that an empty set is allowed and validated without error.
    test('an emptied retryable-status set is accepted', () {
      expect(
        () => SoroushGuard.validateOptions(
          const SoroushOptions(retryableStatusCodes: {}),
        ),
        returnsNormally,
      );
    });

    test('rejects a negative backoff base delay', () {
      expect(
        () => SoroushGuard.validateOptions(
          const SoroushOptions(retryBaseDelay: Duration(milliseconds: -1)),
        ),
        throwsA(isA<SoroushException>()),
      );
    });

    test('rejects a prompt cap below one', () {
      expect(
        () => SoroushGuard.validateOptions(
          const SoroushOptions(maxPromptLength: 0),
        ),
        throwsA(isA<SoroushException>()),
      );
    });
  });

  group('SoroushGuardTests parity — redaction', () {
    // Redact_MasksSecrets  [5 inline]
    test('masks secrets', () {
      expect(SoroushGuard.redact('sk-1234567890'), '****7890');
      expect(SoroushGuard.redact('abcd'), '****');
      expect(SoroushGuard.redact('abc'), '****');
      expect(SoroushGuard.redact(''), '(none)');
      expect(SoroushGuard.redact(null), '(none)');
    });

    // RedactIn_ScrubsSecretOccurrencesFromText — the original's exact expectation.
    test('scrubs secret occurrences from text', () {
      final scrubbed = SoroushGuard.redactIn(
        'oops: sk-livetest-key is invalid',
        'sk-livetest-key',
      );
      expect(scrubbed, 'oops: ****-key is invalid');
    });

    // RedactIn_KeepsTextUntouched_WithoutSecretMatch
    test('keeps text untouched when the secret is absent', () {
      const text = 'nothing to hide here';
      expect(SoroushGuard.redactIn(text, 'sk-abcdefgh'), same(text));
      expect(SoroushGuard.redactIn(text, null), same(text));
      expect(SoroushGuard.redactIn(text, ''), same(text));
    });

    // ValidateResponse_WithEmptyContent_Throws  [3 inline: null, "", "   "]
    test('an empty response throws', () {
      for (final content in <String?>[null, '', '   ']) {
        expect(
          () => SoroushGuard.validateResponse(content),
          throwsA(isA<SoroushException>()),
        );
      }
    });

    // ValidateResponse_Trims
    test('a response is trimmed', () {
      expect(SoroushGuard.validateResponse('  hi  '), 'hi');
    });

    // Redact_LongSecret_KeepsAtMostTheRailSuffix
    test('keeps at most the configured suffix', () {
      final secret = 'k' * 100;
      final masked = SoroushGuard.redact(secret);
      expect(masked, '****${'k' * SoroushLimits.redactDefaultSuffixLength}');
    });

    // Redact_SuffixLength_OutsideRails_Throws  [2 inline: -1, bound+1]
    test('a suffix length outside the rails throws', () {
      for (final suffix in [-1, SoroushLimits.redactSuffixLengthBound + 1]) {
        expect(() => SoroushGuard.redact('secret', suffix), throwsRangeError);
      }
    });

    // RedactIn_SuffixLength_FlowsThrough
    test('the suffix length flows through to the scrubber', () {
      expect(
        SoroushGuard.redactIn('x sk-1234567890 y', 'sk-1234567890', 2),
        contains('****90'),
      );
      expect(
        SoroushGuard.redactIn('x sk-1234567890 y', 'sk-1234567890', 0),
        contains('****'),
      );
    });
  });
}
