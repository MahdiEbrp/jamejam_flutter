# JameJam — Flutter

A single Flutter app that ports the [.NET 10 JameJam toolbox](https://github.com/MahdiEbrp/JameJam)
— Greeter, Soroush AI, Settings, Haft Khan, Anahita, Ganjoor, Raz, Divan, Taqvim and Sync —
from a CLI into one local-first GUI, in **English and Persian (RTL)**.

**Version 0.3.0+1** — the same feature generation as the `.NET` toolbox it ports.

**Where this stands:** phases 0–10 are implemented and green (Settings · Soroush AI ·
Greeter · Haft Khan + Sync engine · Anahita weather · Ganjoor wallet · Raz encrypted vault ·
Divan notes pad · two-device sync · Taqvim calendar) — every step of the original toolbox's
10-step table, and the dashboard badge reads **10 of 10**.
**Phase 11 is complete** — the Persian display layer (Jalali dates, Persian digits), the
AI-surface audit and the two parity defects it caught, the accessibility pass (labelled
controls, semantics regions, a text-scale sweep that scrolls instead of clipping) and the
performance pass (two new SQL indexes behind a schema migration) are all in.
**Phase 12 is complete** — the migration door (a `.NET` backup file read straight into this
app's own stores, see below), eleven golden screenshots, the coverage gate, CI on the three
desktop targets, the changelog and the version. See
[`docs/CONVERSION_PLAN.md`](docs/CONVERSION_PLAN.md).

```bash
flutter pub get
flutter gen-l10n                       # regenerate lib/l10n/generated/ after ARB edits
flutter run -d linux                   # or: -d windows, -d macos, -d <android device>
flutter analyze                        # 0 issues
flutter test                           # 1400 tests, all green
```

## What works today

| Step | Feature | Screen | Notes |
|---|---|---|---|
| 3 | **Settings** | ✅ | SQLite-backed, secret-looking keys refused by name, theme + language switchers, filter, add/edit/clear |
| 2 | **Soroush AI** | ✅ | Provider registry, HTTPS-or-loopback policy, retries with jittered backoff, `Retry-After`, keychain-backed API key, call history |
| 1 | **Greeter** | ✅ | Local greeting + AI greeting through the funnel |
| 4 | **Haft Khan** | ✅ | Task store (SQLite), lists/board/matrix/report, dependencies, recurrence, undo, AI breakdown & summary, backup/restore, sync engine |
| 5 | **Anahita** | ✅ | Open-Meteo forecast + geocoding, current/forecast/hourly/alerts/best-days/plan views, unit switching, TTL cache, AI explain/ask/plan |
| 7 | **Raz** | ✅ | AES-256-GCM vault (PBKDF2-HMAC-SHA512, per-vault salt), keychain-or-env passphrase, auto-lock, entry editor with generator + RFC 6238 TOTP, strength/audit/coach (aggregate counts only), encrypted export/import — **no sync adapter, by design** |
| 8 | **Divan** | ✅ | Markdown notes pad: notebooks, tags, `[[wiki-links]]` + backlinks, FTS5 search with a `LIKE` fallback, checklists, daily journal, metrics, undo, stats, front-matter markdown export/import, a rendered preview, two-device sync, and AI summarize/title/tags/ask |
| 6 | **Ganjoor** | ✅ | Multi-currency wallet: accounts with balances, the ledger with live filters, budgets with warn/over rings, recurring bills with catch-up, goals, debts, monthly reports and net worth, an 80 %-warned budget check on every spend, snapshot undo, JSON backup + CSV import/export, and AI insights/categorize/ask |
| 9 | **Sync** | ✅ | Two-device sync on one screen: a card per service (Haft Khan through its own uid merge, the pad through the shared engine), `JAMEJAM_SYNC_URL` → saved URL precedence, merge/pull/push with a confirmation instead of `--force`, device identity minted by the first run, sealed `jamejam.sync/1` envelopes, and the last merge report — **Raz never syncs, by design** |
| 10 | **Taqvim** | ✅ | Calendar: recurring events, day/week/month/upcoming scopes, the free-window finder with clash warnings, natural-language capture, search, `.ics` import/export, an edit/delete flow with undo, reminders, Jalali month names beside the Gregorian dates, AI brief/plan/ask/capture, and the third sync card |

## Coming from the `.NET` toolbox

The `.NET` build left files on disk — a Haft Khan backup, a Ganjoor wallet, a Raz vault
bundle, a Taqvim `.ics` export. **Settings → Bring your data across** reads any of them: paste
the document (or its file), watch the preview name the kind and the version it recognised, and
import it through the *same readers and rails* the app's own files use, so an imported backup
cannot land differently from a native one.

The two format differences the port had to absorb are handled for you: the `.NET` wrote
**PascalCase** keys, and it serialised money as JSON **numbers** where the port's readers want
invariant strings. Divan (a folder of front-matter markdown, with its own transfer panel) and
the `~/.jamejam` SQLite files (read in place, same names and shapes) need no import step.

```bash
flutter test test/app/dotnet_migration_test.dart     # 14 cases: the readers, the rails, the door
```

## Architecture

```
lib/
├── main.dart                     # build the service graph, then run the app
├── app/
│   ├── app.dart                  # MaterialApp: locale, theme, shell
│   ├── app_services.dart         # the composition root (the .NET Program.cs equivalent)
│   ├── app_shell.dart            # responsive rail/drawer + the nine destinations
│   ├── app_navigation.dart       # current destination, shared
│   └── app_theme.dart            # Material 3 light/dark
├── core/                         # shared, feature-agnostic plumbing
│   ├── text_guard.dart           #   ← JameJam.Text
│   ├── sqlite_database.dart      #   ← JameJam.Data
│   ├── jamejam_paths.dart        #   one database per service
│   ├── secret_store.dart         #   keychain, env-first
│   └── exceptions.dart
├── features/
│   ├── dashboard/                # home + the step catalog
│   ├── settings/                 #   ← JameJam.Settings
│   ├── soroush/                  #   ← JameJam.Soroush
│   └── greeter/                  #   ← JameJam.Toolbox
├── l10n/                         # app_en.arb, app_fa.arb, generated/
└── widgets/                      # SectionCard, EmptyState, StatusChip
```

Layering is strict and one-directional:

```
screen ──▶ controller ──▶ service/guard ──▶ store ──▶ SQLite
                              └──▶ AiFunnel ──▶ SoroushGuard ──▶ HTTP
```

A screen never opens a database, and no feature reaches the network on its own — everything
that talks to a model goes through `AiFunnel`, exactly like the .NET side's single AI path.

## Where the data lives

One SQLite file per service, exactly like the CLI:

| Platform | Location | Override |
|---|---|---|
| Linux / macOS / Windows | `~/.jamejam/<service>.db` | `JAMEJAM_SETTINGS_DB`, `JAMEJAM_HAFTKHAN_DB`, … |
| Android / iOS | the app support directory (OS-sandboxed) | same environment names where a shell exists |

Databases are created `0600` inside a `0700` directory on Unix, use WAL journaling, and are
created once per lifetime. **Secrets never live in them**: API keys and sync tokens go to the
platform keychain (`flutter_secure_storage`) or, when present, the same environment variables
the CLI uses (`JAMEJAM_AI_API_KEY`, `JAMEJAM_SYNC_TOKEN`, `JAMEJAM_RAZ_PASSPHRASE`).

## Differences from the .NET original, and why

| Change | Reason |
|---|---|
| Sync `ISettingsStore` became async | Dart's SQLite drivers are async; storing futures leaking into callers would be worse |
| `SoroushOptions.endpoint` is nullable | The CLI resolved the endpoint above the options and could hand an Anthropic call the OpenAI URL if a setting was stale; resolving inside the client removes the failure mode |
| Provider names moved to `SoroushDefaults` | Dart has no partial classes; keeping the constants in one file avoids an import cycle |
| Secret-key refusal is *shown* | The CLI refuses a `settings set openai.apiKey` with a message; the GUI shows the same message in a snackbar so the rule is visible |
| `PromptMarkers` is a shared helper | The .NET features each built their marker blocks by hand; one helper means a new feature cannot forget the untrusted-data rule |
| Prompt labels reject `-` | A label containing `---` could forge a closing marker; caught by test, fixed in the implementation |

## Quality gates

```bash
dart format --output=none --set-exit-if-changed lib test   # formatting
flutter analyze --fatal-infos --fatal-warnings             # 0 issues, strict lints
flutter test                                               # 1400 tests, all green
flutter test --coverage && dart run tool/coverage.dart      # 90.1 %, floor 60 %
```

Cutting a build — CI's jobs, what each platform needs, signing, the icons and the launch
window — is in [`docs/RELEASE.md`](docs/RELEASE.md); the store listing copy, both locales and
the reviewer notes, is in [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md).

`analysis_options.yaml` matches the .NET project's bar: `flutter_lints` plus stricter
language modes (`strict-casts`, `strict-inference`, `strict-raw-types`) and a curated rule
set with the important rules promoted to **errors**, so a stale IDE run flags what CI would.

### Test parity with the .NET original

The original suite (1393 tests, all ten steps) was built and run here as the baseline.
Every phase has been mapped: the original's **all 75 test files** — 72 of them declaring the
**1393 cases `dotnet test` runs**, the other three support-only — are matched by
`test/**/*_parity_test.dart` and the phase suites, with the same inputs and the same
expected values. The case-by-case mapping, the thirteen defects the exercise exposed, and the
deliberate divergences are documented in [`docs/TEST_PARITY.md`](docs/TEST_PARITY.md).

```bash
flutter test test/features/soroush/soroush_guard_parity_test.dart   # one source file's cases
```

### End-to-end run

Phases 0–3 were also launched for real (`flutter run -d linux` on a virtual display) and
driven through the UI: settings persisted to `~/.jamejam/settings.db` (`0600`, schema v1),
a secret-looking key was refused on screen, the app switched to Persian/RTL, and a restart
came back in the chosen locale and theme. See [`docs/screenshots/`](docs/screenshots/) — that
run predates phases 4–10. `20-live-release-run.png` is the same thing done again at the end of
phase 12, this time with the packaged **release** binary (`flutter build linux --release`, run
on a virtual display with a fresh `$HOME`): it opens on the dashboard at **10 of 10**, and the
first run mints its own `~/.jamejam` databases (`0600`, one per service). `06`–`19` in the same
folder come from the golden suite
(`flutter test --update-goldens tool/screenshots/capture_test.dart`), which re-renders the
later screens through Flutter's own pipeline without a window server.

Tests compose the real service graph with only the outside world swapped for doubles — the
keychain (`MemorySecretStore`), the network (`MockClient`), the task and vault stores
(`MemoryTaskRepository`, `MemoryVaultStore`, because a widget test's fake-async zone never
lets the SQLite FFI isolate answer), and the vault's KDF at its 100 000-iteration floor — so a
passing test exercises the same guards and stores the app runs. See `test/helpers/test_harness.dart`.

Notable things the tests pin down: control-character stripping, the secret-key refusal, SQLite
permissions and schema-once behaviour, retry/backoff and `Retry-After` handling, API-key
scrubbing in provider error bodies, redirects staying off, untrusted-data markers, RTL
switching, and the responsive rail/drawer layouts.

## License

Same as the original project — see the repository's `LICENSE`.
