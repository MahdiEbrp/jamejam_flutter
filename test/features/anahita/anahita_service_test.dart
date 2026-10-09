// Parity port of tests/JameJam.Tests/Anahita/AnahitaServiceTests.cs (14 cases).
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/anahita/anahita_cache.dart';
import 'package:jamejam/features/anahita/anahita_options.dart';
import 'package:jamejam/features/anahita/anahita_service.dart';
import 'package:jamejam/features/anahita/models.dart';
import 'package:jamejam/features/anahita/open_meteo_client.dart';

import 'anahita_fixture.dart';

/// Records geocode calls and returns canned results — the .NET `StubClient`.
/// Shared with the edge-case suite.
class StubAnahitaClient implements AnahitaClient {
  GeoPlace? geocodeResult = AnahitaFixture.berlin();
  WeatherReport report = AnahitaFixture.report([
    AnahitaFixture.day(const DateOnly(2026, 9, 19)),
  ]);

  final List<String> geocodeNames = [];
  final List<GeoPlace> forecastPlaces = [];

  int get forecastCalls => forecastPlaces.length;

  @override
  Future<GeoPlace?> geocode(String name) async {
    geocodeNames.add(name);
    return geocodeResult;
  }

  @override
  Future<WeatherReport> getForecast(GeoPlace place) async {
    forecastPlaces.add(place);
    return report;
  }
}

void main() {
  AnahitaOptions options() =>
      const AnahitaOptions(cacheTtl: Duration(minutes: 10));

  AnahitaService service(
    AnahitaClient client,
    SteppingClock clock, {
    Future<String?> Function()? savedLocation,
    AnahitaOptions? override,
  }) => AnahitaService(
    client: client,
    clock: clock.call,
    options: override ?? options(),
    savedLocation: savedLocation,
  );

  test('no location anywhere throws with guidance', () async {
    final client = StubAnahitaClient();
    final graph = service(
      client,
      AnahitaFixture.clock(),
      savedLocation: () async => null,
    );

    await expectLater(
      graph.current(),
      throwsA(
        isA<AnahitaException>()
            .having(
              (error) => error.message,
              'message',
              contains('No location'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('JameJam weather set'),
            ),
      ),
    );
  });

  test('a place name is geocoded and displayed', () async {
    final client = StubAnahitaClient();
    final graph = service(client, AnahitaFixture.clock());

    final report = await graph.current(placeArg: 'Berlin');

    expect(client.geocodeNames, ['Berlin']);
    expect(report.place.name, 'Berlin');
  });

  test('coordinates are used directly, without geocoding', () async {
    final client = StubAnahitaClient();
    final graph = service(client, AnahitaFixture.clock());

    await graph.current(placeArg: '  64.15, -21.94 ');

    expect(client.geocodeNames, isEmpty);
    expect(client.forecastPlaces.single.latitude, 64.15);
    expect(client.forecastPlaces.single.longitude, -21.94);
    expect(client.forecastPlaces.single.name, '64.15, -21.94');
  });

  test('unparseable coordinate pairs fall back to geocoding', () async {
    final client = StubAnahitaClient();
    final graph = service(client, AnahitaFixture.clock());

    await graph.current(placeArg: '52.5,not-a-number');

    expect(client.geocodeNames, ['52.5,not-a-number']);
  });

  test('out-of-range coordinates fall back to geocoding', () async {
    final client = StubAnahitaClient();
    final graph = service(client, AnahitaFixture.clock());

    await graph.current(
      placeArg: '99, 200',
    ); // beyond the rails → a (doomed) lookup

    expect(client.geocodeNames, ['99, 200']);
  });

  test('an unknown place throws with a helpful hint', () async {
    final client = StubAnahitaClient()..geocodeResult = null;
    final graph = service(client, AnahitaFixture.clock());

    await expectLater(
      graph.current(placeArg: 'Nowhereville'),
      throwsA(
        isA<AnahitaException>()
            .having(
              (error) => error.message,
              'message',
              contains("could not find 'Nowhereville'"),
            )
            .having(
              (error) => error.message,
              'message',
              contains('52.52,13.41'),
            ),
      ),
    );
  });

  test('an argument beats the saved setting', () async {
    final client = StubAnahitaClient();
    final graph = service(
      client,
      AnahitaFixture.clock(),
      savedLocation: () async => 'Hamburg',
    );

    await graph.current(placeArg: 'Berlin');

    expect(client.geocodeNames, ['Berlin']);
  });

  test('the saved setting is used when there is no argument', () async {
    final client = StubAnahitaClient();
    final graph = service(
      client,
      AnahitaFixture.clock(),
      savedLocation: () async => 'Hamburg',
    );

    await graph.current();

    expect(client.geocodeNames, ['Hamburg']);
  });

  test(
    'geocodes are cached per name forever; reports only until the TTL',
    () async {
      final clock = AnahitaFixture.clock();
      final client = StubAnahitaClient();
      final graph = service(client, clock);

      await graph.current(placeArg: 'berlin');
      await graph.current(placeArg: 'BERLIN');

      // Both caches hot: one geocode, one forecast — and the place cache never expires.
      expect(client.geocodeNames, ['berlin']);
      expect(client.forecastCalls, 1);

      clock.advance(
        const Duration(minutes: 11),
      ); // report stale, place still cached
      await graph.current(placeArg: 'Berlin');
      expect(client.geocodeNames, ['berlin']);
      expect(client.forecastCalls, 2);
    },
  );

  test('reports are cached until the TTL expires', () async {
    final clock = AnahitaFixture.clock();
    final client = StubAnahitaClient();
    final graph = service(client, clock);

    await graph.current(placeArg: 'Berlin');
    clock.advance(const Duration(minutes: 9));
    await graph.current(placeArg: 'Berlin');
    expect(client.forecastCalls, 1); // still fresh

    clock.advance(const Duration(minutes: 2)); // beyond the 10-minute TTL
    await graph.current(placeArg: 'Berlin');
    expect(client.forecastCalls, 2);
  });

  test('the cache distinguishes forecast lengths', () async {
    final clock = AnahitaFixture.clock();
    final client = StubAnahitaClient();
    await service(
      client,
      clock,
      override: options().copyWith(forecastDays: 3),
    ).current(placeArg: 'Berlin');
    await service(
      client,
      clock,
      override: options().copyWith(forecastDays: 7),
    ).current(placeArg: 'Berlin');

    expect(client.forecastCalls, 2);
  });

  group('AnahitaCache', () {
    test('the place cache is case-insensitive', () {
      final cache = AnahitaCache(
        clock: AnahitaFixture.clock().call,
        ttl: const Duration(minutes: 5),
      )..setPlace('Berlin', AnahitaFixture.berlin());

      expect(cache.getPlace('BERLIN')?.name, 'Berlin');
      expect(cache.getPlace('Hamburg'), isNull);
    });

    test('reports expire after the TTL', () {
      final clock = AnahitaFixture.clock();
      final cache = AnahitaCache(
        clock: clock.call,
        ttl: const Duration(minutes: 15),
      );
      final report = AnahitaFixture.report();

      cache.setReport(AnahitaFixture.berlin(), 7, report);
      expect(cache.getReport(AnahitaFixture.berlin(), 7), same(report));

      clock.advance(const Duration(minutes: 14));
      expect(cache.getReport(AnahitaFixture.berlin(), 7), isNotNull);

      clock.advance(const Duration(minutes: 2));
      expect(cache.getReport(AnahitaFixture.berlin(), 7), isNull);
    });

    test('a zero TTL disables report caching but keeps places', () {
      final cache =
          AnahitaCache(clock: AnahitaFixture.clock().call, ttl: Duration.zero)
            ..setPlace('Berlin', AnahitaFixture.berlin())
            ..setReport(AnahitaFixture.berlin(), 7, AnahitaFixture.report());

      expect(cache.getPlace('Berlin'), isNotNull); // geocodes never go stale
      expect(cache.getReport(AnahitaFixture.berlin(), 7), isNull);
    });
  });
}
