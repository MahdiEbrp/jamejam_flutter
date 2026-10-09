# sync — Sync Layer / Merge

**Role:** Cross-device synchronization adapters, clients, envelopes.

**Key files / classes:**
- `sync_controller.dart` — `SyncController`.
- `sync_adapter.dart` — adapter logic per feature (Divan, HaftKhan).
- `sync_client.dart` — `HttpSyncClient`, `MemorySyncClient`, `SyncClient`.
- `models.dart` — `SyncEnvelope`, `SyncException`, `SyncOptions`, `SyncDefaults`.

**Usage:** Capture local changes → build envelope → send via client → apply merge on remote.

**Contracts / why:** Last-write-wins; tombstones beat old events; empty sync ids ignored; invalid json throws `SyncException`.

**AI fast-read:** `sync_adapter.dart`; `sync_client.dart` for transport.
