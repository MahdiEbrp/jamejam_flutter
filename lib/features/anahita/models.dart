/// anahita — see doc/anahita.md and AGENTS.md
library;

import '../../core/date_only.dart';

enum WeatherUnits {
  /// Celsius, km/h, millimetres — the default.
  metric(0, 'metric'),

  /// Fahrenheit and mph.
  imperial(1, 'imperial');

  const WeatherUnits(this.code, this.name);

  /// Numeric code, identical to the .NET enum.
  final int code;

  /// Wire/name form used in settings (`anahita.units`).
  final String name;

  /// Parses the settings/flag form, accepting the aliases the CLI accepted.
  static WeatherUnits parse(String? text) =>
      switch (text?.trim().toLowerCase()) {
        null || '' || 'metric' || 'c' || 'celsius' => WeatherUnits.metric,
        'imperial' || 'f' || 'fahrenheit' => WeatherUnits.imperial,
        _ => throw AnahitaException(
          "Unknown units '$text'. Use metric or imperial.",
        ),
      };
}

class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    this.admin1,
    this.population = 0,
  });

  /// Primary place name (or a "lat, lon" label for raw coordinates).
  final String name;

  /// Country name; empty when unknown.
  final String country;

  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  /// IANA timezone of the place (or `auto` before resolution).
  final String timezone;

  /// Administrative division (state/region); null when unknown.
  final String? admin1;

  /// Population when known (used by geocoders for ranking); 0 when unknown.
  final int population;

  /// Human-friendly display name, e.g. "Berlin, Germany".
  ///
  /// The admin division is only added when it differs from the place name itself — the
  /// geocoder repeats them for city-states.
  String get displayName {
    final parts = <String>[name];
    final admin = admin1;
    if (admin != null &&
        admin.trim().isNotEmpty &&
        admin.toLowerCase() != name.toLowerCase()) {
      parts.add(admin);
    }
    if (country.trim().isNotEmpty) {
      parts.add(country);
    }
    return parts.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPlace &&
      other.name == name &&
      other.country == country &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timezone == timezone &&
      other.admin1 == admin1 &&
      other.population == population;

  @override
  int get hashCode => Object.hash(
    name,
    country,
    latitude,
    longitude,
    timezone,
    admin1,
    population,
  );

  @override
  String toString() =>
      'GeoPlace($name, ${latitude.toStringAsFixed(2)}, '
      '${longitude.toStringAsFixed(2)}, $timezone)';

  /// A copy with the API-resolved timezone (or any other field) replaced.
  GeoPlace copyWith({String? timezone}) => GeoPlace(
    name: name,
    country: country,
    latitude: latitude,
    longitude: longitude,
    timezone: timezone ?? this.timezone,
    admin1: admin1,
    population: population,
  );
}

class CurrentConditions {
  const CurrentConditions({
    required this.localTime,
    required this.temperatureC,
    required this.apparentC,
    required this.humidityPercent,
    required this.precipMm,
    required this.code,
    required this.windKmh,
    required this.windDirectionDeg,
  });

  /// Local wall-clock time of the observation (naive local, from the API).
  final DateTime localTime;

  /// Air temperature (°C).
  final double temperatureC;

  /// Feels-like temperature (°C).
  final double apparentC;

  /// Relative humidity (%).
  final int humidityPercent;

  /// Precipitation in the current hour (mm).
  final double precipMm;

  /// WMO weather code (see `WeatherCode`).
  final int code;

  /// Wind speed (km/h).
  final double windKmh;

  /// Wind direction in degrees (0 = north).
  final int windDirectionDeg;

  @override
  bool operator ==(Object other) =>
      other is CurrentConditions &&
      other.localTime == localTime &&
      other.temperatureC == temperatureC &&
      other.apparentC == apparentC &&
      other.humidityPercent == humidityPercent &&
      other.precipMm == precipMm &&
      other.code == code &&
      other.windKmh == windKmh &&
      other.windDirectionDeg == windDirectionDeg;

  @override
  int get hashCode => Object.hash(
    localTime,
    temperatureC,
    apparentC,
    humidityPercent,
    precipMm,
    code,
    windKmh,
    windDirectionDeg,
  );

  @override
  String toString() =>
      'CurrentConditions(${temperatureC.toStringAsFixed(1)}°C, '
      'feels ${apparentC.toStringAsFixed(1)}°C, '
      '$humidityPercent% humidity, code $code)';
}

class HourlyPoint {
  const HourlyPoint({
    required this.localTime,
    required this.temperatureC,
    required this.apparentC,
    required this.precipProbabilityPercent,
    required this.precipMm,
    required this.code,
    required this.windKmh,
    required this.humidityPercent,
  });

  /// Local wall-clock time (naive local, from the API).
  final DateTime localTime;

  /// Air temperature (°C).
  final double temperatureC;

  /// Feels-like temperature (°C).
  final double apparentC;

  /// Chance of precipitation (%); null when the API omits it.
  final double? precipProbabilityPercent;

  /// Expected precipitation (mm).
  final double precipMm;

  /// WMO weather code.
  final int code;

  /// Wind speed (km/h).
  final double windKmh;

  /// Relative humidity (%).
  final int humidityPercent;

  @override
  bool operator ==(Object other) =>
      other is HourlyPoint &&
      other.localTime == localTime &&
      other.temperatureC == temperatureC &&
      other.apparentC == apparentC &&
      other.precipProbabilityPercent == precipProbabilityPercent &&
      other.precipMm == precipMm &&
      other.code == code &&
      other.windKmh == windKmh &&
      other.humidityPercent == humidityPercent;

  @override
  int get hashCode => Object.hash(
    localTime,
    temperatureC,
    apparentC,
    precipProbabilityPercent,
    precipMm,
    code,
    windKmh,
    humidityPercent,
  );

  @override
  String toString() =>
      'HourlyPoint(${localTime.hour.toString().padLeft(2, '0')}:'
      '${localTime.minute.toString().padLeft(2, '0')} '
      '${temperatureC.toStringAsFixed(1)}°C, code $code)';
}

class DailyPoint {
  const DailyPoint({
    required this.date,
    required this.code,
    required this.minC,
    required this.maxC,
    required this.precipProbabilityPercent,
    required this.precipSumMm,
    required this.windMaxKmh,
    required this.uvMax,
    required this.sunrise,
    required this.sunset,
  });

  /// Forecast date.
  final DateOnly date;

  /// Dominant WMO weather code.
  final int code;

  /// Minimum temperature (°C).
  final double minC;

  /// Maximum temperature (°C).
  final double maxC;

  /// Maximum chance of precipitation (%); null when omitted.
  final double? precipProbabilityPercent;

  /// Expected precipitation total (mm).
  final double precipSumMm;

  /// Maximum wind speed (km/h).
  final double windMaxKmh;

  /// Maximum UV index; null when omitted.
  final double? uvMax;

  /// Local sunrise time; null when omitted.
  final TimeOfDayValue? sunrise;

  /// Local sunset time; null when omitted.
  final TimeOfDayValue? sunset;

  @override
  bool operator ==(Object other) =>
      other is DailyPoint &&
      other.date == date &&
      other.code == code &&
      other.minC == minC &&
      other.maxC == maxC &&
      other.precipProbabilityPercent == precipProbabilityPercent &&
      other.precipSumMm == precipSumMm &&
      other.windMaxKmh == windMaxKmh &&
      other.uvMax == uvMax &&
      other.sunrise == sunrise &&
      other.sunset == sunset;

  @override
  int get hashCode => Object.hash(
    date,
    code,
    minC,
    maxC,
    precipProbabilityPercent,
    precipSumMm,
    windMaxKmh,
    uvMax,
    sunrise,
    sunset,
  );

  @override
  String toString() =>
      'DailyPoint(${date.toIso()}, '
      '${minC.toStringAsFixed(1)}-${maxC.toStringAsFixed(1)}°C, code $code)';
}

class TimeOfDayValue {
  const TimeOfDayValue(this.hour, this.minute);

  /// Hour, 0–23.
  final int hour;

  /// Minute, 0–59.
  final int minute;

  /// `HH:mm`, the format every .NET call site used.
  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayValue && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();
}

class WeatherReport {
  const WeatherReport({
    required this.place,
    required this.fetchedAt,
    required this.current,
    required this.hourly,
    required this.daily,
  });

  /// Resolved location (with the API-resolved timezone).
  final GeoPlace place;

  /// When the report was downloaded (UTC).
  final DateTime fetchedAt;

  /// Current conditions.
  final CurrentConditions current;

  /// Hourly forecast, starting at the current hour.
  final List<HourlyPoint> hourly;

  /// Daily forecast, starting today.
  final List<DailyPoint> daily;

  @override
  bool operator ==(Object other) =>
      other is WeatherReport &&
      other.place == place &&
      other.fetchedAt == fetchedAt &&
      other.current == current &&
      _sameList(other.hourly, hourly) &&
      _sameList(other.daily, daily);

  @override
  int get hashCode => Object.hash(
    place,
    fetchedAt,
    current,
    Object.hashAll(hourly),
    Object.hashAll(daily),
  );

  @override
  String toString() =>
      'WeatherReport(${place.name}, fetched ${fetchedAt.toIso8601String()}, '
      '${hourly.length} hour(s), ${daily.length} day(s))';

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

enum AlertSeverity {
  /// Worth knowing about — plan around it.
  watch(0),

  /// Take action — protect yourself and others.
  warning(1);

  const AlertSeverity(this.code);

  /// Numeric code, identical to the .NET enum.
  final int code;
}

class WeatherAlert {
  const WeatherAlert({
    required this.severity,
    required this.title,
    required this.message,
  });

  /// How urgent the alert is.
  final AlertSeverity severity;

  /// Short label, e.g. "Heat".
  final String title;

  /// Human-friendly one-line detail.
  final String message;
}

class DayAdvice {
  const DayAdvice({
    required this.date,
    required this.score,
    required this.summary,
  });

  /// Forecast date.
  final DateOnly date;

  /// 0–100; higher is better for being outside.
  final int score;

  /// Human-friendly summary of the conditions.
  final String summary;
}

class AnahitaException implements Exception {
  const AnahitaException(this.message, {this.statusCode, this.inner});

  /// Safe, redacted description of the failure.
  final String message;

  /// HTTP status code from the endpoint, when applicable.
  final int? statusCode;

  /// Original error, when applicable.
  final Object? inner;

  @override
  String toString() => message;
}
