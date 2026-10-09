/// anahita — see doc/anahita.md and AGENTS.md
library;

import 'anahita_defaults.dart';
import 'models.dart';
import 'unit_math.dart';

class AnahitaCache {
  /// Creates a cache with a time source and a time-to-live.
  AnahitaCache({required DateTime Function() clock, Duration? ttl})
    : _clock = clock,
      _ttl = ttl ?? AnahitaDefaults.cacheTtl;

  static const String _autoTimezone = 'auto';

  final DateTime Function() _clock;
  final Duration _ttl;
  final Map<String, ({DateTime storedAt, WeatherReport report})> _reports = {};
  final Map<String, GeoPlace> _places = {};

  /// Returns the cached report for a place and forecast length, or null when absent/expired.
  WeatherReport? getReport(GeoPlace place, int forecastDays) {
    final entry = _reports[reportKey(place, forecastDays)];
    if (entry == null) return null;
    if (_clock().toUtc().difference(entry.storedAt) < _ttl) {
      return entry.report;
    }
    return null;
  }

  /// Caches a report for a place and forecast length.
  void setReport(GeoPlace place, int forecastDays, WeatherReport report) {
    _reports[reportKey(place, forecastDays)] = (
      storedAt: _clock().toUtc(),
      report: report,
    );
  }

  /// Returns the cached geocode for a name (case-insensitive), or null when absent.
  GeoPlace? getPlace(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    final needle = name.toLowerCase();
    for (final entry in _places.entries) {
      if (entry.key.toLowerCase() == needle) return entry.value;
    }
    return null;
  }

  /// Caches a resolved place under the queried name.
  void setPlace(String name, GeoPlace place) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    _places[name] = place;
  }

  /// The `lat,lon|days|timezone-unresolved` key, at the precision the .NET key used.
  static String reportKey(GeoPlace place, int forecastDays) {
    final latitude = _fixed(place.latitude, 4);
    final longitude = _fixed(place.longitude, 4);
    final auto = place.timezone == _autoTimezone;
    return '$latitude,$longitude|$forecastDays|$auto';
  }

  static String _fixed(double value, int digits) =>
      digits == 4 ? UnitMath.fourDigits(value) : value.toStringAsFixed(digits);
}
