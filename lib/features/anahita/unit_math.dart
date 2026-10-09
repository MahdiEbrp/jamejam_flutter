/// anahita — see doc/anahita.md and AGENTS.md
library;

import 'models.dart';

abstract final class UnitMath {
  static const double _fahrenheitScale = 1.8;
  static const double _fahrenheitOffset = 32.0;
  static const double _kilometresPerMile = 1.609344;
  static const double _kilometresPerHourPerMetrePerSecond = 3.6;
  static const double _kilometresPerNauticalMile = 1.852;

  /// Converts a temperature from Celsius to Fahrenheit.
  static double fahrenheitFromCelsius(double celsius) =>
      (celsius * _fahrenheitScale) + _fahrenheitOffset;

  /// Converts a speed from km/h to mph.
  static double mphFromKmh(double kmh) => kmh / _kilometresPerMile;

  /// Converts a speed from km/h to m/s.
  static double metresPerSecondFromKmh(double kmh) =>
      kmh / _kilometresPerHourPerMetrePerSecond;

  /// Converts a speed from km/h to knots.
  static double knotsFromKmh(double kmh) => kmh / _kilometresPerNauticalMile;

  /// Formats a temperature for display ("18.4°C" or "65.1°F").
  static String temperature(double celsius, WeatherUnits units) =>
      units == WeatherUnits.imperial
      ? '${format(fahrenheitFromCelsius(celsius))}°F'
      : '${format(celsius)}°C';

  /// Formats a speed for display ("12.4 km/h" or "7.7 mph").
  static String speed(double kmh, WeatherUnits units) =>
      units == WeatherUnits.imperial
      ? '${format(mphFromKmh(kmh))} mph'
      : '${format(kmh)} km/h';

  /// The `0.#` invariant format every .NET call site used — numbers are never localized.
  static String format(double value) => _trim(value);

  /// Rounds a nullable API number the way the port must: half away from zero.
  static int toInt(double? value) {
    if (value == null) return 0;
    return value < 0 ? -((-value) + 0.5).floor() : (value + 0.5).floor();
  }

  /// `0.#` / `0.##` style rendering without the `intl` locale: at most [digits]
  /// fraction digits, no trailing zeros, no exponent.
  static String _trim(double value, {int digits = 1}) {
    if (!value.isFinite) return value.toString();
    final rounded = value.toStringAsFixed(digits);
    if (!rounded.contains('.')) return rounded;
    var trimmed = rounded;
    while (trimmed.endsWith('0')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// The `0.##` variant (precipitation in inches uses it).
  static String twoDigits(double value) => _trim(value, digits: 2);

  /// The `0.####` variant — coordinates in labels, cache keys, and query strings.
  static String fourDigits(double value) => _trim(value, digits: 4);
}
