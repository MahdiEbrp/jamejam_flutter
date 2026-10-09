/// soroush — see doc/soroush.md and AGENTS.md
abstract final class SoroushLimits {
  /// Default maximum completion tokens to request.
  static const int defaultMaxTokens = 512;

  /// Default per-attempt request timeout.
  static const Duration defaultRequestTimeout = Duration(seconds: 60);

  /// Default number of transient-failure retries.
  static const int defaultMaxRetries = 2;

  /// Default base delay for exponential backoff.
  static const Duration defaultRetryBaseDelay = Duration(milliseconds: 500);

  /// Default maximum allowed prompt length.
  static const int defaultMaxPromptLength = 8000;

  /// Default maximum provider error-body length echoed in exceptions.
  static const int defaultMaxErrorBodyLength = 500;

  /// Default retry-backoff jitter fraction (50%–150% of the computed delay).
  static const double defaultJitterScale = 0.5;

  // ── Safety rails (the bounds of configuration itself) ──

  /// Upper rail for `maxTokens`.
  static const int maxTokensBound = 100000;

  /// Upper rail for `requestTimeout`.
  static const Duration requestTimeoutBound = Duration(minutes: 10);

  /// Upper rail for `maxRetries`.
  static const int maxRetriesBound = 10;

  /// Lower rail for `maxErrorBodyLength`.
  static const int minErrorBodyLength = 50;

  /// Upper rail for `maxErrorBodyLength`.
  static const int maxErrorBodyLengthBound = 100000;

  /// Default number of secret characters kept visible when redacting.
  static const int redactDefaultSuffixLength = 4;

  /// Upper rail for the redaction suffix length.
  static const int redactSuffixLengthBound = 64;
}

class SoroushException implements Exception {
  const SoroushException(this.message, {this.statusCode, this.cause});

  /// Safe, redacted description of the failure.
  final String message;

  /// HTTP status code from the provider, when applicable.
  final int? statusCode;

  /// Original error, when applicable.
  final Object? cause;

  @override
  String toString() => statusCode == null
      ? 'SoroushException: $message'
      : 'SoroushException($statusCode): $message';
}

class SoroushOptions {
  const SoroushOptions({
    this.provider = SoroushDefaults.openAiCompatibleProviderName,
    this.endpoint,
    this.apiKey,
    this.model,
    this.maxTokens = SoroushLimits.defaultMaxTokens,
    this.requestTimeout = SoroushLimits.defaultRequestTimeout,
    this.maxRetries = SoroushLimits.defaultMaxRetries,
    this.retryBaseDelay = SoroushLimits.defaultRetryBaseDelay,
    this.maxPromptLength = SoroushLimits.defaultMaxPromptLength,
    this.maxErrorBodyLength = SoroushLimits.defaultMaxErrorBodyLength,
    this.jitterScale = SoroushLimits.defaultJitterScale,
    this.retryableStatusCodes = defaultRetryableStatusCodes,
  });

  /// Provider name — see the provider registry. Default: OpenAI-compatible.
  final String provider;

  /// API endpoint. **HTTPS required**; plain HTTP is allowed only on loopback.
  ///
  /// Null means "use the resolved provider's default endpoint", so an Anthropic call can
  /// never accidentally be sent to the OpenAI URL.
  final String? endpoint;

  /// API key. Treated as a secret: never logged, never echoed, never stored in settings.
  final String? apiKey;

  /// Model identifier. Null falls back to the provider default.
  final String? model;

  /// Maximum completion tokens to request.
  final int maxTokens;

  /// Per-attempt request timeout.
  final Duration requestTimeout;

  /// How many times to retry transient failures (retryable statuses, network errors, timeouts).
  final int maxRetries;

  /// Base delay for exponential backoff between retries. Honors `Retry-After` when present.
  final Duration retryBaseDelay;

  /// Maximum allowed prompt length (safety layer).
  final int maxPromptLength;

  /// Maximum provider error-body length echoed in exception messages.
  final int maxErrorBodyLength;

  /// Fraction of the computed backoff used as jitter: 0 = deterministic, 0.5 = 50%–150%.
  final double jitterScale;

  /// HTTP status codes considered transient.
  final Set<int> retryableStatusCodes;

  /// Statuses retried by default: 408, 429, 500, 502, 503, 504.
  static const Set<int> defaultRetryableStatusCodes = {
    408,
    429,
    500,
    502,
    503,
    504,
  };

  SoroushOptions copyWith({
    String? provider,
    String? endpoint,
    String? apiKey,
    String? model,
    int? maxTokens,
    Duration? requestTimeout,
    int? maxRetries,
    Duration? retryBaseDelay,
    int? maxPromptLength,
    int? maxErrorBodyLength,
    double? jitterScale,
    Set<int>? retryableStatusCodes,
    bool clearApiKey = false,
    bool clearEndpoint = false,
    bool clearModel = false,
  }) {
    return SoroushOptions(
      provider: provider ?? this.provider,
      endpoint: clearEndpoint ? null : (endpoint ?? this.endpoint),
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
      model: clearModel ? null : (model ?? this.model),
      maxTokens: maxTokens ?? this.maxTokens,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      maxRetries: maxRetries ?? this.maxRetries,
      retryBaseDelay: retryBaseDelay ?? this.retryBaseDelay,
      maxPromptLength: maxPromptLength ?? this.maxPromptLength,
      maxErrorBodyLength: maxErrorBodyLength ?? this.maxErrorBodyLength,
      jitterScale: jitterScale ?? this.jitterScale,
      retryableStatusCodes: retryableStatusCodes ?? this.retryableStatusCodes,
    );
  }
}

abstract final class SoroushDefaults {
  /// Canonical name of the OpenAI-compatible provider.
  static const String openAiCompatibleProviderName = 'openai';

  /// Canonical name of the Anthropic provider.
  static const String anthropicProviderName = 'anthropic';

  /// Canonical OpenAI chat-completions endpoint (works with most compatible APIs too).
  static const String openAiCompatibleEndpoint =
      'https://api.openai.com/v1/chat/completions';

  /// Canonical Anthropic messages endpoint.
  static const String anthropicEndpoint =
      'https://api.anthropic.com/v1/messages';

  /// Default OpenAI-compatible model.
  static const String openAiCompatibleModel = 'gpt-4o-mini';

  /// Default Anthropic model.
  static const String anthropicModel = 'claude-3-5-haiku-latest';
}
