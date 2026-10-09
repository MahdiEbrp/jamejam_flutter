# settings — Preferences / Storage

**Role:** App settings, drafts, editors, storage guards.

**Key files / classes:**
- `settings_controller.dart` — `SettingsController`.
- `settings_page.dart` — `SettingsPage`, `SettingEditorDialog`, `SettingGuard`.
- `stores/` — `MemorySettingsStore`, `SettingDraft`, `SettingsEntry`, `SettingsOptions`.

**Usage:** Edit settings → draft → guard validates → persist to store.

**Contracts / why:** Guards prevent invalid states; drafts allow cancel without saving.

**AI fast-read:** `settings_controller.dart`; `stores/` for persistence contract.
