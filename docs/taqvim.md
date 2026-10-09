# taqvim — Calendar / Agenda / Sync

**Role:** Calendar capture, SQLite persistence, Jalali formatting, cross-device sync.

**Key files / classes:**
- `taqvim_capture.dart` — `CaptureResult`, `TaqvimCapture.tryParse()` (natural-language → DateTime).
- `taqvim_store.dart` — `SqliteTaqvimStore`, `MemoryTaqvimStore`; CRUD + tombstones.
- `taqvim_sync_adapter.dart` — `TaqvimSyncAdapter`; last-write-wins merge.
- `taqvim_service.dart` — `TaqvimService`; gap/free-slot computation.
- `taqvim_format.dart` — Jalali formatting.
- `models.dart` — `Occurrence`, `Recurrence`, `FreeSlot`, `IcsEvent`.

**Usage:**
```dart
final r = TaqvimCapture.tryParse("standup tomorrow at 9:30", _now);
store.add(event); adapter.merge(envelope);
```

**Contracts / why:**
- Capture never invents time; returns null if ambiguous.
- Sync adapter uses tombstones; newer edit wins; exact tie deterministic.
- Store keeps undo log; trims old tombstones.

**AI fast-read:** Source header points to this doc. Contract-heavy files: `taqvim_capture.dart`, `taqvim_sync_adapter.dart`, `taqvim_store.dart`.
