/// anahita — see doc/anahita.md and AGENTS.md
library;

import 'anahita_defaults.dart';
import 'anahita_format.dart';
import 'models.dart';
import 'unit_math.dart';
import 'weather_code.dart';

abstract final class AnahitaInsights {
  /// Evaluates the next [AnahitaDefaults.alertHorizonDays] forecast days and returns alerts,
  /// most urgent first (warning before watch).
  static List<WeatherAlert> findAlerts(
    WeatherReport report,
    WeatherUnits units,
  ) {
    final horizon = report.daily.take(AnahitaDefaults.alertHorizonDays);
    final alerts = <WeatherAlert>[];

    for (final day in horizon) {
      final label = AnahitaFormat.dayLabel(day.date);

      if (day.maxC >= AnahitaDefaults.heatCelsius) {
        alerts.add(
          WeatherAlert(
            severity: AlertSeverity.warning,
            title: 'Heat',
            message:
                '$label peaks at ${UnitMath.temperature(day.maxC, units)} — '
                'hydrate and stay out of the midday sun.',
          ),
        );
      }

      if (day.minC <= AnahitaDefaults.coldCelsius) {
        alerts.add(
          WeatherAlert(
            severity: AlertSeverity.warning,
            title: 'Deep freeze',
            message:
                '$label falls to ${UnitMath.temperature(day.minC, units)} — '
                'protect skin and pipes.',
          ),
        );
      } else if (day.minC <= AnahitaDefaults.frostCelsius) {
        alerts.add(
          WeatherAlert(
            severity: AlertSeverity.watch,
            title: 'Frost',
            message:
                '$label dips to ${UnitMath.temperature(day.minC, units)} — '
                'frost is likely before morning.',
          ),
        );
      }

      if (day.windMaxKmh >= AnahitaDefaults.strongWindKmh) {
        alerts.add(
          WeatherAlert(
            severity: AlertSeverity.warning,
            title: 'Strong wind',
            message:
                '$label blows up to ${UnitMath.speed(day.windMaxKmh, units)} — '
                'secure loose objects.',
          ),
        );
      }

      if (day.precipSumMm >= AnahitaDefaults.heavyRainMm) {
        alerts.add(
          WeatherAlert(
            severity: AlertSeverity.warning,
            title: 'Heavy rain',
            message:
                '$label may dump ${UnitMath.format(day.precipSumMm)} mm — '
                'expect flooding pockets.',
          ),
        );
      }

      if (WeatherCode.isThunderstorm(day.code)) {
        alerts.add(
          WeatherAlert(
            severity: AlertSeverity.warning,
            title: 'Thunderstorms',
            message:
                '$label brings ${WeatherCode.describe(day.code).toLowerCase()} — '
                'avoid open ground and tall trees.',
          ),
        );
      }

      final uv = day.uvMax;
      if (uv != null && uv >= AnahitaDefaults.highUv) {
        alerts.add(
          WeatherAlert(
            severity: AlertSeverity.watch,
            title: 'High UV',
            message:
                '$label reaches UV ${UnitMath.format(uv)} — sunscreen and a hat.',
          ),
        );
      }
    }

    return List.unmodifiable(
      alerts.toList()
        ..sort((a, b) => b.severity.code.compareTo(a.severity.code)),
    );
  }

  /// Ranks forecast days for outdoor plans; the best day first.
  static List<DayAdvice> rankDays(
    WeatherReport report,
    WeatherUnits units,
    int topCount,
  ) {
    if (topCount < 0) {
      throw RangeError.range(topCount, 0, null, 'topCount');
    }

    final ranked = <DayAdvice>[
      for (final day in report.daily)
        DayAdvice(
          date: day.date,
          score: scoreDay(day),
          summary: summarize(day, units),
        ),
    ];

    return List.unmodifiable(_byScore(ranked).take(topCount));
  }

  /// Score descending, then date ascending — the .NET `OrderByDescending…ThenBy` pair.
  static List<DayAdvice> _byScore(List<DayAdvice> days) => days
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.date.differenceInDays(b.date);
    });

  /// Scores one day for outdoor plans (0–[AnahitaDefaults.perfectScore]): rain chance,
  /// temperature distance from comfort, wind, and thunderstorms subtract.
  static int scoreDay(DailyPoint day) {
    final chance = day.precipProbabilityPercent;
    var rainPenalty = chance != null
        ? (chance /
                  AnahitaDefaults.rainAdvicePercent *
                  AnahitaDefaults.rainPenaltyMax)
              .round()
        : day.precipSumMm >= AnahitaDefaults.rainTraceMm
        ? AnahitaDefaults.rainPenaltyMax ~/ 2
        : 0;
    if (rainPenalty > AnahitaDefaults.rainPenaltyMax) {
      rainPenalty = AnahitaDefaults.rainPenaltyMax;
    }

    final mean = (day.minC + day.maxC) / 2;
    final comfortPenalty =
        ((mean - AnahitaDefaults.comfortCelsius).abs() *
                AnahitaDefaults.temperaturePenaltyPerDegree)
            .toInt();
    final thunderPenalty = WeatherCode.isThunderstorm(day.code)
        ? AnahitaDefaults.thunderPenalty
        : 0;
    final windPenalty = day.windMaxKmh >= AnahitaDefaults.strongWindKmh
        ? AnahitaDefaults.windPenalty
        : 0;

    final score =
        AnahitaDefaults.perfectScore -
        rainPenalty -
        comfortPenalty -
        thunderPenalty -
        windPenalty;
    return score.clamp(0, AnahitaDefaults.perfectScore);
  }

  /// Builds the one-line human summary for a forecast day.
  static String summarize(DailyPoint day, WeatherUnits units) =>
      '${WeatherCode.describe(day.code)}, ${UnitMath.temperature(day.minC, units)}'
      '–${UnitMath.temperature(day.maxC, units)}${adviceFor(day)}';

  /// One actionable sentence for a forecast day.
  static String adviceFor(DailyPoint day) {
    final rainLikely =
        (day.precipProbabilityPercent ?? 0) >=
            AnahitaDefaults.rainAdvicePercent ||
        day.precipSumMm >= AnahitaDefaults.rainTraceMm;

    if (WeatherCode.isThunderstorm(day.code)) {
      return ' — thunderstorms likely, stay near shelter.';
    }
    if (rainLikely) {
      return ' — rain is likely, pack an umbrella.';
    }
    if (day.maxC >= AnahitaDefaults.heatCelsius) {
      return ' — very hot, plan around the midday sun.';
    }
    if (day.minC <= AnahitaDefaults.frostCelsius) {
      return ' — freezing, dress in warm layers.';
    }
    if (day.windMaxKmh >= AnahitaDefaults.strongWindKmh) {
      return ' — very windy, think twice about cycling.';
    }
    return ' — good conditions to be outside.';
  }
}
