// Parity port of tests/JameJam.Tests/Anahita/OpenMeteoClientTests.cs (17 cases), driven through
// `MockClient` instead of a stubbed HttpMessageHandler — same transport policy, same payloads.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/anahita/anahita_defaults.dart';
import 'package:jamejam/features/anahita/anahita_options.dart';
import 'package:jamejam/features/anahita/models.dart';
import 'package:jamejam/features/anahita/open_meteo_client.dart';

import 'anahita_fixture.dart';

void main() {
  AnahitaOptions options({
    String forecast = 'https://weather.test/v1/forecast',
    String geocoding = 'https://weather.test/search',
    String? apiKey,
  }) => AnahitaOptions(
    forecastEndpoint: forecast,
    geocodingEndpoint: geocoding,
    apiKey: apiKey,
    retryBaseDelay: const Duration(milliseconds: 1),
  );

  /// Records every request and answers with the supplied handler.
  ({OpenMeteoClient client, List<http.Request> requests}) build(
    Future<http.Response> Function(http.Request request) handler,
    AnahitaOptions config,
  ) {
    final requests = <http.Request>[];
    final mock = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    return (
      client: OpenMeteoClient(httpClient: mock, options: config),
      requests: requests,
    );
  }

  Map<String, dynamic> misaligned() =>
      jsonDecode('''
{
  "timezone": "UTC",
  "current": {"time": "2026-09-19T14:00", "temperature_2m": 18.4, "apparent_temperature": 17.9,
              "relative_humidity_2m": 62, "precipitation": 0.4, "weather_code": 2,
              "wind_speed_10m": 12.4, "wind_direction_10m": 315},
  "hourly": {"time": ["2026-09-19T14:00", "2026-09-19T15:00"], "temperature_2m": [18.4]}
}
''')
          as Map<String, dynamic>;

  group('forecast', () {
    test('parses the full payload', () async {
      final stub = build(
        (_) async => http.Response(AnahitaFixture.forecastBody(), 200),
        options(),
      );

      final report = await stub.client.getForecast(AnahitaFixture.berlin());

      expect(report.place.timezone, 'Europe/Berlin'); // API-resolved
      expect(report.current.temperatureC, 18.4);
      expect(report.current.humidityPercent, 62);
      expect(report.current.windDirectionDeg, 315);
      expect(report.hourly, hasLength(2));
      expect(
        report.hourly[1].precipProbabilityPercent,
        isNull,
      ); // API null preserved
      expect(report.daily, hasLength(2));
      expect(report.daily[1].date, const DateOnly(2026, 9, 20));
      expect(report.daily[1].sunrise, const TimeOfDayValue(6, 43));
      expect(report.daily[1].uvMax, isNull);
      expect(report.daily[1].precipProbabilityPercent, 80);
    });

    test('builds the expected query', () async {
      final stub = build(
        (_) async => http.Response(AnahitaFixture.forecastBody(), 200),
        options().copyWith(forecastDays: 5),
      );

      await stub.client.getForecast(AnahitaFixture.berlin());

      final url = stub.requests.single.url.toString();
      expect(url, contains('latitude=52.52'));
      expect(url, contains('longitude=13.41'));
      expect(url, contains('forecast_days=5'));
      expect(url, contains('timezone=auto'));
      expect(url, contains('temperature_2m_max'));
    });

    test('sends the bearer key when configured', () async {
      final stub = build(
        (_) async => http.Response(AnahitaFixture.forecastBody(), 200),
        options(apiKey: 'mirror-key-1'),
      );

      await stub.client.getForecast(AnahitaFixture.berlin());

      expect(
        stub.requests.single.headers['authorization'],
        'Bearer mirror-key-1',
      );
    });

    test('retries transient failures, then succeeds', () async {
      var calls = 0;
      final stub = build((_) async {
        calls++;
        return calls == 1
            ? http.Response('busy', 503)
            : http.Response(AnahitaFixture.forecastBody(), 200);
      }, options());

      final report = await stub.client.getForecast(AnahitaFixture.berlin());

      expect(report.current.temperatureC, 18.4);
      expect(stub.requests, hasLength(2));
    });

    test('rejects oversized responses', () async {
      final stub = build(
        (_) async => http.Response(jsonEncode({'big': 'x' * 5000}), 200),
        options().copyWith(maxResponseBytes: 1000),
      );

      await expectLater(
        stub.client.getForecast(AnahitaFixture.berlin()),
        throwsA(
          isA<AnahitaException>().having(
            (error) => error.message,
            'message',
            contains('exceeds the configured maximum'),
          ),
        ),
      );
    });

    test('scrubs the key from error bodies', () async {
      final stub = build(
        (_) async => http.Response('{"error":"bad key mirror-key-1"}', 401),
        options(apiKey: 'mirror-key-1'),
      );

      try {
        await stub.client.getForecast(AnahitaFixture.berlin());
        fail('the request should have thrown');
      } on AnahitaException catch (error) {
        expect(error.message, contains('****'));
        expect(error.message, isNot(contains('mirror-key-1')));
        expect(error.statusCode, 401);
      }
    });

    test('a 404 is a friendly error, not null', () async {
      final stub = build((_) async => http.Response('{}', 404), options());

      await expectLater(
        stub.client.getForecast(AnahitaFixture.berlin()),
        throwsA(
          isA<AnahitaException>().having(
            (error) => error.message,
            'message',
            contains('404'),
          ),
        ),
      );
    });

    test('a payload without current conditions is a friendly error', () async {
      final stub = build(
        (_) async => http.Response('{"timezone":"UTC"}', 200),
        options(),
      );

      await expectLater(
        stub.client.getForecast(AnahitaFixture.berlin()),
        throwsA(
          isA<AnahitaException>().having(
            (error) => error.message,
            'message',
            contains('no current conditions'),
          ),
        ),
      );
    });

    test('misaligned arrays are a friendly error', () async {
      final stub = build(
        (_) async => http.Response(jsonEncode(misaligned()), 200),
        options(),
      );

      await expectLater(
        stub.client.getForecast(AnahitaFixture.berlin()),
        throwsA(
          isA<AnahitaException>().having(
            (error) => error.message,
            'message',
            contains('inconsistent data'),
          ),
        ),
      );
    });

    test('invalid JSON is a friendly error', () async {
      final stub = build(
        (_) async => http.Response('{"broken":[1,2', 200),
        options(),
      );

      await expectLater(
        stub.client.getForecast(AnahitaFixture.berlin()),
        throwsA(
          isA<AnahitaException>().having(
            (error) => error.message,
            'message',
            contains('did not return a valid Anahita weather response'),
          ),
        ),
      );
    });

    test('times out after all attempts', () async {
      var calls = 0;
      final stub = build(
        (_) async {
          calls++;
          await Future<void>.delayed(const Duration(seconds: 5));
          return http.Response('late', 200);
        },
        options().copyWith(
          requestTimeout: const Duration(milliseconds: 50),
          maxRetries: 1,
        ),
      );

      await expectLater(
        stub.client.getForecast(AnahitaFixture.berlin()),
        throwsA(
          isA<AnahitaException>().having(
            (error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
      expect(calls, 2);
    });

    test('network failures are retried, then surfaced', () async {
      final stub = build(
        (_) async => throw http.ClientException('connection refused'),
        options().copyWith(maxRetries: 1),
      );

      await expectLater(
        stub.client.getForecast(AnahitaFixture.berlin()),
        throwsA(
          isA<AnahitaException>().having(
            (error) => error.message,
            'message',
            contains('Network error'),
          ),
        ),
      );
      expect(stub.requests, hasLength(2));
    });

    test('a retryable status on the last attempt is surfaced', () async {
      final stub = build(
        (_) async => http.Response('down', 502),
        options().copyWith(maxRetries: 0),
      );

      await expectLater(
        stub.client.getForecast(AnahitaFixture.berlin()),
        throwsA(
          isA<AnahitaException>().having(
            (error) => error.message,
            'message',
            contains('502'),
          ),
        ),
      );
      expect(stub.requests, hasLength(1));
    });

    test('honors Retry-After', () async {
      var calls = 0;
      final stub = build((_) async {
        calls++;
        if (calls == 1) {
          return http.Response('slow down', 429, headers: {'retry-after': '0'});
        }
        return http.Response(AnahitaFixture.forecastBody(), 200);
      }, options().copyWith(maxRetries: 1));

      final report = await stub.client.getForecast(AnahitaFixture.berlin());
      expect(report.current.temperatureC, 18.4);
      expect(stub.requests, hasLength(2));
    });

    test(
      'a huge declared content length is rejected before buffering',
      () async {
        final stub = build(
          (_) async => http.Response(
            '{"tiny":true}',
            200,
            headers: {
              'content-length': '${AnahitaDefaults.maxResponseBytesBound + 1}',
            },
          ),
          options(),
        );

        await expectLater(
          stub.client.getForecast(AnahitaFixture.berlin()),
          throwsA(
            isA<AnahitaException>().having(
              (error) => error.message,
              'message',
              contains('too large'),
            ),
          ),
        );
      },
    );

    test('insecure endpoints fail before any call', () async {
      final stub = build(
        (_) async => http.Response(AnahitaFixture.forecastBody(), 200),
        options(
          forecast: 'http://weather.example.com/v1/forecast',
          geocoding: 'http://geo.example.com/search',
        ),
      );

      await expectLater(
        stub.client.getForecast(AnahitaFixture.berlin()),
        throwsA(isA<AnahitaException>()),
      );
      await expectLater(
        stub.client.geocode('Berlin'),
        throwsA(isA<AnahitaException>()),
      );
      expect(stub.requests, isEmpty);
    });
  });

  group('geocoding', () {
    test('parses the best result and builds the query', () async {
      final stub = build(
        (_) async => http.Response(AnahitaFixture.geocodeBody(), 200),
        options(),
      );

      final place = await stub.client.geocode('Berlin');

      expect(place, isNotNull);
      expect(place!.name, 'Berlin');
      expect(place.country, 'Germany');
      expect(place.latitude, closeTo(52.52437, 1e-5));
      expect(place.timezone, 'Europe/Berlin');
      expect(place.population, 3664088);

      final url = stub.requests.single.url.toString();
      expect(url, contains('name=Berlin'));
      expect(url, contains('count=5'));
    });

    test('encodes special characters', () async {
      final stub = build(
        (_) async => http.Response(AnahitaFixture.geocodeBody(), 200),
        options(),
      );

      await stub.client.geocode('Frankfurt (Oder)');

      expect(
        stub.requests.single.url.toString(),
        contains('name=Frankfurt%20%28Oder%29'),
      );
    });

    test('empty results return null', () async {
      final stub = build(
        (_) async => http.Response(AnahitaFixture.geocodeEmptyBody(), 200),
        options(),
      );

      expect(await stub.client.geocode('Nowhereville'), isNull);
    });

    test('a 404 returns null', () async {
      final stub = build((_) async => http.Response('{}', 404), options());

      expect(await stub.client.geocode('Nowhereville'), isNull);
    });
  });
}
