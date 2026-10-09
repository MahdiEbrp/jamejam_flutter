# JameJam — Agent Index

Feature modules (`lib/features/`). Each has `docs/<feature>.md` for AI-fast reading.

| Feature | Role | Key files | Doc |
|---|---|---|---|
| anahita | Weather / forecast (Open-Meteo) | service, cache, format | docs/anahita.md |
| taqvim | Calendar / agenda / sync | capture, store, sync_adapter | docs/taqvim.md |
| divan | Poetry / verses | service, model | docs/divan.md |
| ganjoor | Literature / poetry source | controller, backup | docs/ganjoor.md |
| haftkhan | Tasks / reminders | repository, task | docs/haftkhan.md |
| raz | Vault / encryption / secrets | service, store | docs/raz.md |
| settings | Preferences / storage | stores, options | docs/settings.md |
| dashboard | Home / overview | page, model | docs/dashboard.md |
| sync | Sync layer / merge | adapter, sync | docs/sync.md |
| migration | DB versioning | migration_service | docs/migration.md |
| greeter | Welcome / onboarding | page | docs/greeter.md |
| soroush | Notification / alert | service | docs/soroush.md |

Rule: read `AGENTS.md` for module roles; read `docs/<feature>.md` for usage/contracts.
