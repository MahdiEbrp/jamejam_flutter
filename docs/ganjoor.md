# ganjoor — Literature / Poetry Source

**Role:** Literature source, budget/finance assistant (books, bills, cash-flow).

**Key files / classes:**
- `ganjoor_controller.dart` — `GanjoorController`.
- `ganjoor_page.dart` — `GanjoorPage`, `GanjoorAccount`.
- `ganjoor_service.dart` — `GanjoorService`.
- `models.dart` — `GanjoorBudget`, `GanjoorBill`, `GanjoorBudgetStatus`, `GanjoorCashFlow`, `GanjoorBackup`, `GanjoorBackupFile`, `FinanceAssistant`.

**Usage:** Controller drives page; service handles budget/backup logic; backup exports/loads.

**Contracts / why:** Budget alerts respect status thresholds; backup file is owner-only; cash-flow calculates based on bill dates.

**AI fast-read:** `ganjoor_service.dart` + `models.dart`.
