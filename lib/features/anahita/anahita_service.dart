/// anahita — see doc/anahita.md and AGENTS.md
library;

import 'anahita_cache.dart';
import 'anahita_strings.dart';
import 'anahita_defaults.dart';
import 'anahita_options.dart';
import 'models.dart';
import 'open_meteo_client.dart';
import 'unit_math.dart';

class AnahitaService {
  /// Wires the transport, the clock, the options, the saved-location lookup, and the cache.
  AnahitaService({
    required AnahitaClient client,
    required DateTime Function() clock,
    AnahitaOptions? options,
    Future<String?> Function()? savedLocation,
    Map<String, String> environment = const {},
    AnahitaCache? cache,
  }) : _client = client,
       _clock = clock,
       _options = options ?? const AnahitaOptions(),
       _savedLocation = savedLocation,
       _environment = environment,
       _cache = cache ?? AnahitaCache(clock: clock, ttl: options?.cacheTtl);

  final AnahitaClient _client;
  final DateTime Function() _clock;
  final AnahitaOptions _options;
  final Future<String?> Function()? _savedLocation;
  final Map<String, String> _environment;
  final AnahitaCache _cache;

  /// The options this service validates and sends with.
  AnahitaOptions get options => _options;

  /// The location the CLI would have used: flag, then environment, then the saved setting.
  Future<String?> resolveLocation(String? placeArg) async {
    final candidates = <String?>[
      placeArg,
      _environment[AnahitaDefaults.locationEnvironmentVariable],
      await _savedLocation?.call(),
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  /// Resolves the location and returns the current report (cached when fresh).
  ///
  /// Throws [AnahitaException] when there is no location, the place is unknown, or the
  /// transport fails.
  Future<WeatherReport> current({String? placeArg}) async {
    final location = await resolveLocation(placeArg);
    if (location == null) {
      throw const AnahitaException(AnahitaDefaults.noLocationMessage);
    }

    final place = await resolvePlace(location);
    final cached = _cache.getReport(place, _options.forecastDays);
    if (cached != null) return cached;

    final report = await _client.getForecast(place);
    _cache.setReport(place, _options.forecastDays, report);
    return report;
  }

  /// Turns a place name or "lat,lon" pair into coordinates (geocoding when needed).
  Future<GeoPlace> resolvePlace(String location) async {
    final coordinates = tryParseCoordinates(location);
    if (coordinates != null) return coordinates;

    final cached = _cache.getPlace(location);
    if (cached != null) return cached;

    final resolved = await _client.geocode(location);
    if (resolved == null) {
      throw AnahitaException(
        '${AnahitaStrings.locationNotFoundMsg.replaceFirst('%s', location)} '
        '${AnahitaStrings.notFoundPrefix} '
        '${AnahitaStrings.notFoundCoordinateHint}${AnahitaStrings.coordinateExample}',
      );
    }

    _cache.setPlace(location, resolved);
    return resolved;
  }

  /// Parses `"52.52, 13.41"` when it is a pair of in-range numbers; null otherwise.
  static GeoPlace? tryParseCoordinates(String location) {
    final parts = location.split(',');
    if (parts.length != 2) return null;

    final latitude = double.tryParse(parts[0].trim());
    final longitude = double.tryParse(parts[1].trim());
    if (latitude == null || longitude == null) return null;

    if (latitude.abs() > AnahitaDefaults.latitudeBound ||
        longitude.abs() > AnahitaDefaults.longitudeBound) {
      return null;
    }

    return GeoPlace(
      name:
          '${UnitMath.fourDigits(latitude)}, ${UnitMath.fourDigits(longitude)}',
      country: '',
      latitude: latitude,
      longitude: longitude,
      timezone: 'auto',
    );
  }

  /// The service clock, exposed so views can label "as of" times deterministically.
  DateTime now() => _clock();
}
