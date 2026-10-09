/// anahita — see doc/anahita.md and AGENTS.md
library;

import 'anahita_defaults.dart';
import 'models.dart';

class AnahitaOptions {
  const AnahitaOptions({
    this.forecastEndpoint = AnahitaDefaults.forecastEndpoint,
    this.geocodingEndpoint = AnahitaDefaults.geocodingEndpoint,
    this.apiKey,
    this.requestTimeout = AnahitaDefaults.requestTimeout,
    this.maxRetries = AnahitaDefaults.maxRetries,
    this.retryBaseDelay = AnahitaDefaults.retryBaseDelay,
    this.maxResponseBytes = AnahitaDefaults.maxResponseBytes,
    this.cacheTtl = AnahitaDefaults.cacheTtl,
    this.forecastDays = AnahitaDefaults.forecastDays,
    this.hourlyWindow = AnahitaDefaults.hourlyWindow,
    this.aiMaxQuestionChars = AnahitaDefaults.aiMaxQuestionChars,
    this.aiMaxTaskCount = AnahitaDefaults.aiMaxTaskCount,
    this.aiHourlyLines = AnahitaDefaults.aiHourlyLines,
  });

  /// Forecast endpoint (Open-Meteo-compatible). HTTPS required; plain HTTP only on loopback.
  final String forecastEndpoint;

  /// Geocoding endpoint (place name → coordinates). Same HTTPS/loopback policy.
  final String geocodingEndpoint;

  /// Optional API key for private/proxied endpoints.
  ///
  /// From the environment only — never the command line, never stored, scrubbed from every
  /// error.
  final String? apiKey;

  /// Per-attempt HTTP timeout.
  final Duration requestTimeout;

  /// Retries for transient failures (408/429/5xx, network errors, timeouts).
  final int maxRetries;

  /// Base delay for exponential backoff (honors `Retry-After`).
  final Duration retryBaseDelay;

  /// Maximum accepted response size — larger responses are rejected before buffering.
  final int maxResponseBytes;

  /// How long a downloaded report stays valid in the cache.
  final Duration cacheTtl;

  /// How many days of daily forecast to request (1–16).
  final int forecastDays;

  /// How many hours the hourly view shows by default (1–48).
  final int hourlyWindow;

  /// Maximum characters of a user weather question included in AI prompts.
  final int aiMaxQuestionChars;

  /// Maximum open tasks included in the AI planning prompt.
  final int aiMaxTaskCount;

  /// Maximum hourly lines included in the AI weather context.
  final int aiHourlyLines;

  /// A copy with the given fields replaced — the .NET `with` expression.
  AnahitaOptions copyWith({
    String? forecastEndpoint,
    String? geocodingEndpoint,
    String? apiKey,
    Duration? requestTimeout,
    int? maxRetries,
    Duration? retryBaseDelay,
    int? maxResponseBytes,
    Duration? cacheTtl,
    int? forecastDays,
    int? hourlyWindow,
    int? aiMaxQuestionChars,
    int? aiMaxTaskCount,
    int? aiHourlyLines,
  }) => AnahitaOptions(
    forecastEndpoint: forecastEndpoint ?? this.forecastEndpoint,
    geocodingEndpoint: geocodingEndpoint ?? this.geocodingEndpoint,
    apiKey: apiKey ?? this.apiKey,
    requestTimeout: requestTimeout ?? this.requestTimeout,
    maxRetries: maxRetries ?? this.maxRetries,
    retryBaseDelay: retryBaseDelay ?? this.retryBaseDelay,
    maxResponseBytes: maxResponseBytes ?? this.maxResponseBytes,
    cacheTtl: cacheTtl ?? this.cacheTtl,
    forecastDays: forecastDays ?? this.forecastDays,
    hourlyWindow: hourlyWindow ?? this.hourlyWindow,
    aiMaxQuestionChars: aiMaxQuestionChars ?? this.aiMaxQuestionChars,
    aiMaxTaskCount: aiMaxTaskCount ?? this.aiMaxTaskCount,
    aiHourlyLines: aiHourlyLines ?? this.aiHourlyLines,
  );

  /// Builds options from the environment, falling back to the named defaults.
  static AnahitaOptions fromEnvironment([
    Map<String, String> environment = const {},
  ]) {
    String? read(String name) {
      final fromMap = environment[name];
      if (fromMap != null && fromMap.trim().isNotEmpty) return fromMap;
      return null;
    }

    return AnahitaOptions(
      forecastEndpoint:
          read(AnahitaDefaults.endpointEnvironmentVariable) ??
          AnahitaDefaults.forecastEndpoint,
      geocodingEndpoint:
          read(AnahitaDefaults.geocodingEnvironmentVariable) ??
          AnahitaDefaults.geocodingEndpoint,
      apiKey: read(AnahitaDefaults.apiKeyEnvironmentVariable),
    );
  }

  /// Validates every value against its named rail, and both endpoints against the
  /// HTTPS/loopback policy.
  ///
  /// Throws [AnahitaException] for any value outside its rail, or an insecure endpoint.
  void validate() {
    _validateEndpoint(forecastEndpoint, 'forecast');
    _validateEndpoint(geocodingEndpoint, 'geocoding');

    if (requestTimeout <= Duration.zero ||
        requestTimeout > AnahitaDefaults.requestTimeoutBound) {
      throw AnahitaException(
        'RequestTimeout must be positive and at most '
        '${AnahitaDefaults.requestTimeoutBound.inMinutes} minutes.',
      );
    }

    if (maxRetries < 0 || maxRetries > AnahitaDefaults.maxRetriesBound) {
      throw AnahitaException(
        'MaxRetries must be between 0 and ${AnahitaDefaults.maxRetriesBound}.',
      );
    }

    if (retryBaseDelay < Duration.zero) {
      throw const AnahitaException('RetryBaseDelay must not be negative.');
    }

    if (maxResponseBytes < 1 ||
        maxResponseBytes > AnahitaDefaults.maxResponseBytesBound) {
      throw AnahitaException(
        'MaxResponseBytes must be between 1 and '
        '${AnahitaDefaults.maxResponseBytesBound}.',
      );
    }

    if (cacheTtl < Duration.zero || cacheTtl > AnahitaDefaults.cacheTtlBound) {
      throw AnahitaException(
        'CacheTtl must be between zero and ${AnahitaDefaults.cacheTtlBound.inHours} hours.',
      );
    }

    if (forecastDays < 1 || forecastDays > AnahitaDefaults.forecastDaysBound) {
      throw AnahitaException(
        'ForecastDays must be between 1 and ${AnahitaDefaults.forecastDaysBound}.',
      );
    }

    if (hourlyWindow < 1 || hourlyWindow > AnahitaDefaults.hourlyWindowBound) {
      throw AnahitaException(
        'HourlyWindow must be between 1 and ${AnahitaDefaults.hourlyWindowBound}.',
      );
    }

    if (aiMaxQuestionChars < 1 ||
        aiMaxQuestionChars > AnahitaDefaults.aiMaxQuestionCharsBound) {
      throw AnahitaException(
        'AiMaxQuestionChars must be between 1 and '
        '${AnahitaDefaults.aiMaxQuestionCharsBound}.',
      );
    }

    if (aiMaxTaskCount < 1 ||
        aiMaxTaskCount > AnahitaDefaults.aiMaxTaskCountBound) {
      throw AnahitaException(
        'AiMaxTaskCount must be between 1 and ${AnahitaDefaults.aiMaxTaskCountBound}.',
      );
    }

    if (aiHourlyLines < 1 ||
        aiHourlyLines > AnahitaDefaults.aiHourlyLinesBound) {
      throw AnahitaException(
        'AiHourlyLines must be between 1 and ${AnahitaDefaults.aiHourlyLinesBound}.',
      );
    }
  }

  static void _validateEndpoint(String endpoint, String kind) {
    if (endpoint.trim().isEmpty) {
      throw AnahitaException('The $kind endpoint must not be empty.');
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      // A malformed URL is caller input, not a platform question — so the URI rules
      // live here rather than behind `dart:io`.
      throw AnahitaException("Invalid $kind endpoint '$endpoint'.");
    }

    if (uri.query.isNotEmpty) {
      throw AnahitaException(
        "The $kind endpoint must be a base URL without a query string ('$endpoint').",
      );
    }

    final secure =
        uri.scheme == 'https' ||
        (uri.scheme == 'http' && _isLoopback(uri.host));
    if (!secure) {
      throw AnahitaException(
        "Insecure $kind endpoint '$endpoint'. "
        'Use HTTPS (plain HTTP is only allowed on loopback).',
      );
    }
  }

  static bool _isLoopback(String host) =>
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '[::1]';
}
