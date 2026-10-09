# migration — DB Versioning

**Role:** Migrate .NET SQLite database to Flutter version; gain sync indices.

**Key files / classes:**
- `migration_service.dart` — `MigrationService`.
- `models.dart` — `DotnetDocument`, `DotnetMigration`.
- `dialog.dart` — `MigrationDialog`, `MigrationOutcome`.

**Usage:** Detect old DB version → apply migrations → gain indexed queries.

**Contracts / why:** Must preserve existing events; tombstones must align after migration; v1→v2 adds sync indices.

**AI fast-read:** `migration_service.dart`; `TEST_PARITY.md` for parity notes.
