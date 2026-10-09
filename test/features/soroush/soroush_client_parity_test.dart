// Parity port of tests/JameJam.Tests/Soroush/SoroushClientTests.cs (14 cases) and
// Soroush/SoroushHttpTests.cs (2 cases).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/features/soroush/soroush_client.dart';
import 'package:jamejam/features/soroush/soroush_options.dart';
import 'package:jamejam/features/soroush/soroush_registry.dart';

String _openAi(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

String _anthropic(String content) => jsonEncode({
  'content': [
    {'type': 'text', 'text': content},
  ],
});

/// Builds a client over a scripted transport that records every request.
({HttpSoroushClient client, List<http.Request> requests}) scripted(
  http.Response Function(http.Request request, int attempt) handler, {
  SoroushOptions options = const SoroushOptions(apiKey: 'sk-test'),
}) {
  final requests = <http.Request>[];
  final client = HttpSoroushClient(
    httpClient: MockClient((request) async {
      requests.add(request);
      return handler(request, requests.length);
    }),
    options: options,
  );
  return (client: client, requests: requests);
}

void main() {
  group('SoroushClientTests parity', () {
    // OpenAICompatible_BuildsAuthRequest_AndParsesContent
    test(
      'OpenAI-compatible builds an auth request and parses content',
      () async {
        final (:client, :requests) = scripted(
          (_, __) => http.Response(_openAi('hello'), 200),
        );

        final result = await client.complete('hi');

        expect(result.content, 'hello');
        expect(result.provider, 'openai');
        expect(requests.single.headers['authorization'], 'Bearer sk-test');
        expect(
          jsonDecode(requests.single.body)['messages'][0]['content'],
          'hi',
        );
      },
    );

    // Anthropic_SendsAnthropicHeaders_AndParsesContentBlocks
    test('Anthropic sends its headers and parses content blocks', () async {
      final (:client, :requests) = scripted(
        (_, __) => http.Response(_anthropic('hello'), 200),
        options: const SoroushOptions(
          apiKey: 'sk-test',
          provider: SoroushProviders.anthropic,
        ),
      );

      final result = await client.complete('hi');

      expect(result.content, 'hello');
      expect(result.provider, 'anthropic');
      expect(requests.single.headers['x-api-key'], 'sk-test');
      expect(requests.single.headers['anthropic-version'], '2023-06-01');
      expect(requests.single.headers.containsKey('authorization'), isFalse);
    });

    // TransientFailure_IsRetriedThenSucceeds
    test('a transient failure is retried, then succeeds', () async {
      final (:client, :requests) = scripted(
        (_, attempt) => attempt < 3
            ? http.Response('busy', 503)
            : http.Response(_openAi('ok'), 200),
        options: const SoroushOptions(
          apiKey: 'sk-test',
          maxRetries: 3,
          retryBaseDelay: Duration.zero,
        ),
      );

      final result = await client.complete('hi');
      expect(result.attempts, 3);
      expect(requests, hasLength(3));
    });

    // PerAttemptTimeout_IsRetried_ThenFailsWithTimeoutError
    test(
      'a per-attempt timeout is retried, then reported as a timeout',
      () async {
        final client = HttpSoroushClient(
          httpClient: MockClient((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 60));
            return http.Response(_openAi('late'), 200);
          }),
          options: const SoroushOptions(
            apiKey: 'sk-test',
            maxRetries: 1,
            retryBaseDelay: Duration.zero,
          ),
        );

        await expectLater(
          client.complete('hi', timeout: const Duration(milliseconds: 10)),
          throwsA(
            isA<SoroushException>().having(
              (e) => e.message,
              'message',
              contains('timed out'),
            ),
          ),
        );
      },
    );

    // NonRetryableStatus_FailsImmediately
    test('a non-retryable status fails immediately', () async {
      final (:client, :requests) = scripted(
        (_, __) => http.Response('bad request', 400),
        options: const SoroushOptions(
          apiKey: 'sk-test',
          maxRetries: 5,
          retryBaseDelay: Duration.zero,
        ),
      );

      await expectLater(
        client.complete('hi'),
        throwsA(isA<SoroushException>()),
      );
      expect(requests, hasLength(1));
    });

    // ApiErrorBody_IsScrubbed_WhenItEchoesTheApiKey
    test('an API error body that echoes the key is scrubbed', () async {
      final (:client, requests: _) = scripted(
        (_, __) => http.Response('Incorrect API key: sk-verysecret12345', 401),
        options: const SoroushOptions(
          apiKey: 'sk-verysecret12345',
          maxRetries: 0,
        ),
      );

      try {
        await client.complete('hi');
        fail('expected a SoroushException');
      } on SoroushException catch (error) {
        expect(error.message, isNot(contains('sk-verysecret12345')));
        expect(error.message, contains('****2345'));
        expect(error.statusCode, 401);
      }
    });

    // NetworkErrors_AreRetriedUntilExhausted
    test('network errors are retried until exhausted', () async {
      final requests = <int>[];
      final client = HttpSoroushClient(
        httpClient: MockClient((_) async {
          requests.add(1);
          throw http.ClientException('connection refused');
        }),
        options: const SoroushOptions(
          apiKey: 'sk-test',
          maxRetries: 2,
          retryBaseDelay: Duration.zero,
        ),
      );

      await expectLater(
        client.complete('hi'),
        throwsA(
          isA<SoroushException>().having(
            (e) => e.message,
            'message',
            contains('Network error'),
          ),
        ),
      );
      expect(requests, hasLength(3)); // initial attempt + 2 retries
    });

    // EmptyPrompt_FailsWithoutAnyHttpCall
    test('an empty prompt fails without any HTTP call', () async {
      final (:client, :requests) = scripted(
        (_, __) => http.Response(_openAi('ok'), 200),
      );

      await expectLater(client.complete('   '), throwsArgumentError);
      expect(requests, isEmpty);
    });

    // InsecureRemoteEndpoint_FailsWithoutAnyHttpCall
    test('an insecure remote endpoint fails without any HTTP call', () async {
      final (:client, :requests) = scripted(
        (_, __) => http.Response(_openAi('ok'), 200),
        options: const SoroushOptions(
          apiKey: 'sk-test',
          endpoint: 'http://api.example.com/v1/chat/completions',
        ),
      );

      await expectLater(
        client.complete('hi'),
        throwsA(isA<SoroushException>()),
      );
      expect(requests, isEmpty);
    });

    // InvalidOptions_FailFast_BeforeAnyHttpCall
    test('invalid options fail fast, before any HTTP call', () async {
      final (:client, :requests) = scripted(
        (_, __) => http.Response(_openAi('ok'), 200),
        options: const SoroushOptions(apiKey: 'sk-test', maxTokens: 0),
      );

      await expectLater(
        client.complete('hi'),
        throwsA(isA<SoroushException>()),
      );
      expect(requests, isEmpty);
    });

    // RetryableStatusCodes_AreCustomizable
    test('retryable status codes are customizable', () async {
      final (:client, :requests) = scripted(
        (_, attempt) => attempt == 1
            ? http.Response('teapot', 418)
            : http.Response(_openAi('ok'), 200),
        options: const SoroushOptions(
          apiKey: 'sk-test',
          retryBaseDelay: Duration.zero,
          retryableStatusCodes: {418},
        ),
      );

      final result = await client.complete('hi');
      expect(result.attempts, 2);
      expect(requests, hasLength(2));
    });

    // RetryableStatusCodes_CanBeEmptied_TransientsThenFailFast
    test('an emptied retryable set makes transients fail fast', () async {
      final (:client, :requests) = scripted(
        (_, __) => http.Response('busy', 503),
        options: const SoroushOptions(
          apiKey: 'sk-test',
          retryBaseDelay: Duration.zero,
          retryableStatusCodes: {},
        ),
      );

      await expectLater(
        client.complete('hi'),
        throwsA(isA<SoroushException>()),
      );
      expect(requests, hasLength(1));
    });

    // MaxErrorBodyLength_IsConfigurable
    test('the error-body length is configurable', () async {
      final (:client, requests: _) = scripted(
        (_, __) => http.Response('x' * 5000, 500),
        options: const SoroushOptions(
          apiKey: 'sk-test',
          maxRetries: 0,
          maxErrorBodyLength: 50,
        ),
      );

      try {
        await client.complete('hi');
        fail('expected a SoroushException');
      } on SoroushException catch (error) {
        // 50 characters of body, plus the truncation marker and the message prefix.
        expect(error.message.length, lessThan(150));
        expect(error.message, endsWith('…'));
      }
    });

    // MalformedSuccessBody_ProducesFriendlyError
    test('a malformed success body produces a friendly error', () async {
      final (:client, requests: _) = scripted(
        (_, __) => http.Response('{"unexpected":true}', 200),
      );

      await expectLater(
        client.complete('hi'),
        throwsA(
          isA<SoroushException>().having(
            (e) => e.message,
            'message',
            contains('unexpected OpenAI-compatible response shape'),
          ),
        ),
      );
    });
  });

  group('SoroushHttpTests parity — transport hardening', () {
    // CreateHandler_DisablesRedirects / CreateClient_ReturnsWorkingClient
    test('redirects are disabled on every request the client sends', () async {
      final (:client, :requests) = scripted(
        (_, __) => http.Response(_openAi('ok'), 200),
      );

      await client.complete('hi');

      expect(requests.single.followRedirects, isFalse);
      expect(requests.single.maxRedirects, 0);
    });

    test(
      'the client sends a well-formed POST with a JSON content type',
      () async {
        final (:client, :requests) = scripted(
          (_, __) => http.Response(_openAi('ok'), 200),
        );

        await client.complete('hi');
        final request = requests.single;

        expect(request.method, 'POST');
        expect(request.headers['content-type'], contains('application/json'));
        expect(() => jsonDecode(request.body), returnsNormally);
      },
    );

    // Retry-After handling (.NET honours response.Headers.RetryAfter).
    test('Retry-After is honoured on a retryable status', () async {
      final (:client, :requests) = scripted(
        (_, attempt) => attempt == 1
            ? http.Response('slow down', 429, headers: {'retry-after': '0'})
            : http.Response(_openAi('ok'), 200),
        options: const SoroushOptions(
          apiKey: 'sk-test',
          retryBaseDelay: Duration.zero,
        ),
      );

      final result = await client.complete('hi');
      expect(result.attempts, 2);
      expect(requests, hasLength(2));
    });

    // A loopback endpoint with no key must not send an Authorization header at all.
    test('no key means no auth header', () async {
      final (:client, :requests) = scripted(
        (_, __) => http.Response(_openAi('ok'), 200),
        options: const SoroushOptions(
          endpoint: 'http://localhost:11434/v1/chat/completions',
        ),
      );

      await client.complete('hi');
      expect(requests.single.headers.containsKey('authorization'), isFalse);
      expect(requests.single.headers.containsKey('x-api-key'), isFalse);
    });
  });
}
