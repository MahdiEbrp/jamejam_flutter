// Parity port of tests/JameJam.Tests/Anahita/AnahitaOptionsTests.cs (14 cases).
//
// The .NET suite sets real environment variables and reads them back; the Dart port takes the
// environment as a map (a GUI cannot require a shell export), so the same cases drive
// [AnahitaOptions.fromEnvironment] with an explicit map instead of mutating the process.
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/anahita/anahita_defaults.dart';
import 'package:jamejam/features/anahita/anahita_options.dart';
import 'package:jamejam/features/anahita/models.dart';

void main() {
  void rejects(AnahitaOptions options, String messagePart) {
    expect(
      options.validate,
      throwsA(
        isA<AnahitaException>().having(
          (error) => error.message,
          'message',
          contains(messagePart),
        ),
      ),
    );
  }

  test('the defaults are valid', () {
    expect(const AnahitaOptions().validate, returnsNormally);
  });

  test('the forecast endpoint is required and must parse', () {
    rejects(
      const AnahitaOptions(forecastEndpoint: ''),
      'forecast endpoint must not be empty',
    );
    rejects(
      const AnahitaOptions(forecastEndpoint: 'not a url'),
      'Invalid forecast endpoint',
    );
  });

  test('the forecast endpoint rejects query strings', () {
    rejects(
      const AnahitaOptions(
        forecastEndpoint: 'https://api.test/v1/forecast?key=x',
      ),
      'without a query string',
    );
  });

  test('the geocoding endpoint follows the same policy', () {
    rejects(
      const AnahitaOptions(geocodingEndpoint: ''),
      'geocoding endpoint must not be empty',
    );
    rejects(
      const AnahitaOptions(geocodingEndpoint: 'ftp://geo.test'),
      'Insecure geocoding endpoint',
    );
    rejects(
      const AnahitaOptions(geocodingEndpoint: 'http://geo.example.com/search'),
      'Insecure geocoding endpoint',
    );
  });

  test('loopback HTTP is allowed', () {
    expect(
      const AnahitaOptions(
        forecastEndpoint: 'http://127.0.0.1:8080/v1/forecast',
        geocodingEndpoint: 'http://localhost:8080/search',
      ).validate,
      returnsNormally,
    );
  });

  test('the request timeout has rails', () {
    rejects(
      const AnahitaOptions(requestTimeout: Duration.zero),
      'RequestTimeout must be',
    );
    rejects(
      const AnahitaOptions(requestTimeout: Duration(minutes: 11)),
      'RequestTimeout must be',
    );
  });

  test('the retry count has rails', () {
    rejects(
      const AnahitaOptions(maxRetries: -1),
      'MaxRetries must be between 0 and 10',
    );
    rejects(
      const AnahitaOptions(maxRetries: 11),
      'MaxRetries must be between 0 and 10',
    );
  });

  test('the retry delay cannot be negative', () {
    rejects(
      const AnahitaOptions(retryBaseDelay: Duration(milliseconds: -1)),
      'RetryBaseDelay',
    );
  });

  test('the response cap has rails', () {
    rejects(
      const AnahitaOptions(maxResponseBytes: 0),
      'MaxResponseBytes must be between 1 and',
    );
    rejects(
      const AnahitaOptions(maxResponseBytes: 65 * 1024 * 1024),
      'MaxResponseBytes must be between 1 and',
    );
  });

  test('the cache TTL has rails', () {
    rejects(
      const AnahitaOptions(cacheTtl: Duration(hours: -1)),
      'CacheTtl must be between zero and',
    );
    rejects(
      const AnahitaOptions(cacheTtl: Duration(hours: 25)),
      'CacheTtl must be between zero and',
    );
  });

  test('the forecast length has rails', () {
    rejects(
      const AnahitaOptions(forecastDays: 0),
      'ForecastDays must be between 1 and 16',
    );
    rejects(
      const AnahitaOptions(forecastDays: 17),
      'ForecastDays must be between 1 and 16',
    );
  });

  test('the hourly window has rails', () {
    rejects(
      const AnahitaOptions(hourlyWindow: 0),
      'HourlyWindow must be between 1 and 48',
    );
    rejects(
      const AnahitaOptions(hourlyWindow: 49),
      'HourlyWindow must be between 1 and 48',
    );
  });

  test('the AI prompt tunables have rails', () {
    rejects(
      const AnahitaOptions(aiMaxQuestionChars: 0),
      'AiMaxQuestionChars must be between 1 and',
    );
    rejects(
      const AnahitaOptions(aiMaxQuestionChars: 2001),
      'AiMaxQuestionChars must be between 1 and',
    );
    rejects(
      const AnahitaOptions(aiMaxTaskCount: 0),
      'AiMaxTaskCount must be between 1 and',
    );
    rejects(
      const AnahitaOptions(aiMaxTaskCount: 101),
      'AiMaxTaskCount must be between 1 and',
    );
    rejects(
      const AnahitaOptions(aiHourlyLines: 49),
      'AiHourlyLines must be between 1 and',
    );
  });

  test('the environment overrides the endpoints and the key', () {
    final options = AnahitaOptions.fromEnvironment(const {
      AnahitaDefaults.endpointEnvironmentVariable:
          'https://mirror.test/forecast',
      AnahitaDefaults.geocodingEnvironmentVariable:
          'https://mirror.test/search',
      AnahitaDefaults.apiKeyEnvironmentVariable: 'mirror-key-42',
    });

    expect(options.forecastEndpoint, 'https://mirror.test/forecast');
    expect(options.geocodingEndpoint, 'https://mirror.test/search');
    expect(options.apiKey, 'mirror-key-42');
    expect(options.validate, returnsNormally);
  });

  test('blank environment values fall back to the defaults', () {
    final options = AnahitaOptions.fromEnvironment(const {
      AnahitaDefaults.endpointEnvironmentVariable: '   ',
    });

    expect(options.forecastEndpoint, AnahitaDefaults.forecastEndpoint);
    expect(options.geocodingEndpoint, AnahitaDefaults.geocodingEndpoint);
    expect(options.apiKey, isNull);
  });

  test('copyWith replaces only what it is given', () {
    const base = AnahitaOptions();
    final changed = base.copyWith(forecastDays: 3, apiKey: 'k');

    expect(changed.forecastDays, 3);
    expect(changed.apiKey, 'k');
    expect(changed.forecastEndpoint, base.forecastEndpoint);
    expect(changed.hourlyWindow, base.hourlyWindow);
  });
}
