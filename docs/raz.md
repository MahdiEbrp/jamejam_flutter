# raz — Vault / Encryption / Secrets

**Role:** Encrypted memory vault, password generation, policy enforcement.

**Key files / classes:**
- `raz_service.dart` — `RazService`.
- `raz_store.dart` — `MemoryVaultStore`.
- `models.dart` — `RazEntry`, `RazEntryDto`, `RazException`, `RazCryptoArgumentException`, `Base32`.
- `password_policy.dart` / `password_strength.dart` — `PasswordPolicy`, `PasswordStrength`, `PasswordGenerator`.
- `raz_defaults.dart` — `RazDefaults`.

**Usage:** Vault stores encrypted entries; generator creates strong passwords; policy validates.

**Contracts / why:** Entries encrypted at rest; null arguments throw `TypeError` not `ArgumentNullException`; database file is owner-only.

**AI fast-read:** `raz_service.dart`; `password_policy.dart` for rules.
