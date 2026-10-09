# anahita — Weather / Forecast

**Role:** Open-Meteo forecast fetcher with location resolution and caching.

**What it does:** Resolves a location (argument → env → saved setting), downloads forecast, serves cached reports while fresh.

**Key files / classes:**
- `anahita_service.dart` — `AnahitaService` wires transport/clock/options/cache.
- `anahita_cache.dart` — `AnahitaCache` TTL-based.
- `open_meteo_client.dart` — transport layer.
- `anahita_format.dart` — `AnahitaFormat`, `CurrentConditions`.
- `anahita_insights.dart` — insights logic.
- `anahita_options.dart` — `AnahitaOptions`.
- `models.dart` — data models.

**Usage:**
```dart
AnahitaService(client: ..., clock: () => DateTime.now(), cache: ...)
  .current(placeArg: "Berlin") // returns WeatherReport
```

**Contracts / why:**
- Cache TTL set by `AnahitaOptions`; never invent location.
- `resolveLocation()` falls back through candidates.
- Throws `AnahitaException` on unknown place / no transport.

**AI fast-read:** Read `AGENTS.md`; source comments reference `doc/anahita.md`. Key contract file: `lib/features/anahita/anahita_service.dart`.
