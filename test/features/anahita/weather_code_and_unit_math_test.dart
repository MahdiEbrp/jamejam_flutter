// Parity port of tests/JameJam.Tests/Anahita/WeatherCodeAndUnitMathTests.cs.
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/anahita/models.dart';
import 'package:jamejam/features/anahita/unit_math.dart';
import 'package:jamejam/features/anahita/weather_code.dart';

void main() {
  group('WeatherCode', () {
    test('describes the codes the API actually sends', () {
      const expected = {
        0: 'Clear sky',
        1: 'Mainly clear',
        2: 'Partly cloudy',
        3: 'Overcast',
        45: 'Fog',
        61: 'Light rain',
        65: 'Heavy rain',
        71: 'Light snow',
        80: 'Light showers',
        95: 'Thunderstorm',
        99: 'Severe thunderstorm with hail',
      };
      for (final entry in expected.entries) {
        expect(
          WeatherCode.describe(entry.key),
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    test('gives unknown codes a name rather than throwing', () {
      expect(WeatherCode.describe(-5), 'Unrecognized weather code');
      expect(WeatherCode.describe(100), 'Unrecognized weather code');
    });

    test('every described code has an icon', () {
      for (final code in const [0, 1, 2, 3, 45, 61, 71, 95]) {
        expect(WeatherCode.icon(code), isNotEmpty);
      }
    });

    test('the thunderstorm range is exactly 95–99', () {
      expect(WeatherCode.isThunderstorm(94), isFalse);
      expect(WeatherCode.isThunderstorm(95), isTrue);
      expect(WeatherCode.isThunderstorm(99), isTrue);
      expect(WeatherCode.isThunderstorm(100), isFalse);
    });
  });

  group('UnitMath', () {
    test('converts Celsius to Fahrenheit', () {
      expect(UnitMath.fahrenheitFromCelsius(0), 32);
      expect(UnitMath.fahrenheitFromCelsius(100), 212);
      expect(UnitMath.fahrenheitFromCelsius(-40), -40);
      expect(UnitMath.fahrenheitFromCelsius(36.6), closeTo(97.88, 1e-9));
    });

    test('converts km/h to mph', () {
      expect(UnitMath.mphFromKmh(100), closeTo(62.1371192237334, 1e-9));
      expect(UnitMath.mphFromKmh(0), 0);
    });

    test('converts km/h to m/s and knots', () {
      expect(UnitMath.metresPerSecondFromKmh(36), closeTo(10, 1e-9));
      expect(UnitMath.knotsFromKmh(18.52), closeTo(10, 1e-9));
    });

    test('formats temperatures the way the CLI printed them', () {
      expect(UnitMath.temperature(18.4, WeatherUnits.metric), '18.4°C');
      expect(UnitMath.temperature(18.4, WeatherUnits.imperial), '65.1°F');
      expect(UnitMath.temperature(20, WeatherUnits.metric), '20°C');
    });

    test('formats speeds the way the CLI printed them', () {
      expect(UnitMath.speed(12.4, WeatherUnits.metric), '12.4 km/h');
      expect(UnitMath.speed(12.4, WeatherUnits.imperial), '7.7 mph');
      expect(UnitMath.speed(60, WeatherUnits.metric), '60 km/h');
    });
  });

  group('WeatherUnits', () {
    test('accepts the CLI spellings', () {
      expect(WeatherUnits.parse(null), WeatherUnits.metric);
      expect(WeatherUnits.parse(''), WeatherUnits.metric);
      expect(WeatherUnits.parse('metric'), WeatherUnits.metric);
      expect(WeatherUnits.parse('c'), WeatherUnits.metric);
      expect(WeatherUnits.parse('celsius'), WeatherUnits.metric);
      expect(WeatherUnits.parse('IMPERIAL'), WeatherUnits.imperial);
      expect(WeatherUnits.parse('f'), WeatherUnits.imperial);
      expect(WeatherUnits.parse('fahrenheit'), WeatherUnits.imperial);
    });

    test('rejects anything else with the CLI wording', () {
      expect(
        () => WeatherUnits.parse('kelvin'),
        throwsA(
          isA<AnahitaException>().having(
            (error) => error.message,
            'message',
            contains("Unknown units 'kelvin'"),
          ),
        ),
      );
    });
  });
}
