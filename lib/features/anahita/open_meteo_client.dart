/// anahita — see doc/anahita.md and AGENTS.md
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/date_only.dart';
import '../soroush/soroush_guard.dart';
import 'anahita_defaults.dart';
import 'anahita_options.dart';
import 'models.dart';
import 'unit_math.dart';

abstract class AnahitaClient {
  /// Resolves a place name to coordinates; null when the geocoder knows nothing.
  Future<GeoPlace?> geocode(String name);

  /// Downloads the forecast for a resolved place.
  Future<WeatherReport> getForecast(GeoPlace place);
}

class OpenMeteoClient implements AnahitaClient {
  /// Wraps an HTTP client with the validated options.
  OpenMeteoClient({
    required http.Client httpClient,
    required this.options,
    DateTime Function()? clock,
    Random? random,
  }) : _http = httpClient,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random();

  static const String _truncationSuffix = '…';
  static const int _maxErrorBodyCharacters = 500;
  static const double _jitterScale = 0.5;

  /// Status codes worth another attempt — the same set Soroush retries.
  static const Set<int> retryableStatusCodes = <int>{
    408,
    429,
    500,
    502,
    503,
    504,
  };

  static const List<String> currentVariables = <String>[
    'temperature_2m',
    'apparent_temperature',
    'relative_humidity_2m',
    'precipitation',
    'weather_code',
    'wind_speed_10m',
    'wind_direction_10m',
  ];

  static const List<String> hourlyVariables = <String>[
    'temperature_2m',
    'apparent_temperature',
    'relative_humidity_2m',
    'precipitation_probability',
    'precipitation',
    'weather_code',
    'wind_speed_10m',
  ];

  static const List<String> dailyVariables = <String>[
    'weather_code',
    'temperature_2m_max',
    'temperature_2m_min',
    'precipitation_sum',
    'precipitation_probability_max',
    'wind_speed_10m_max',
    'uv_index_max',
    'sunrise',
    'sunset',
  ];

  final http.Client _http;

  /// The validated options this client was built with.
  final AnahitaOptions options;

  final DateTime Function() _clock;
  final Random _random;

  @override
  Future<GeoPlace?> geocode(String name) async {
    if (name.trim().isEmpty) {
      throw AnahitaException('A place name is required to geocode.');
    }
    options.validate();
    final endpoint = Uri.parse(_geocodingUrl(name));

    final response = await _sendWithRetries(() => _request(endpoint));
    if (response.statusCode == 404) return null;

    _ensureSuccess(response);
    final json = _readCapped(response);
    final dto = _parseMap(json, 'geocoding');
    final results = dto['results'];
    if (results is! List || results.isEmpty) return null;

    final first = results.first;
    if (first is! Map<String, dynamic>) return null;
    return _toPlace(first);
  }

  @override
  Future<WeatherReport> getForecast(GeoPlace place) async {
    options.validate();
    final endpoint = Uri.parse(_forecastUrl(place));

    final response = await _sendWithRetries(() => _request(endpoint));
    _ensureSuccess(response);

    final json = _readCapped(response);
    final dto = _parseMap(json, 'weather');
    return _toReport(place, dto);
  }

  GeoPlace _toPlace(Map<String, dynamic> dto) {
    final timezone = _text(dto['timezone']);
    return GeoPlace(
      name: _text(dto['name']),
      country: _text(dto['country']),
      latitude: _number(dto['latitude']) ?? 0,
      longitude: _number(dto['longitude']) ?? 0,
      timezone: timezone.trim().isEmpty ? 'auto' : timezone,
      admin1: _text(dto['admin1']),
      population: (_number(dto['population']) ?? 0).round(),
    );
  }

  WeatherReport _toReport(GeoPlace place, Map<String, dynamic> dto) {
    final current = dto['current'];
    if (current is! Map<String, dynamic>) {
      throw const AnahitaException(
        'The weather endpoint returned no current conditions (invalid payload).',
      );
    }

    final timezone = _text(dto['timezone']);
    final resolved = place.copyWith(
      timezone: timezone.trim().isEmpty ? place.timezone : timezone,
    );

    return WeatherReport(
      place: resolved,
      fetchedAt: _clock().toUtc(),
      current: _toCurrent(current),
      hourly: _toHourly(dto['hourly']),
      daily: _toDaily(dto['daily']),
    );
  }

  CurrentConditions _toCurrent(Map<String, dynamic> dto) {
    final temperature = _number(dto['temperature_2m']) ?? 0;
    return CurrentConditions(
      localTime: _parseLocal(dto['time'], 'current time'),
      temperatureC: temperature,
      apparentC: _number(dto['apparent_temperature']) ?? temperature,
      humidityPercent: UnitMath.toInt(_number(dto['relative_humidity_2m'])),
      precipMm: _number(dto['precipitation']) ?? 0,
      code: UnitMath.toInt(_number(dto['weather_code'])),
      windKmh: _number(dto['wind_speed_10m']) ?? 0,
      windDirectionDeg: UnitMath.toInt(_number(dto['wind_direction_10m'])),
    );
  }

  List<HourlyPoint> _toHourly(Object? raw) {
    if (raw is! Map<String, dynamic>) return const [];
    final times = raw['time'];
    if (times is! List || times.isEmpty) return const [];

    final count = times.length;
    final temperature = _aligned(
      raw,
      'temperature_2m',
      count,
      'hourly temperature',
    );
    final apparent = _aligned(
      raw,
      'apparent_temperature',
      count,
      'hourly feels-like',
    );
    final humidity = _aligned(
      raw,
      'relative_humidity_2m',
      count,
      'hourly humidity',
    );
    final chance = _aligned(
      raw,
      'precipitation_probability',
      count,
      'hourly rain chance',
    );
    final precipitation = _aligned(
      raw,
      'precipitation',
      count,
      'hourly precipitation',
    );
    final code = _aligned(raw, 'weather_code', count, 'hourly weather code');
    final wind = _aligned(raw, 'wind_speed_10m', count, 'hourly wind');

    return List.unmodifiable(<HourlyPoint>[
      for (var i = 0; i < count; i++)
        HourlyPoint(
          localTime: _parseLocal(times[i], 'hourly time'),
          temperatureC: temperature[i] ?? 0,
          apparentC: apparent[i] ?? temperature[i] ?? 0,
          precipProbabilityPercent: chance[i],
          precipMm: precipitation[i] ?? 0,
          code: UnitMath.toInt(code[i]),
          windKmh: wind[i] ?? 0,
          humidityPercent: UnitMath.toInt(humidity[i]),
        ),
    ]);
  }

  List<DailyPoint> _toDaily(Object? raw) {
    if (raw is! Map<String, dynamic>) return const [];
    final dates = raw['time'];
    if (dates is! List || dates.isEmpty) return const [];

    final count = dates.length;
    final code = _aligned(raw, 'weather_code', count, 'daily weather code');
    final max = _aligned(raw, 'temperature_2m_max', count, 'daily high');
    final min = _aligned(raw, 'temperature_2m_min', count, 'daily low');
    final sum = _aligned(
      raw,
      'precipitation_sum',
      count,
      'daily precipitation',
    );
    final chance = _aligned(
      raw,
      'precipitation_probability_max',
      count,
      'daily rain chance',
    );
    final wind = _aligned(raw, 'wind_speed_10m_max', count, 'daily wind');
    final uv = _aligned(raw, 'uv_index_max', count, 'daily UV');
    final sunrise = _alignedStrings(raw, 'sunrise', count, 'daily sunrise');
    final sunset = _alignedStrings(raw, 'sunset', count, 'daily sunset');

    return List.unmodifiable(<DailyPoint>[
      for (var i = 0; i < count; i++)
        DailyPoint(
          date: _parseDate(dates[i]),
          code: UnitMath.toInt(code[i]),
          minC: min[i] ?? 0,
          maxC: max[i] ?? 0,
          precipProbabilityPercent: chance[i],
          precipSumMm: sum[i] ?? 0,
          windMaxKmh: wind[i] ?? 0,
          uvMax: uv[i],
          sunrise: _parseTimeOfDay(sunrise[i]),
          sunset: _parseTimeOfDay(sunset[i]),
        ),
    ]);
  }

  /// The .NET client refuses misaligned arrays instead of guessing — same here.
  List<double?> _aligned(
    Map<String, dynamic> raw,
    String key,
    int expected,
    String what,
  ) {
    final value = raw[key];
    if (value is! List || value.length != expected) {
      throw AnahitaException(
        'The weather endpoint returned inconsistent data ($what is missing or misaligned).',
      );
    }
    return <double?>[for (final item in value) _number(item)];
  }

  List<String?> _alignedStrings(
    Map<String, dynamic> raw,
    String key,
    int expected,
    String what,
  ) {
    final value = raw[key];
    if (value is! List || value.length != expected) {
      throw AnahitaException(
        'The weather endpoint returned inconsistent data ($what is missing or misaligned).',
      );
    }
    return <String?>[for (final item in value) item == null ? null : '$item'];
  }

  DateTime _parseLocal(Object? value, String what) {
    final text = value == null ? null : '$value';
    final parsed = text == null
        ? null
        : DateTime.tryParse(_normalizeTimestamp(text));
    if (parsed != null) return parsed;
    throw AnahitaException(
      "The weather endpoint returned an unreadable $what ('$value').",
    );
  }

  /// Open-Meteo sends `yyyy-MM-ddTHH:mm` — pad seconds so [DateTime.parse] accepts it.
  static String _normalizeTimestamp(String value) =>
      value.length == 16 ? '$value:00' : value;

  DateOnly _parseDate(Object? value) {
    final text = value == null ? null : '$value';
    if (text != null && text.length >= 10) {
      try {
        return DateOnly.parseIso(text.substring(0, 10));
      } on FormatException {
        // fall through to the protocol error below
      }
    }
    throw AnahitaException(
      "The weather endpoint returned an unreadable date ('$value').",
    );
  }

  TimeOfDayValue? _parseTimeOfDay(String? value) {
    if (value == null || value.isEmpty) return null;
    final local = _parseLocal(value, 'sun time');
    return TimeOfDayValue(local.hour, local.minute);
  }

  Map<String, dynamic> _parseMap(String json, String kind) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (error) {
      throw AnahitaException(
        'The $kind endpoint did not return a valid Anahita weather response.',
        inner: error,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw AnahitaException('The $kind endpoint returned an empty payload.');
    }
    return decoded;
  }

  String _forecastUrl(GeoPlace place) {
    final latitude = UnitMath.fourDigits(place.latitude);
    final longitude = UnitMath.fourDigits(place.longitude);
    final current = currentVariables.join(',');
    final hourly = hourlyVariables.join(',');
    final daily = dailyVariables.join(',');
    return '${options.forecastEndpoint}?latitude=$latitude&longitude=$longitude'
        '&current=$current&hourly=$hourly&daily=$daily'
        '&timezone=auto&forecast_days=${options.forecastDays}';
  }

  String _geocodingUrl(String name) =>
      '${options.geocodingEndpoint}?name=${_escapeDataString(name)}'
      '&count=${AnahitaDefaults.geocodeResultLimit}&language=en&format=json';

  http.Request _request(Uri endpoint) {
    final request = http.Request('GET', endpoint);
    final key = options.apiKey;
    if (key != null && key.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $key';
    }
    request.followRedirects = false;
    return request;
  }

  Future<http.Response> _sendWithRetries(http.Request Function() build) async {
    final maxAttempts = options.maxRetries + 1;

    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _http
            .send(build())
            .timeout(options.requestTimeout)
            .then(http.Response.fromStream);

        final retryable = retryableStatusCodes.contains(response.statusCode);
        if (!retryable || attempt >= maxAttempts || response.statusCode < 400) {
          return response;
        }

        await _delayBeforeRetry(response.headers['retry-after'], attempt);
      } on TimeoutException {
        if (attempt >= maxAttempts) {
          throw AnahitaException(
            'Weather request timed out after $attempt attempt(s) without success.',
          );
        }
        await _delayBeforeRetry(null, attempt);
      } on http.ClientException catch (error) {
        if (attempt >= maxAttempts) {
          throw AnahitaException(
            'Network error talking to the weather endpoint: ${error.message}',
            inner: error,
          );
        }
        await _delayBeforeRetry(null, attempt);
      }
    }
  }

  /// Reads the body with a hard cap, refusing anything larger before it is buffered.
  String _readCapped(http.Response response) {
    final declared = response.headers['content-length'];
    if (declared != null) {
      final length = int.tryParse(declared);
      if (length != null && length > AnahitaDefaults.maxResponseBytesBound) {
        throw const AnahitaException('The weather response is too large.');
      }
    }

    final body = response.body;
    if (body.length > options.maxResponseBytes) {
      throw AnahitaException(
        'The weather response exceeds the configured maximum of '
        '${options.maxResponseBytes} bytes.',
      );
    }
    return body;
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    var body = response.body;
    if (body.length > _maxErrorBodyCharacters) {
      body = '${body.substring(0, _maxErrorBodyCharacters)}$_truncationSuffix';
    }
    body = SoroushGuard.redactIn(body, options.apiKey);

    throw AnahitaException(
      'Weather endpoint returned ${response.statusCode} (${response.reasonPhrase}). '
      'Body: $body',
      statusCode: response.statusCode,
    );
  }

  Future<void> _delayBeforeRetry(String? retryAfter, int attempt) async {
    final retryAfterMs = _parseRetryAfter(retryAfter);
    final backoff =
        options.retryBaseDelay.inMilliseconds * pow(2, attempt - 1).toDouble();
    final jittered =
        backoff *
        (1 - _jitterScale + (2 * _jitterScale * _random.nextDouble()));
    final delayMs = retryAfterMs ?? jittered.round();

    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }

  static int? _parseRetryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return seconds * 1000;
    final date = DateTime.tryParse(value.trim());
    if (date == null) return null;
    return date.difference(DateTime.now()).inMilliseconds;
  }

  /// Percent-encodes everything outside the unreserved set — the .NET
  /// `Uri.EscapeDataString` behaviour, so `Frankfurt (Oder)` becomes `Frankfurt%20%28Oder%29`
  /// rather than the form-encoded `Frankfurt+%28Oder%29`.
  static String _escapeDataString(String value) {
    final buffer = StringBuffer();
    for (final byte in utf8.encode(value)) {
      final isUnreserved =
          (byte >= 0x41 && byte <= 0x5A) || // A–Z
          (byte >= 0x61 && byte <= 0x7A) || // a–z
          (byte >= 0x30 && byte <= 0x39) || // 0–9
          byte == 0x2D || // -
          byte == 0x2E || // .
          byte == 0x5F || // _
          byte == 0x7E; // ~
      if (isUnreserved) {
        buffer.writeCharCode(byte);
      } else {
        buffer.write(
          '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      }
    }
    return buffer.toString();
  }

  static String _text(Object? value) => value == null ? '' : '$value';

  static double? _number(Object? value) => switch (value) {
    null => null,
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };
}
