/// anahita — see doc/anahita.md and AGENTS.md
library;

abstract final class AnahitaDefaults {
  /// Human-facing service name used in help and errors.
  static const String serviceName = 'Anahita';

  // ── Endpoints (Open-Meteo, keyless) ──

  /// Default forecast endpoint (Open-Meteo-compatible; override for self-hosted mirrors).
  static const String forecastEndpoint =
      'https://api.open-meteo.com/v1/forecast';

  /// Default geocoding endpoint (place name → coordinates).
  static const String geocodingEndpoint =
      'https://geocoding-api.open-meteo.com/v1/search';

  /// How many geocoding candidates the service asks for (the first is used).
  static const int geocodeResultLimit = 5;

  // ── Environment and settings ──

  /// Environment variable carrying the default location (flag and settings override it).
  static const String locationEnvironmentVariable = 'ANAHITA_LOCATION';

  /// Environment variable carrying a forecast endpoint override.
  static const String endpointEnvironmentVariable = 'ANAHITA_ENDPOINT';

  /// Environment variable carrying a geocoding endpoint override.
  static const String geocodingEnvironmentVariable = 'ANAHITA_GEOCODING_URL';

  /// Environment variable carrying an optional API key for private/proxied endpoints.
  ///
  /// Sent as a bearer token; never accepted on the command line, never stored.
  static const String apiKeyEnvironmentVariable = 'ANAHITA_API_KEY';

  /// Environment variable carrying the default units.
  static const String unitsEnvironmentVariable = 'ANAHITA_UNITS';

  /// Settings key that stores the default location.
  static const String locationSettingKey = 'anahita.location';

  /// Settings key that stores the default units (metric|imperial).
  static const String unitsSettingKey = 'anahita.units';

  /// Guidance shown when no location can be resolved.
  static const String noLocationMessage =
      'No location. Pass --at <place>, set ANAHITA_LOCATION, or save it once: '
      'JameJam weather set Berlin';

  // ── Transport rails ──

  /// Default per-attempt HTTP timeout for weather calls.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Default number of retries for transient weather failures.
  static const int maxRetries = 2;

  /// Default base delay for exponential backoff between retries.
  static const Duration retryBaseDelay = Duration(milliseconds: 300);

  /// Default maximum accepted response size (4 MiB).
  static const int maxResponseBytes = 4 * 1024 * 1024;

  /// Default duration a weather report stays in the cache.
  static const Duration cacheTtl = Duration(minutes: 15);

  // ── Forecast shape rails ──

  /// Default number of forecast days to request.
  static const int forecastDays = 7;

  /// Default number of hours shown by the hourly view.
  static const int hourlyWindow = 24;

  /// Days of the forecast (starting today) the alert engine watches.
  static const int alertHorizonDays = 2;

  /// Days listed by the best-day ranking.
  static const int bestDayCount = 3;

  // ── Coordinate rails ──

  /// Absolute latitude bound (±90°).
  static const double latitudeBound = 90.0;

  /// Absolute longitude bound (±180°).
  static const double longitudeBound = 180.0;

  // ── Alert thresholds ──

  /// Daily maximum at or above which a heat alert fires (°C).
  static const double heatCelsius = 35.0;

  /// Daily minimum at or below which a deep-freeze alert fires (°C).
  static const double coldCelsius = -10.0;

  /// Daily minimum at or below which a frost watch fires (°C).
  static const double frostCelsius = 0.0;

  /// Daily wind maximum at or above which a strong-wind alert fires (km/h).
  static const double strongWindKmh = 60.0;

  /// Daily precipitation sum at or above which a heavy-rain alert fires (mm).
  static const double heavyRainMm = 25.0;

  /// Daily UV maximum at or above which a high-UV watch fires.
  static const double highUv = 8.0;

  /// Precipitation probability at or above which advice suggests rain gear (%).
  static const double rainAdvicePercent = 50.0;

  /// Hourly/daily precipitation total considered "rain actually fell" (mm).
  static const double rainTraceMm = 1.0;

  // ── Outdoor-day scoring ──

  /// Score of a perfect outdoor day; penalties subtract from it.
  static const int perfectScore = 100;

  /// Penalty per degree Celsius between a day's mean temperature and comfort.
  static const int temperaturePenaltyPerDegree = 2;

  /// Penalty applied to days with strong wind.
  static const int windPenalty = 25;

  /// Penalty applied to days with a thunderstorm code.
  static const int thunderPenalty = 60;

  /// Largest penalty a day's rain chance can contribute.
  static const int rainPenaltyMax = 40;

  /// Mean temperature considered most pleasant for outdoor plans (°C).
  static const double comfortCelsius = 22.0;

  // ── AI prompt tunables (Soroush layer) ──

  /// Maximum characters of a user weather question included in AI prompts.
  static const int aiMaxQuestionChars = 400;

  /// Maximum open tasks included in the AI planning prompt.
  static const int aiMaxTaskCount = 30;

  /// Maximum hourly lines included in the AI weather context.
  static const int aiHourlyLines = 12;

  /// Maximum characters of a task title inside AI prompts.
  static const int aiTaskTitleChars = 80;

  // ── Safety rails (bounds) ──

  /// Upper rail for the AI question length.
  static const int aiMaxQuestionCharsBound = 2000;

  /// Upper rail for the AI task count.
  static const int aiMaxTaskCountBound = 100;

  /// Upper rail for AI hourly lines.
  static const int aiHourlyLinesBound = 48;

  /// Upper rail for task titles inside AI prompts.
  static const int aiTaskTitleCharsBound = 200;

  /// Upper rail for the request timeout.
  static const Duration requestTimeoutBound = Duration(minutes: 10);

  /// Upper rail for retries.
  static const int maxRetriesBound = 10;

  /// Upper rail for the response size cap (64 MiB).
  static const int maxResponseBytesBound = 64 * 1024 * 1024;

  /// Upper rail for the cache TTL.
  static const Duration cacheTtlBound = Duration(hours: 24);

  /// Upper rail for forecast days (Open-Meteo serves at most 16).
  static const int forecastDaysBound = 16;

  /// Upper rail for the hourly window (the API serves 48 hours usefully).
  static const int hourlyWindowBound = 48;
}
