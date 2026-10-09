// Parity port of tests/JameJam.Tests/Anahita/AnahitaFormatTests.cs (12 cases).
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/anahita/anahita_format.dart';
import 'package:jamejam/features/anahita/models.dart';

import 'anahita_fixture.dart';

void main() {
  const saturday = DateOnly(2026, 9, 19);
  const sunday = DateOnly(2026, 9, 20);

  WeatherReport report([List<DailyPoint> days = const []]) =>
      AnahitaFixture.report(days);

  test('the now block shows place, conditions, wind, and sun', () {
    final text = AnahitaFormat.formatNow(
      report([AnahitaFixture.day(saturday)]),
      WeatherUnits.metric,
    );

    expect(
      text,
      contains('Berlin, Germany — 52.52°N, 13.41°E · Europe/Berlin'),
    );
    expect(text, contains('Partly cloudy'));
    expect(text, contains('18.4°C (feels 17.9°C)'));
    expect(text, contains('humidity 62%'));
    expect(text, contains('Wind 12.4 km/h NW')); // 315°
    expect(text, contains('Sunrise 06:41 · Sunset 19:22 · UV max 4.2'));
  });

  test('the now block handles imperial units and southern coordinates', () {
    final place = const GeoPlace(
      name: 'Puerto Williams',
      country: 'Chile',
      latitude: -54.93,
      longitude: -67.61,
      timezone: 'America/Punta_Arenas',
    );
    final base = report();
    final southern = WeatherReport(
      place: place,
      fetchedAt: base.fetchedAt,
      current: base.current,
      hourly: base.hourly,
      daily: base.daily,
    );
    final text = AnahitaFormat.formatNow(southern, WeatherUnits.imperial);

    expect(text, contains('54.93°S, 67.61°W'));
    expect(text, contains('65.1°F'));
    expect(text, contains('mph'));
  });

  test('the compass covers the whole rose', () {
    expect(AnahitaFormat.compass(0), 'N');
    expect(AnahitaFormat.compass(22), 'NNE');
    expect(AnahitaFormat.compass(90), 'E');
    expect(AnahitaFormat.compass(225), 'SW');
    expect(AnahitaFormat.compass(337), 'NNW');
    expect(AnahitaFormat.compass(359), 'N'); // wraps
  });

  test('alerts render as nothing when calm, and with severity when not', () {
    expect(AnahitaFormat.formatAlerts(const []), '');

    const alerts = [
      WeatherAlert(
        severity: AlertSeverity.warning,
        title: 'Heat',
        message: 'peaks today',
      ),
      WeatherAlert(
        severity: AlertSeverity.watch,
        title: 'High UV',
        message: 'sunscreen time',
      ),
    ];
    final text = AnahitaFormat.formatAlerts(alerts);

    expect(text, startsWith('Alerts'));
    expect(text, contains('⚠ Heat — peaks today'));
    expect(text, contains('☑ High UV — sunscreen time'));
  });

  test('the hourly table slices, and a missing chance shows a dash', () {
    final base = report();
    final one = AnahitaFormat.formatHourly(base, WeatherUnits.metric, 1);

    expect(one, contains('Next 1 hour(s)'));
    expect(one, contains('14:00'));
    expect(one, isNot(contains('15:00')));

    final withNullChance = WeatherReport(
      place: base.place,
      fetchedAt: base.fetchedAt,
      current: base.current,
      hourly: [
        base.hourly[0],
        HourlyPoint(
          localTime: base.hourly[1].localTime,
          temperatureC: base.hourly[1].temperatureC,
          apparentC: base.hourly[1].apparentC,
          precipProbabilityPercent: null,
          precipMm: base.hourly[1].precipMm,
          code: base.hourly[1].code,
          windKmh: base.hourly[1].windKmh,
          humidityPercent: base.hourly[1].humidityPercent,
        ),
      ],
      daily: base.daily,
    );
    final both = AnahitaFormat.formatHourly(
      withNullChance,
      WeatherUnits.metric,
      5,
    );
    expect(both, contains('15:00'));
    expect(both, contains('—'));
  });

  test('empty hourly data is a sentence, not a crash', () {
    final empty = AnahitaFixture.report(const [], const []);
    expect(
      AnahitaFormat.formatHourly(empty, WeatherUnits.metric, 4),
      'No hourly data available.',
    );
  });

  test('the daily table lists every day', () {
    final text = AnahitaFormat.formatDaily(
      report([
        AnahitaFixture.day(saturday),
        AnahitaFixture.day(sunday, code: 61),
      ]),
      WeatherUnits.metric,
    );

    expect(text, startsWith('2-day forecast'));
    expect(text, contains('Sat 19 Sep'));
    expect(text, contains('Sun 20 Sep'));
    expect(text, contains('Light rain'));
  });

  test('empty forecast data is a sentence, not a crash', () {
    expect(
      AnahitaFormat.formatDaily(report(), WeatherUnits.metric),
      'No forecast data available.',
    );
  });

  test('the best-days list ranks with scores', () {
    const days = [
      DayAdvice(
        date: sunday,
        score: 92,
        summary: 'Clear sky, 20°C–24°C — good conditions to be outside.',
      ),
      DayAdvice(
        date: saturday,
        score: 60,
        summary: 'Overcast, 12.5°C–19.2°C — rain is likely, pack an umbrella.',
      ),
    ];
    final text = AnahitaFormat.formatBest(days);

    expect(text, startsWith('Best days outdoors'));
    expect(text, contains('1. Sun 20 Sep (score 92)'));
    expect(text, contains('2. Sat 19 Sep (score 60)'));
    expect(AnahitaFormat.formatBest(const []), 'No forecast data to rank.');
  });

  test('the plan view groups tasks under their day and shows gaps', () {
    final text = AnahitaFormat.formatPlan(
      report([
        AnahitaFixture.day(saturday),
        AnahitaFixture.day(sunday),
        AnahitaFixture.day(const DateOnly(2026, 9, 21)),
      ]),
      WeatherUnits.metric,
      const [
        (due: saturday, title: 'Water the garden'),
        (due: saturday, title: 'Fix the roof'),
        (due: sunday, title: 'Climb Damavand'),
      ],
    );

    expect(text, startsWith('Weather for your plans'));
    expect(text, contains('· Water the garden'));
    expect(text, contains('· Fix the roof'));
    expect(text, contains('· Climb Damavand'));

    final saturdayBlock = text.split('Sun 20 Sep').first;
    expect(saturdayBlock, contains('Fix the roof'));
    expect(saturdayBlock, isNot(contains('Climb Damavand')));
    expect(text, contains('(nothing due)'));
  });

  test('an empty forecast makes the plan view friendly', () {
    expect(
      AnahitaFormat.formatPlan(report(), WeatherUnits.metric, const []),
      'No forecast data available.',
    );
  });
}
