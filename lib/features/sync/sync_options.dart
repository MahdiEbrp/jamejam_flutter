/// sync — see doc/sync.md and AGENTS.md
import 'sync_models.dart';

abstract final class SyncDefaults {
  /// Default per-attempt HTTP timeout for sync calls.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Default number of retries for transient sync failures.
  static const int maxRetries = 2;

  /// Default base delay for exponential backoff between sync retries.
  static const Duration retryBaseDelay = Duration(milliseconds: 300);

  /// Default maximum accepted sync response size (8 MiB).
  static const int maxResponseBytes = 8 * 1024 * 1024;

  /// Default maximum sealed payload size (8 MiB).
  static const int maxPayloadBytes = 8 * 1024 * 1024;

  /// Environment variable carrying the optional sync bearer token (never the CLI).
  static const String tokenEnvironmentVariable = 'JAMEJAM_SYNC_TOKEN';

  /// Environment variable carrying the sync URL (the settings screen can override it).
  static const String urlEnvironmentVariable = 'JAMEJAM_SYNC_URL';

  /// Settings key that stores a default sync URL.
  static const String urlSettingKey = 'haftkhan.syncUrl';

  /// Upper rail for the request timeout.
  static const Duration requestTimeoutBound = Duration(minutes: 10);

  /// Upper rail for retries.
  static const int maxRetriesBound = 10;

  /// Upper rail for the response size cap (64 MiB).
  static const int maxResponseBytesBound = 64 * 1024 * 1024;

  /// Upper rail for the sealed payload size (64 MiB).
  static const int maxPayloadBytesBound = 64 * 1024 * 1024;
}

class SyncOptions {
  const SyncOptions({
    this.endpoint = '',
    this.bearerToken,
    this.requestTimeout = SyncDefaults.requestTimeout,
    this.maxRetries = SyncDefaults.maxRetries,
    this.retryBaseDelay = SyncDefaults.retryBaseDelay,
    this.maxResponseBytes = SyncDefaults.maxResponseBytes,
  });

  /// Sync endpoint (custom URL). HTTPS required; plain HTTP only on loopback.
  final String endpoint;

  /// Optional bearer token. From the environment only — never the command line, never stored.
  final String? bearerToken;

  /// Per-attempt HTTP timeout.
  final Duration requestTimeout;

  /// Retries for transient failures (408/429/5xx, network errors, timeouts).
  final int maxRetries;

  /// Base delay for exponential backoff (honors Retry-After).
  final Duration retryBaseDelay;

  /// Maximum accepted response size — larger responses are rejected before buffering.
  final int maxResponseBytes;

  SyncOptions copyWith({
    String? endpoint,
    String? bearerToken,
    Duration? requestTimeout,
    int? maxRetries,
    Duration? retryBaseDelay,
    int? maxResponseBytes,
  }) => SyncOptions(
    endpoint: endpoint ?? this.endpoint,
    bearerToken: bearerToken ?? this.bearerToken,
    requestTimeout: requestTimeout ?? this.requestTimeout,
    maxRetries: maxRetries ?? this.maxRetries,
    retryBaseDelay: retryBaseDelay ?? this.retryBaseDelay,
    maxResponseBytes: maxResponseBytes ?? this.maxResponseBytes,
  );

  /// True when [endpoint] is HTTPS, or plain HTTP on the loopback interface.
  static bool isSecureEnough(Uri uri) {
    if (uri.scheme == 'https') return true;
    return uri.scheme == 'http' && uri.host.isNotEmpty && _isLoopback(uri.host);
  }

  static bool _isLoopback(String host) {
    final lowered = host.toLowerCase();
    if (lowered == 'localhost' || lowered == '::1' || lowered == '[::1]') {
      return true;
    }
    final parts = lowered.split('.');
    return parts.length == 4 &&
        parts.first == '127' &&
        parts.every((part) => int.tryParse(part) != null);
  }

  /// Validates every value against its named rail, and the endpoint against the policy.
  ///
  /// Throws [SyncException] for any value outside its rail, or an insecure endpoint.
  void validate() {
    if (endpoint.trim().isEmpty) {
      throw const SyncException('Sync endpoint must not be empty.');
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.isAbsolute) {
      throw SyncException("Invalid sync endpoint '$endpoint'.");
    }

    if (!isSecureEnough(uri)) {
      throw SyncException(
        "Insecure sync endpoint '$endpoint'. Use HTTPS "
        '(plain HTTP is only allowed on loopback).',
      );
    }

    if (bearerToken != null && bearerToken!.isEmpty) {
      throw const SyncException(
        'Bearer token must not be empty when provided.',
      );
    }

    if (requestTimeout <= Duration.zero ||
        requestTimeout > SyncDefaults.requestTimeoutBound) {
      throw SyncException(
        'RequestTimeout must be positive and at most '
        '${SyncDefaults.requestTimeoutBound.inMinutes} minutes.',
      );
    }

    if (maxRetries < 0 || maxRetries > SyncDefaults.maxRetriesBound) {
      throw SyncException(
        "MaxRetries must be between 0 and ${SyncDefaults.maxRetriesBound}.",
      );
    }

    if (retryBaseDelay < Duration.zero) {
      throw const SyncException('RetryBaseDelay must not be negative.');
    }

    if (maxResponseBytes < 1 ||
        maxResponseBytes > SyncDefaults.maxResponseBytesBound) {
      throw SyncException(
        'MaxResponseBytes must be between 1 and ${SyncDefaults.maxResponseBytesBound}.',
      );
    }
  }
}
