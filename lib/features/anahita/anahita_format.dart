/// anahita — see doc/anahita.md and AGENTS.md
library;

import '../../core/date_only.dart';
import 'anahita_insights.dart';
import 'models.dart';
import 'unit_math.dart';
import 'weather_code.dart';

abstract final class AnahitaFormat {
  static const int _compassPoints = 16;
  static const double _millimetresPerInch = 25.4;

  static const List<String> _compassRose = <String>[
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
  ];

  static const List<String> _weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Converts a wind direction in degrees to a 16-point compass label.
  static String compass(int degrees) {
    // Dart's `%` is already Euclidean (non-negative), matching the .NET expression.
    final index =
        ((degrees % 360) / (360.0 / _compassPoints)).round() % _compassPoints;
    return _compassRose[index];
  }

  /// The `ddd d MMM` label used by alerts, the daily table, and the plan view.
  static String dayLabel(DateOnly date) =>
      '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

  /// `HH:mm` for a wall-clock time.
  static String clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  /// Formats the "right now" block: place header, conditions, and sun times.
  static String formatNow(WeatherReport report, WeatherUnits units) {
    final current = report.current;
    final today = report.daily.isEmpty ? null : report.daily.first;

    final heading =
        '${report.place.displayName} — ${coordinates(report.place)}'
        ' · ${report.place.timezone}';
    final conditions =
        '${WeatherCode.icon(current.code)} ${WeatherCode.describe(current.code)}'
        ' · ${UnitMath.temperature(current.temperatureC, units)}'
        ' (feels ${UnitMath.temperature(current.apparentC, units)})'
        ' · humidity ${current.humidityPercent}%';
    final wind =
        'Wind ${UnitMath.speed(current.windKmh, units)}'
        ' ${compass(current.windDirectionDeg)}'
        ' · precip now ${precipitation(current.precipMm, units)}';

    final lines = <String>[heading, conditions, wind];

    final sunrise = today?.sunrise;
    final sunset = today?.sunset;
    if (sunrise != null && sunset != null) {
      final uv = today!.uvMax;
      final uvNote = uv == null ? '' : ' · UV max ${UnitMath.format(uv)}';
      lines.add(
        'Sunrise ${sunrise.format()} · Sunset ${sunset.format()}$uvNote',
      );
    }

    return lines.join('\n');
  }

  /// Formats the alert list; empty string (no section) when there is nothing to warn about.
  static String formatAlerts(List<WeatherAlert> alerts) {
    if (alerts.isEmpty) return '';

    return <String>[
      'Alerts',
      for (final alert in alerts) _alertLine(alert),
    ].join('\n');
  }

  static String _alertLine(WeatherAlert alert) {
    final glyph = alert.severity == AlertSeverity.warning ? '⚠' : '☑';
    return '$glyph ${alert.title} — ${alert.message}';
  }

  /// Formats the next hours as a compact table.
  static String formatHourly(
    WeatherReport report,
    WeatherUnits units,
    int hours,
  ) {
    final slice = report.hourly.take(hours).toList();
    if (slice.isEmpty) return 'No hourly data available.';

    return <String>[
      'Next ${slice.length} hour(s)',
      for (final point in slice) _hourLine(point, units),
    ].join('\n');
  }

  static String _hourLine(HourlyPoint point, WeatherUnits units) =>
      '${clock(point.localTime)}'
      '  ${UnitMath.temperature(point.temperatureC, units).padLeft(7)}'
      '  ${WeatherCode.icon(point.code)}'
      '  ${rainChance(point.precipProbabilityPercent).padLeft(3)}'
      '  ${UnitMath.speed(point.windKmh, units)}';

  /// Formats the daily forecast, one line per day.
  static String formatDaily(WeatherReport report, WeatherUnits units) {
    if (report.daily.isEmpty) return 'No forecast data available.';

    return <String>[
      '${report.daily.length}-day forecast',
      for (final day in report.daily) _dayLine(day, units),
    ].join('\n');
  }

  static String _dayLine(DailyPoint day, WeatherUnits units) {
    final low = UnitMath.temperature(day.minC, units).padLeft(7);
    final high = UnitMath.temperature(day.maxC, units).padLeft(7);
    final chance = rainChance(day.precipProbabilityPercent).padLeft(3);
    final wind = UnitMath.speed(day.windMaxKmh, units);
    return '${dayLabel(day.date)}  $low–$high  ${WeatherCode.icon(day.code)}'
        ' $chance  wind $wind  ${WeatherCode.describe(day.code)}';
  }

  /// Formats the best-days ranking.
  static String formatBest(List<DayAdvice> days) {
    if (days.isEmpty) return 'No forecast data to rank.';

    final lines = <String>['Best days outdoors'];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      lines.add(
        '${i + 1}. ${dayLabel(day.date)} (score ${day.score}) — ${day.summary}',
      );
    }

    return lines.join('\n');
  }

  /// Formats the weather-for-your-plans view: open Haft Khan tasks grouped under their due
  /// day's forecast. Days without tasks still show, so gaps are visible.
  static String formatPlan(
    WeatherReport report,
    WeatherUnits units,
    List<({DateOnly due, String title})> tasks,
  ) {
    if (report.daily.isEmpty) return 'No forecast data available.';

    final lines = <String>['Weather for your plans'];
    for (final day in report.daily) {
      final due = tasks.where((task) => task.due == day.date).toList();
      final low = UnitMath.temperature(day.minC, units);
      final high = UnitMath.temperature(day.maxC, units);
      final chance = rainChance(day.precipProbabilityPercent);
      lines.add(
        '${dayLabel(day.date)}  ${WeatherCode.icon(day.code)} $low–$high'
        '  $chance rain${AnahitaInsights.adviceFor(day)}',
      );
      for (final task in due) {
        lines.add('    · ${task.title}');
      }
      if (due.isEmpty) {
        lines.add('    · (nothing due)');
      }
    }

    return lines.join('\n');
  }

  /// `52.52°N, 13.41°E` — the coordinate form the CLI showed next to a place name.
  static String coordinates(GeoPlace place) {
    final latitude = UnitMath.twoDigits(place.latitude.abs());
    final longitude = UnitMath.twoDigits(place.longitude.abs());
    final northSouth = place.latitude < 0 ? 'S' : 'N';
    final eastWest = place.longitude < 0 ? 'W' : 'E';
    return '$latitude°$northSouth, $longitude°$eastWest';
  }

  /// `—` when the API omitted rain chance, `42%` otherwise.
  static String rainChance(double? percent) =>
      percent == null ? '—' : '${percent.round()}%';

  /// Millimetres, or inches in imperial.
  static String precipitation(double mm, WeatherUnits units) =>
      units == WeatherUnits.imperial
      ? '${UnitMath.twoDigits(mm / _millimetresPerInch)} in'
      : '${UnitMath.format(mm)} mm';
}
