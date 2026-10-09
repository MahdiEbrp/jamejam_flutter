/// sync — see doc/sync.md and AGENTS.md
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../soroush/soroush_guard.dart';
import 'sync_models.dart';
import 'sync_options.dart';

abstract interface class SyncClient {
  /// Downloads the remote document. Returns null when the remote does not exist yet (404).
  ///
  /// Throws [SyncException] for a transport failure, an oversized response, or an
  /// unreadable remote.
  Future<String?> get();

  /// Uploads [json] as the remote document.
  ///
  /// Throws [SyncException] for a transport failure or a rejecting remote.
  Future<void> put(String json);
}

class HttpSyncClient implements SyncClient {
  HttpSyncClient({
    required http.Client httpClient,
    required SyncOptions options,
    Random? random,
  }) : _http = httpClient,
       _options = options,
       _random = random ?? Random();

  static const String _truncationSuffix = '…';
  static const double _jitterScale = 0.5;
  static const int _maxErrorBodyLength = 500;

  /// Status codes worth a retry: the remote is busy or briefly broken, not wrong.
  static const Set<int> retryableStatusCodes = {408, 429, 500, 502, 503, 504};

  final http.Client _http;
  final SyncOptions _options;
  final Random _random;

  @override
  Future<String?> get() async {
    _options.validate();
    final response = await _sendWithRetries('GET', null);
    if (response.statusCode == 404) return null;

    _ensureSuccess(response);
    return _readCapped(response);
  }

  @override
  Future<void> put(String json) async {
    _options.validate();
    if (json.trim().isEmpty) {
      throw ArgumentError.value(json, 'json', 'The payload must not be empty.');
    }

    final response = await _sendWithRetries('PUT', json);
    _ensureSuccess(response);
  }

  /// One logical request, retried with backoff up to `options.maxRetries` extra attempts.
  Future<http.Response> _sendWithRetries(String method, String? body) async {
    final endpoint = Uri.parse(_options.endpoint);
    final maxAttempts = _options.maxRetries + 1;

    for (var attempt = 1; ; attempt++) {
      try {
        // A fresh request per attempt, and no redirects: an endpoint is validated up front,
        // so silently following a redirect could move credentials somewhere else.
        final request = http.Request(method, endpoint)
          ..followRedirects = false
          ..maxRedirects = 0;
        if (_options.bearerToken != null && _options.bearerToken!.isNotEmpty) {
          request.headers['authorization'] = 'Bearer ${_options.bearerToken}';
        }
        if (body != null) {
          request.body = body;
          request.headers['content-type'] = 'application/json; charset=utf-8';
        }

        final streamed = await _http
            .send(request)
            .timeout(
              _options.requestTimeout,
              onTimeout: () => throw TimeoutException('sync'),
            );
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        if (!retryableStatusCodes.contains(response.statusCode) ||
            attempt >= maxAttempts) {
          return response;
        }

        await _delayBeforeRetry(_retryAfter(response), attempt);
      } on TimeoutException {
        if (attempt >= maxAttempts) {
          throw SyncException(
            'Sync request timed out after $attempt attempt(s) without success.',
          );
        }
        await _delayBeforeRetry(null, attempt);
      } on http.ClientException catch (error) {
        if (attempt >= maxAttempts) {
          throw SyncException('Network error during sync: ${error.message}');
        }
        await _delayBeforeRetry(null, attempt);
      }
    }
  }

  /// Reads the body while enforcing the size cap — a hostile remote cannot exhaust memory.
  String _readCapped(http.Response response) {
    final length = response.bodyBytes.length;
    if (length > _options.maxResponseBytes) {
      throw SyncException(
        'The remote response exceeds the configured maximum of '
        '${_options.maxResponseBytes} bytes.',
      );
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    var body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (body.length > _maxErrorBodyLength) {
      body = '${body.substring(0, _maxErrorBodyLength)}$_truncationSuffix';
    }

    body = SoroushGuard.redactIn(body, _options.bearerToken);
    throw SyncException(
      'Sync remote returned ${response.statusCode}. Body: $body',
      statusCode: response.statusCode,
    );
  }

  /// Exponential backoff with jitter: spreading retries prevents synchronized retry storms.
  Future<void> _delayBeforeRetry(Duration? retryAfter, int attempt) async {
    final backoffMilliseconds =
        _options.retryBaseDelay.inMilliseconds * pow(2, attempt - 1);
    final jittered =
        backoffMilliseconds *
        (1 - _jitterScale + (2 * _jitterScale * _random.nextDouble()));
    final delay = retryAfter ?? Duration(milliseconds: jittered.round());

    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  /// `Retry-After` in seconds, when the remote sent one.
  Duration? _retryAfter(http.Response response) {
    final header = response.headers['retry-after'];
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }
}

class MemorySyncClient implements SyncClient {
  MemorySyncClient({String? document}) : _document = document;

  String? _document;

  /// How many GET/PUT calls have been served (used by tests to prove call counts).
  int getCount = 0;
  int putCount = 0;

  /// The stored document, when one exists.
  String? get document => _document;

  @override
  Future<String?> get() async {
    getCount++;
    return _document;
  }

  @override
  Future<void> put(String json) async {
    putCount++;
    _document = json;
  }
}
