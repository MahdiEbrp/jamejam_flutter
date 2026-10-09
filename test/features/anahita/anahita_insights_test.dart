// Parity port of tests/JameJam.Tests/Anahita/AnahitaInsightsTests.cs (23 cases).
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/anahita/anahita_defaults.dart';
import 'package:jamejam/features/anahita/anahita_insights.dart';
import 'package:jamejam/features/anahita/models.dart';

import 'anahita_fixture.dart';

void main() {
  const saturday = DateOnly(2026, 9, 19);
  const sunday = DateOnly(2026, 9, 20);
  const monday = DateOnly(2026, 9, 21);

  List<WeatherAlert> alerts(List<DailyPoint> days) =>
      AnahitaInsights.findAlerts(
        AnahitaFixture.report(days),
        WeatherUnits.metric,
      );

  group('alerts', () {
    test('mild days produce no alerts', () {
      expect(
        alerts([AnahitaFixture.day(saturday), AnahitaFixture.day(sunday)]),
        isEmpty,
      );
    });

    test('heat fires at and above the threshold only', () {
      expect(
        alerts([AnahitaFixture.day(saturday, max: 35.0)]).map((a) => a.title),
        contains('Heat'),
      );
      expect(
        alerts([AnahitaFixture.day(saturday, max: 34.9)]).map((a) => a.title),
        isNot(contains('Heat')),
      );
    });

    test('deep freeze fires below the cold threshold', () {
      final result = alerts([AnahitaFixture.day(saturday, min: -15)]);
      expect(
        result.where(
          (a) =>
              a.title == 'Deep freeze' && a.severity == AlertSeverity.warning,
        ),
        hasLength(1),
      );
      expect(result.map((a) => a.title), isNot(contains('Frost')));
    });

    test('frost is a watch between frost and cold', () {
      final result = alerts([AnahitaFixture.day(saturday, min: -5)]);
      expect(result.map((a) => a.title), isNot(contains('Deep freeze')));
      expect(
        result.where(
          (a) => a.title == 'Frost' && a.severity == AlertSeverity.watch,
        ),
        hasLength(1),
      );
    });

    test('strong wind, heavy rain, and thunder are warnings', () {
      final result = alerts([
        AnahitaFixture.day(saturday, code: 95, wind: 61, sum: 26),
      ]);
      final titles = result.map((a) => a.title);
      expect(titles, contains('Strong wind'));
      expect(titles, contains('Heavy rain'));
      expect(titles, contains('Thunderstorms'));
      expect(result.every((a) => a.severity == AlertSeverity.warning), isTrue);
    });

    test('high UV is a watch, and a missing UV value is silent', () {
      expect(
        alerts([AnahitaFixture.day(saturday, uv: 8)]).map((a) => a.title),
        contains('High UV'),
      );
      expect(
        alerts([AnahitaFixture.day(saturday, uv: null)]).map((a) => a.title),
        isNot(contains('High UV')),
      );
    });

    test('alerts obey the two-day horizon', () {
      expect(
        alerts([
          AnahitaFixture.day(saturday),
          AnahitaFixture.day(sunday),
          AnahitaFixture.day(monday, max: 40),
        ]),
        isEmpty,
      );
    });

    test('warnings sort before watches', () {
      // heat (warning) + UV (watch) on the same day
      final result = alerts([AnahitaFixture.day(saturday, max: 36, uv: 9)]);
      expect(result.first.severity, AlertSeverity.warning);
      expect(result.last.severity, AlertSeverity.watch);
    });

    test('alert messages react to units', () {
      final result = AnahitaInsights.findAlerts(
        AnahitaFixture.report([AnahitaFixture.day(saturday, max: 35.2)]),
        WeatherUnits.imperial,
      );
      expect(result, hasLength(1));
      expect(result.single.message, contains('95.4°F'));
    });
  });

  group('scoring', () {
    test('perfect conditions score full', () {
      final day = AnahitaFixture.day(
        saturday,
        min: 20,
        max: 24,
        chance: 0,
        sum: 0,
        wind: 10,
        uv: 3,
      );
      expect(AnahitaInsights.scoreDay(day), AnahitaDefaults.perfectScore);
    });

    test('the rain-chance penalty is proportional and clamped', () {
      int score(double chance) => AnahitaInsights.scoreDay(
        AnahitaFixture.day(
          saturday,
          min: 20,
          max: 24,
          chance: chance,
          sum: 0,
          wind: 10,
        ),
      );

      expect(score(0), 100); // 0% → no penalty
      expect(score(25), 80); // 25% → penalty 20
      expect(score(50), 60); // at rainAdvicePercent → the full 40
      expect(score(100), 60); // clamped at the max penalty
    });

    test('a missing rain chance falls back to the precipitation sum', () {
      final day = AnahitaFixture.day(
        saturday,
        min: 20,
        max: 24,
        chance: null,
        sum: 5,
        wind: 10,
      );
      expect(AnahitaInsights.scoreDay(day), 80);
    });

    test('heat, cold, wind, and thunder all subtract', () {
      // mean 35 → comfort 26; wind 70 → 25; thunder → 60; mean -9 → comfort 62.
      final scorcher = AnahitaFixture.day(
        saturday,
        min: 30,
        max: 40,
        chance: 0,
        wind: 10,
      );
      final freezing = AnahitaFixture.day(
        saturday,
        min: -12,
        max: -6,
        chance: 0,
        wind: 10,
      );
      final gale = AnahitaFixture.day(
        saturday,
        min: 20,
        max: 24,
        chance: 0,
        wind: 70,
      );
      final storm = AnahitaFixture.day(
        saturday,
        min: 20,
        max: 24,
        chance: 0,
        wind: 10,
        code: 95,
      );
      final miserable = AnahitaFixture.day(
        saturday,
        min: -12,
        max: -6,
        chance: 100,
        wind: 70,
        code: 95,
      );

      expect(AnahitaInsights.scoreDay(scorcher), 74);
      expect(AnahitaInsights.scoreDay(freezing), 38);
      expect(AnahitaInsights.scoreDay(gale), 75);
      expect(AnahitaInsights.scoreDay(storm), 40);
      expect(AnahitaInsights.scoreDay(miserable), 0); // clamped at zero
    });
  });

  group('ranking', () {
    test('orders by score then date, and respects the count', () {
      final report = AnahitaFixture.report([
        AnahitaFixture.day(saturday, min: 20, max: 24, chance: 90), // 60
        AnahitaFixture.day(sunday, min: 20, max: 24, chance: 0), // 100
        AnahitaFixture.day(monday, min: 20, max: 24, chance: 10), // 92
      ]);

      final ranked = AnahitaInsights.rankDays(report, WeatherUnits.metric, 2);

      expect(ranked, hasLength(2));
      expect(ranked[0].date, sunday);
      expect(ranked[1].date, monday);
      expect(ranked[0].score, 100);
    });

    test('a negative count is refused', () {
      expect(
        () => AnahitaInsights.rankDays(
          AnahitaFixture.report([AnahitaFixture.day(saturday)]),
          WeatherUnits.metric,
          -1,
        ),
        throwsRangeError,
      );
    });
  });

  group('advice', () {
    test('summaries describe the day and react to units', () {
      final day = AnahitaFixture.day(
        saturday,
        code: 61,
        min: 12.5,
        max: 19.2,
        chance: 80,
      );
      final metric = AnahitaInsights.summarize(day, WeatherUnits.metric);
      expect(metric, contains('Light rain'));
      expect(metric, contains('12.5°C–19.2°C'));
      expect(metric, contains('umbrella'));
      expect(
        AnahitaInsights.summarize(day, WeatherUnits.imperial),
        contains('°F'),
      );
    });

    test('each condition gets its own sentence', () {
      String advice(DailyPoint day) => AnahitaInsights.adviceFor(day);

      expect(
        advice(AnahitaFixture.day(saturday, code: 95)),
        contains('thunderstorms likely'),
      );
      expect(
        advice(AnahitaFixture.day(saturday, code: 61, chance: 80)),
        contains('umbrella'),
      );
      expect(
        advice(AnahitaFixture.day(saturday, chance: null, sum: 5)),
        contains('umbrella'),
      );
      expect(
        advice(AnahitaFixture.day(saturday, max: 36)),
        contains('very hot'),
      );
      expect(
        advice(AnahitaFixture.day(saturday, min: -4, max: 4)),
        contains('freezing'),
      );
      expect(advice(AnahitaFixture.day(saturday, wind: 75)), contains('windy'));
      expect(
        advice(
          AnahitaFixture.day(
            saturday,
            min: 20,
            max: 24,
            chance: 0,
            sum: 0,
            wind: 10,
          ),
        ),
        contains('good conditions to be outside'),
      );
    });
  });
}
