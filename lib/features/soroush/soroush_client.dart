/// soroush — see doc/soroush.md and AGENTS.md
import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'soroush_guard.dart';
import 'soroush_options.dart';
import 'soroush_registry.dart';

class SoroushResult {
  const SoroushResult({
    required this.content,
    required this.provider,
    required this.model,
    required this.attempts,
    required this.duration,
  });

  /// The completion text (sanitized).
  final String content;

  /// Canonical provider name that served the request.
  final String provider;

  /// Model identifier used for the request.
  final String? model;

  /// HTTP attempts consumed (1 = no retry needed).
  final int attempts;

  /// Total wall-clock time including retries.
  final Duration duration;
}

class AiRequest {
  const AiRequest({
    required this.prompt,
    this.provider,
    this.model,
    this.endpoint,
  });

  /// The prompt to complete (sanitized before sending).
  final String prompt;

  /// Provider override; falls back to settings, then the default provider.
  final String? provider;

  /// Model override; falls back to settings, then the provider default.
  final String? model;

  /// Endpoint override; falls back to settings, then the provider default.
  final String? endpoint;
}

abstract interface class SoroushClient {
  /// Sends [prompt] through the safety layer to the configured provider.
  Future<SoroushResult> complete(String prompt, {Duration? timeout});
}

abstract interface class TextCompleter {
  Future<String> completeText(String prompt);
}

class HttpSoroushClient implements SoroushClient {
  HttpSoroushClient({
    required http.Client httpClient,
    required SoroushOptions options,
    Random? random,
  }) : _http = httpClient,
       _options = options,
       _random = random ?? Random();

  final http.Client _http;
  final SoroushOptions _options;
  final Random _random;

  @override
  Future<SoroushResult> complete(String prompt, {Duration? timeout}) async {
    SoroushGuard.validateOptions(_options);
    final safePrompt = SoroushGuard.sanitizePrompt(
      prompt,
      _options.maxPromptLength,
    );

    final provider = SoroushProviders.resolve(_options.provider);
    final endpoint = SoroushGuard.validateEndpoint(
      _options.endpoint ?? provider.defaultEndpoint,
    );

    final clock = Stopwatch()..start();
    final maxAttempts = _options.maxRetries + 1;
    final effectiveTimeout = timeout ?? _options.requestTimeout;

    for (var attempt = 1; ; attempt++) {
      try {
        // Redirects are disabled: an endpoint is validated up front, and silently following
        // a redirect could move a call — and its credentials — somewhere else.
        final request =
            provider.buildRequest(
                options: _options,
                endpoint: endpoint.toString(),
                prompt: safePrompt,
              )
              ..followRedirects = false
              ..maxRedirects = 0;

        final streamed = await _http
            .send(request)
            .timeout(
              effectiveTimeout,
              onTimeout: () => throw TimeoutException('per-attempt'),
            );
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final content = provider.parseResponse(response.body);
          return SoroushResult(
            content: content,
            provider: provider.name,
            model: _options.model ?? provider.defaultModel,
            attempts: attempt,
            duration: clock.elapsed,
          );
        }

        if (!_options.retryableStatusCodes.contains(response.statusCode) ||
            attempt >= maxAttempts) {
          throw _apiError(response);
        }

        await _delayBeforeRetry(_retryAfter(response), attempt);
      } on TimeoutException {
        if (attempt >= maxAttempts) {
          throw SoroushException(
            'AI request timed out after $attempt attempt(s) without success.',
          );
        }
        await _delayBeforeRetry(null, attempt);
      } on http.ClientException catch (error) {
        if (attempt >= maxAttempts) {
          throw SoroushException(
            'Network error talking to the AI provider: ${error.message}',
            cause: error,
          );
        }
        await _delayBeforeRetry(null, attempt);
      } on SoroushException {
        rethrow;
      }
    }
  }

  /// Exponential backoff with configurable jitter: spreading retries out prevents
  /// synchronized retry storms against an already-struggling provider.
  Future<void> _delayBeforeRetry(Duration? retryAfter, int attempt) async {
    final backoffMilliseconds =
        _options.retryBaseDelay.inMilliseconds * pow(2, attempt - 1);
    final jitter = _options.jitterScale;
    final jittered =
        backoffMilliseconds *
        (1 - jitter + (2 * jitter * _random.nextDouble()));
    final delay = retryAfter ?? Duration(milliseconds: jittered.round());

    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  /// `Retry-After` in seconds, when the provider sent one.
  Duration? _retryAfter(http.Response response) {
    final header = response.headers['retry-after'];
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }

  SoroushException _apiError(http.Response response) {
    var body = response.body;
    if (body.length > _options.maxErrorBodyLength) {
      body = '${body.substring(0, _options.maxErrorBodyLength)}…';
    }

    // Defense in depth: if the provider ever echoes our key back in an error body,
    // scrub it before the message can reach a screen or a log.
    body = SoroushGuard.redactIn(body, _options.apiKey);

    return SoroushException(
      'AI provider returned ${response.statusCode}. Body: $body',
      statusCode: response.statusCode,
    );
  }
}

class TextCompleterAdapter implements TextCompleter {
  const TextCompleterAdapter(this._client);

  final SoroushClient _client;

  @override
  Future<String> completeText(String prompt) async {
    final result = await _client.complete(prompt);
    return result.content;
  }
}
