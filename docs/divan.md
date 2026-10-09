# divan — Poetry / Verses

**Role:** Poetry block display, filtering, markdown rendering.

**Key files / classes:**
- `divan_controller.dart` — `DivanController`.
- `divan_page.dart` — `DivanPage`, `_DivanPageState`.
- `divan_service.dart` — `DivanService`.
- `models.dart` — `DivanBlock`, `DivanBlockLine`, `DivanFilter`, `DivanOptions`, `DivanMarkdown`, `DivanDefaults`.

**Usage:** Load blocks → filter → render markdown.

**Contracts / why:** Blocks have lines with metadata; filter respects options; markdown uses normalized formatting.

**AI fast-read:** `divan_controller.dart` for logic; `models.dart` for data shape.
