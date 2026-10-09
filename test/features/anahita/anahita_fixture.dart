// Shared fixtures for the Phase 5 (Anahita) parity suites.
//
// A direct port of `tests/JameJam.Tests/Anahita/AnahitaTestSupport.cs`: the same frozen
// instant, the same canonical Berlin place, the same deterministic report, and the same
// Open-Meteo payloads — so the Dart expectations can be compared line-by-line with the
// original's.
import 'dart:convert';

import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/anahita/models.dart';

/// Deterministic places, reports, and payloads.
abstract final class AnahitaFixture {
  /// The frozen test instant (2026-09-19T10:00Z).
  static final DateTime now = DateTime.utc(2026, 9, 19, 10);

  /// A canonical Berlin place.
  static GeoPlace berlin() => const GeoPlace(
    name: 'Berlin',
    country: 'Germany',
    latitude: 52.52,
    longitude: 13.41,
    timezone: 'Europe/Berlin',
    admin1: 'State of Berlin',
    population: 3664088,
  );

  /// Builds a configurable daily point.
  static DailyPoint day(
    DateOnly date, {
    int code = 2,
    double min = 12.5,
    double max = 19.2,
    double? chance = 10,
    double sum = 0.4,
    double wind = 21.3,
    double? uv = 4.2,
  }) => DailyPoint(
    date: date,
    code: code,
    minC: min,
    maxC: max,
    precipProbabilityPercent: chance,
    precipSumMm: sum,
    windMaxKmh: wind,
    uvMax: uv,
    sunrise: const TimeOfDayValue(6, 41),
    sunset: const TimeOfDayValue(19, 22),
  );

  /// Builds a deterministic report from the given daily points.
  ///
  /// [hourly] defaults to [hours]; pass an empty list for the "no hourly data" case.
  static WeatherReport report([
    List<DailyPoint> daily = const [],
    List<HourlyPoint>? hourly,
  ]) => WeatherReport(
    place: berlin(),
    fetchedAt: now,
    current: CurrentConditions(
      localTime: DateTime(2026, 9, 19, 14),
      temperatureC: 18.4,
      apparentC: 17.9,
      humidityPercent: 62,
      precipMm: 0.4,
      code: 2,
      windKmh: 12.4,
      windDirectionDeg: 315,
    ),
    hourly: hourly ?? hours(),
    daily: daily,
  );

  /// The two hourly points every default report carries.
  static List<HourlyPoint> hours() => [
    HourlyPoint(
      localTime: DateTime(2026, 9, 19, 14),
      temperatureC: 18.4,
      apparentC: 17.9,
      precipProbabilityPercent: 10,
      precipMm: 0,
      code: 2,
      windKmh: 12.4,
      humidityPercent: 62,
    ),
    HourlyPoint(
      localTime: DateTime(2026, 9, 19, 15),
      temperatureC: 18.9,
      apparentC: 18.1,
      precipProbabilityPercent: 20,
      precipMm: 0.1,
      code: 3,
      windKmh: 13.1,
      humidityPercent: 60,
    ),
  ];

  /// A minimal realistic Open-Meteo forecast payload.
  static Map<String, dynamic> forecastJson() =>
      jsonDecode('''
{
  "latitude": 52.52, "longitude": 13.41, "timezone": "Europe/Berlin",
  "current": {"time": "2026-09-19T14:00", "temperature_2m": 18.4, "apparent_temperature": 17.9,
              "relative_humidity_2m": 62, "precipitation": 0.4, "weather_code": 2,
              "wind_speed_10m": 12.4, "wind_direction_10m": 315},
  "hourly": {
    "time": ["2026-09-19T14:00", "2026-09-19T15:00"],
    "temperature_2m": [18.4, 18.9], "apparent_temperature": [17.9, 18.1],
    "relative_humidity_2m": [62, 60], "precipitation_probability": [10, null],
    "precipitation": [0.0, 0.1], "weather_code": [2, 3], "wind_speed_10m": [12.4, 13.1]},
  "daily": {
    "time": ["2026-09-19", "2026-09-20"],
    "weather_code": [2, 61], "temperature_2m_max": [19.2, 16.1], "temperature_2m_min": [12.5, 11.0],
    "precipitation_sum": [0.4, 8.2], "precipitation_probability_max": [10, 80],
    "wind_speed_10m_max": [21.3, 33.5], "uv_index_max": [4.2, null],
    "sunrise": ["2026-09-19T06:41", "2026-09-20T06:43"], "sunset": ["2026-09-19T19:22", "2026-09-20T19:20"]}
}
''')
          as Map<String, dynamic>;

  /// A minimal Open-Meteo geocoding payload with two results.
  static Map<String, dynamic> geocodeJson() =>
      jsonDecode('''
{
  "results": [
    {"name": "Berlin", "latitude": 52.52437, "longitude": 13.41053,
     "country": "Germany", "admin1": "State of Berlin", "timezone": "Europe/Berlin",
     "population": 3664088},
    {"name": "Berlin", "latitude": 44.46867, "longitude": -71.18508,
     "country": "United States", "timezone": "America/New_York", "population": 9365}
  ]
}
''')
          as Map<String, dynamic>;

  /// An empty geocoding payload (no place matched).
  static Map<String, dynamic> geocodeEmptyJson() =>
      jsonDecode('{"generationtime_ms": 0.5}') as Map<String, dynamic>;

  /// The JSON bodies above, as text (what the HTTP layer actually sees).
  static String forecastBody() => jsonEncode(forecastJson());
  static String geocodeBody() => jsonEncode(geocodeJson());
  static String geocodeEmptyBody() => jsonEncode(geocodeEmptyJson());

  /// A movable clock, standing in for `SteppingTimeProvider`.
  static SteppingClock clock([DateTime? start]) => SteppingClock(start ?? now);
}

/// A clock the tests can push forward, standing in for .NET's `TimeProvider`.
class SteppingClock {
  SteppingClock(this._now);

  DateTime _now;

  /// The current instant.
  DateTime get now => _now;

  /// Reads the clock the way the service and cache do.
  DateTime call() => _now;

  /// Moves the clock forward.
  void advance(Duration delta) => _now = _now.add(delta);
}
