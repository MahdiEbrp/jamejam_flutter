// Parity port of tests/JameJam.Tests/Anahita/AnahitaModelCoverageTests.cs: exhaustive WMO
// table coverage plus the model's value semantics. C# records give equality, hashing,
// cloning and deconstruction for free; the Dart models spell those out, so the assertions
// below check the same behaviour field by field (`copyWith` stands in for `with { }`).
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/anahita/models.dart';
import 'package:jamejam/features/anahita/weather_code.dart';

import 'anahita_fixture.dart';

void main() {
  const saturday = DateOnly(2026, 9, 19);

  group('WeatherCode.describe covers the whole WMO table', () {
    const table = <int, String>{
      0: 'Clear sky',
      1: 'Mainly clear',
      2: 'Partly cloudy',
      3: 'Overcast',
      45: 'Fog',
      48: 'Rime fog',
      51: 'Light drizzle',
      53: 'Drizzle',
      55: 'Dense drizzle',
      56: 'Freezing drizzle',
      57: 'Dense freezing drizzle',
      61: 'Light rain',
      63: 'Rain',
      65: 'Heavy rain',
      66: 'Freezing rain',
      67: 'Heavy freezing rain',
      71: 'Light snow',
      73: 'Snow',
      75: 'Heavy snow',
      77: 'Snow grains',
      80: 'Light showers',
      81: 'Showers',
      82: 'Violent showers',
      85: 'Snow showers',
      86: 'Heavy snow showers',
      95: 'Thunderstorm',
      96: 'Thunderstorm with hail',
      99: 'Severe thunderstorm with hail',
    };

    for (final entry in table.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(WeatherCode.describe(entry.key), entry.value);
      });
    }

    test('an unknown code is labelled, not blank', () {
      expect(WeatherCode.describe(50), 'Unrecognized weather code');
      expect(WeatherCode.describe(-1), 'Unrecognized weather code');
    });
  });

  group('WeatherCode.icon maps the condition family', () {
    const icons = <int, String>{
      0: '☀',
      1: '☀',
      2: '☁',
      3: '☁',
      45: '☁',
      48: '☁',
      51: '☂',
      57: '☂',
      61: '☂',
      67: '☂',
      71: '❆',
      77: '❆',
      80: '☂',
      82: '☂',
      85: '❆',
      86: '❆',
      95: '⚡',
      99: '⚡',
      50: '·', // unmapped → neutral dot
    };

    for (final entry in icons.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(WeatherCode.icon(entry.key), entry.value);
      });
    }
  });

  test('thunderstorms span their whole family', () {
    for (final code in const [95, 96, 97, 98, 99]) {
      expect(WeatherCode.isThunderstorm(code), isTrue, reason: 'code $code');
    }
    for (final code in const [0, 2, 61, 71, 82, 86, 94, 100]) {
      expect(WeatherCode.isThunderstorm(code), isFalse, reason: 'code $code');
    }
  });

  group('GeoPlace.displayName', () {
    test('composes name, admin, and country', () {
      const full = GeoPlace(
        name: 'Berlin',
        country: 'Germany',
        latitude: 52.52,
        longitude: 13.41,
        timezone: 'Europe/Berlin',
        admin1: 'State of Berlin',
      );
      expect(full.displayName, 'Berlin, State of Berlin, Germany');
    });

    test('omits a missing admin', () {
      const noAdmin = GeoPlace(
        name: 'Berlin',
        country: 'Germany',
        latitude: 52.52,
        longitude: 13.41,
        timezone: 'Europe/Berlin',
      );
      expect(noAdmin.displayName, 'Berlin, Germany');
    });

    test('omits an admin that repeats the name, case-insensitively', () {
      const adminEqualsName = GeoPlace(
        name: 'Berlin',
        country: 'Germany',
        latitude: 52.52,
        longitude: 13.41,
        timezone: 'Europe/Berlin',
        admin1: 'berlin',
      );
      expect(adminEqualsName.displayName, 'Berlin, Germany');
    });

    test('handles a raw coordinate label with no country', () {
      const noCountry = GeoPlace(
        name: '52.52, 13.41',
        country: '',
        latitude: 52.52,
        longitude: 13.41,
        timezone: 'auto',
      );
      expect(noCountry.displayName, '52.52, 13.41');
    });

    test('keeps an admin when there is no country', () {
      const adminOnly = GeoPlace(
        name: 'Nowhere',
        country: '',
        latitude: 1,
        longitude: 2,
        timezone: 'auto',
        admin1: 'Somewhere',
      );
      expect(adminOnly.displayName, 'Nowhere, Somewhere');
    });
  });

  group('value semantics', () {
    test(
      'an HourlyPoint equal to its copy, and unequal when a field moves',
      () {
        final hour = HourlyPoint(
          localTime: DateTime(2026, 9, 19, 14, 0),
          temperatureC: 18.4,
          apparentC: 17.9,
          precipProbabilityPercent: 10,
          precipMm: 0,
          code: 2,
          windKmh: 12.4,
          humidityPercent: 62,
        );
        final same = HourlyPoint(
          localTime: hour.localTime,
          temperatureC: hour.temperatureC,
          apparentC: hour.apparentC,
          precipProbabilityPercent: hour.precipProbabilityPercent,
          precipMm: hour.precipMm,
          code: hour.code,
          windKmh: hour.windKmh,
          humidityPercent: hour.humidityPercent,
        );
        final different = HourlyPoint(
          localTime: hour.localTime,
          temperatureC: 20,
          apparentC: hour.apparentC,
          precipProbabilityPercent: hour.precipProbabilityPercent,
          precipMm: hour.precipMm,
          code: hour.code,
          windKmh: hour.windKmh,
          humidityPercent: hour.humidityPercent,
        );

        expect(hour, same);
        expect(hour.hashCode, same.hashCode);
        expect(hour, isNot(different));
        expect(hour, isNot(equals(null)));
        expect(hour, isNot(equals('HourlyPoint')));

        // the deconstruction equivalent: every field is readable
        expect(hour.temperatureC, 18.4);
        expect(hour.precipProbabilityPercent, 10);
        expect(hour.code, 2);
      },
    );

    test('CurrentConditions compares by value', () {
      final conditions = CurrentConditions(
        localTime: DateTime(2026, 9, 19, 14),
        temperatureC: 18.4,
        apparentC: 17.9,
        humidityPercent: 62,
        precipMm: 0.4,
        code: 2,
        windKmh: 12.4,
        windDirectionDeg: 315,
      );
      final same = CurrentConditions(
        localTime: conditions.localTime,
        temperatureC: conditions.temperatureC,
        apparentC: conditions.apparentC,
        humidityPercent: conditions.humidityPercent,
        precipMm: conditions.precipMm,
        code: conditions.code,
        windKmh: conditions.windKmh,
        windDirectionDeg: conditions.windDirectionDeg,
      );

      expect(conditions, same);
      expect(conditions.hashCode, same.hashCode);
      expect(
        conditions,
        isNot(
          CurrentConditions(
            localTime: conditions.localTime,
            temperatureC: conditions.temperatureC,
            apparentC: conditions.apparentC,
            humidityPercent: conditions.humidityPercent,
            precipMm: conditions.precipMm,
            code: 3,
            windKmh: conditions.windKmh,
            windDirectionDeg: conditions.windDirectionDeg,
          ),
        ),
      );
    });

    test('WeatherReport compares by value, list contents included', () {
      final report = AnahitaFixture.report([AnahitaFixture.day(saturday)]);
      final rebuilt = AnahitaFixture.report([AnahitaFixture.day(saturday)]);
      // same numbers, different place
      final elsewhere = WeatherReport(
        place: report.place.copyWith(timezone: 'UTC'),
        fetchedAt: report.fetchedAt,
        current: report.current,
        hourly: report.hourly,
        daily: report.daily,
      );

      expect(report, rebuilt);
      expect(report.hashCode, rebuilt.hashCode);
      expect(
        report,
        isNot(AnahitaFixture.report([AnahitaFixture.day(saturday, max: 25)])),
      );
      expect(report, isNot(elsewhere)); // the place differs
      expect(report.daily, hasLength(1));
      expect(report.hourly, hasLength(2));
    });

    test('GeoPlace.copyWith keeps the other fields', () {
      final berlin = AnahitaFixture.berlin();

      expect(berlin.copyWith(timezone: 'UTC').timezone, 'UTC');
      expect(berlin.copyWith(timezone: 'UTC').name, berlin.name);
      expect(berlin.copyWith(timezone: 'UTC').population, berlin.population);
      expect(berlin.copyWith(), berlin);
    });

    test('records render readable diagnostics', () {
      final report = AnahitaFixture.report([AnahitaFixture.day(saturday)]);

      expect(report.toString(), contains('WeatherReport'));
      expect(report.toString(), contains('Berlin'));
      expect(report.current.toString(), contains('CurrentConditions'));
      expect(report.hourly.first.toString(), contains('HourlyPoint'));
      expect(report.daily.first.toString(), contains('DailyPoint'));
      expect(report.place.toString(), contains('GeoPlace'));
    });
  });
}
