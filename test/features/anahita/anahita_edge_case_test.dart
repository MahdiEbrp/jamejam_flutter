// Parity port of tests/JameJam.Tests/Anahita/AnahitaEdgeCaseTests.cs. The CLI-only rail
// (`FlagWithoutValue_BecomesAnUnknownOption`, "null dependencies") has no analogue here —
// the Dart types are non-nullable and there is no flag parser — so those cases are noted in
// docs/TEST_PARITY.md rather than faked.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/anahita/anahita_defaults.dart';
import 'package:jamejam/features/anahita/anahita_format.dart';
import 'package:jamejam/features/anahita/anahita_insights.dart';
import 'package:jamejam/features/anahita/anahita_options.dart';
import 'package:jamejam/features/anahita/anahita_service.dart';
import 'package:jamejam/features/anahita/models.dart';
import 'package:jamejam/features/anahita/open_meteo_client.dart';

import 'anahita_fixture.dart';
import 'anahita_service_test.dart' show StubAnahitaClient;

void main() {
  const saturday = DateOnly(2026, 9, 19);

  AnahitaOptions options({String? apiKey, int maxRetries = 0}) =>
      AnahitaOptions(
        forecastEndpoint: 'https://weather.test/v1/forecast',
        geocodingEndpoint: 'https://weather.test/search',
        apiKey: apiKey,
        maxRetries: maxRetries,
        retryBaseDelay: const Duration(milliseconds: 1),
      );

  ({OpenMeteoClient client, List<http.Request> requests}) build(
    Future<http.Response> Function(http.Request request) handler, {
    AnahitaOptions? config,
  }) {
    final requests = <http.Request>[];
    final mock = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    return (
      client: OpenMeteoClient(httpClient: mock, options: config ?? options()),
      requests: requests,
    );
  }

  String currentOnly({String time = '2026-09-19T14:00'}) => jsonEncode({
    'timezone': 'UTC',
    'current': {
      'time': time,
      'temperature_2m': 1,
      'apparent_temperature': 1,
      'relative_humidity_2m': 1,
      'precipitation': 0,
      'weather_code': 0,
      'wind_speed_10m': 0,
      'wind_direction_10m': 0,
    },
  });

  test('a blank api key sends no authorization header', () async {
    final stub = build(
      (_) async => http.Response(AnahitaFixture.forecastBody(), 200),
      config: options(apiKey: ''),
    );

    await stub.client.getForecast(AnahitaFixture.berlin());

    expect(stub.requests.single.headers.containsKey('authorization'), isFalse);
  });

  test('long error bodies are truncated', () async {
    final stub = build(
      (_) async => http.Response('x' * 900, 404),
      config: options(),
    );

    try {
      await stub.client.getForecast(AnahitaFixture.berlin());
      fail('the request should have thrown');
    } on AnahitaException catch (error) {
      expect(error.message, endsWith('…'));
      expect(error.message, contains('x' * 500));
      expect(error.message, isNot(contains('x' * 501)));
    }
  });

  test('malformed timestamps are friendly errors', () async {
    final stub = build(
      (_) async => http.Response(currentOnly(time: 'not-a-time'), 200),
      config: options(),
    );

    await expectLater(
      stub.client.getForecast(AnahitaFixture.berlin()),
      throwsA(
        isA<AnahitaException>().having(
          (error) => error.message,
          'message',
          contains('unreadable current time'),
        ),
      ),
    );
  });

  test('malformed dates are friendly errors', () async {
    const badDate =
        '{"timezone":"UTC",'
        '"current": {"time": "2026-09-19T14:00", "temperature_2m": 1,'
        '"apparent_temperature": 1, "relative_humidity_2m": 1, "precipitation": 0,'
        '"weather_code": 0, "wind_speed_10m": 0, "wind_direction_10m": 0},'
        '"daily": {"time": ["nope"], "weather_code": [0], "temperature_2m_max": [1],'
        '"temperature_2m_min": [0], "precipitation_sum": [0],'
        '"precipitation_probability_max": [0], "wind_speed_10m_max": [0],'
        '"uv_index_max": [0], "sunrise": ["2026-09-19T06:41"],'
        '"sunset": ["2026-09-19T19:22"]}}';
    final stub = build(
      (_) async => http.Response(badDate, 200),
      config: options(),
    );

    await expectLater(
      stub.client.getForecast(AnahitaFixture.berlin()),
      throwsA(
        isA<AnahitaException>().having(
          (error) => error.message,
          'message',
          contains('unreadable date'),
        ),
      ),
    );
  });

  test('a zero Retry-After skips the delay', () async {
    var calls = 0;
    final stub = build((_) async {
      calls++;
      if (calls == 1) {
        return http.Response('busy', 503, headers: {'retry-after': '0'});
      }
      return http.Response(AnahitaFixture.forecastBody(), 200);
    }, config: options(maxRetries: 2));

    final stopwatch = Stopwatch()..start();
    final report = await stub.client.getForecast(AnahitaFixture.berlin());
    stopwatch.stop();

    expect(report.current.temperatureC, 18.4);
    expect(stub.requests, hasLength(2));
    expect(stopwatch.elapsedMilliseconds, lessThan(500)); // no backoff wait
  });

  test(
    'a whitespace place argument falls through to the saved location',
    () async {
      final client = StubAnahitaClient();
      final service = AnahitaService(
        client: client,
        clock: AnahitaFixture.clock().call,
        options: options(),
        savedLocation: () async => 'Hamburg',
      );

      final report = await service.current(placeArg: '   ');

      expect(client.geocodeNames, ['Hamburg']);
      expect(report.place.name, AnahitaFixture.berlin().name);
    },
  );

  test('a flag-shaped place argument is treated as a place name', () async {
    // there is no flag parser in the Flutter port: whatever is typed is the place
    final client = StubAnahitaClient();
    final service = AnahitaService(
      client: client,
      clock: AnahitaFixture.clock().call,
      options: options(),
    );

    await service.current(placeArg: '--days');

    expect(client.geocodeNames, ['--days']);
  });

  test('the hourly window option drives the rendered window', () {
    final hours = [
      for (var i = 0; i < 10; i++)
        HourlyPoint(
          localTime: DateTime(2026, 9, 19, i),
          temperatureC: 18,
          apparentC: 17,
          precipProbabilityPercent: 10,
          precipMm: 0,
          code: 2,
          windKmh: 12,
          humidityPercent: 60,
        ),
    ];
    final report = AnahitaFixture.report([AnahitaFixture.day(saturday)], hours);

    final text = AnahitaFormat.formatHourly(
      report,
      WeatherUnits.metric,
      const AnahitaOptions(hourlyWindow: 3).hourlyWindow,
    );

    expect(text, contains('Next 3 hour(s)'));
    expect(text, contains('00:00'));
    expect(text, contains('02:00'));
    expect(text, isNot(contains('03:00')));
  });

  test('quiet rain numbers carry no penalty', () {
    final day = AnahitaFixture.day(
      saturday,
      chance: null,
      sum: 0,
      min: 20,
      max: 24,
      wind: 10,
    );

    expect(AnahitaInsights.scoreDay(day), AnahitaDefaults.perfectScore);
  });

  test('formatNow skips the sun line when the sun times are missing', () {
    final day = DailyPoint(
      date: saturday,
      code: 2,
      minC: 12.5,
      maxC: 19.2,
      precipProbabilityPercent: 10,
      precipSumMm: 0.4,
      windMaxKmh: 21.3,
      uvMax: null,
      sunrise: null,
      sunset: null,
    );

    final text = AnahitaFormat.formatNow(
      AnahitaFixture.report([day]),
      WeatherUnits.metric,
    );

    expect(text, isNot(contains('Sunrise')));
  });

  test('unit aliases are accepted, and unknown ones are rejected', () {
    expect(WeatherUnits.parse('metric'), WeatherUnits.metric);
    expect(WeatherUnits.parse('imperial'), WeatherUnits.imperial);
    expect(WeatherUnits.parse('celsius'), WeatherUnits.metric);
    expect(WeatherUnits.parse('fahrenheit'), WeatherUnits.imperial);
    expect(
      WeatherUnits.parse('METRIC '),
      WeatherUnits.metric,
    ); // trimmed, folded
    expect(WeatherUnits.parse(''), WeatherUnits.metric); // the default
    expect(
      () => WeatherUnits.parse('kelvin'),
      throwsA(
        isA<AnahitaException>().having(
          (error) => error.message,
          'message',
          contains('Unknown units'),
        ),
      ),
    );
  });
}
