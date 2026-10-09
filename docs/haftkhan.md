# haftkhan — Tasks / Reminders

**Role:** Task board, reminders, dependencies, AI planning.

**Key files / classes:**
- `haftkhan_controller.dart` — `HaftKhanController`.
- `haftkhan_page.dart` — `HaftKhanPage`, `BoardColumn`, `CompleteResult`.
- `haftkhan_service.dart` — `HaftKhanService`.
- `task_repository_parity_test.dart` references repository contract.
- `models.dart` — `AiTaskPlan`, `AiTaskAssistant`, `DependencyDto`, `BackupFile`.

**Usage:** Board columns → tasks → complete with dependencies; AI assistant suggests plans.

**Contracts / why:** Dependency resolution must complete before marking done; backup preserves board state.

**AI fast-read:** `haftkhan_controller.dart`; `models.dart` for task shapes.
