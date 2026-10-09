import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jamejam/app/app.dart';
import 'package:jamejam/app/app_navigation.dart';
import 'package:jamejam/app/app_services.dart';
import 'package:jamejam/core/jamejam_paths.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/divan/divan_options.dart';
import 'package:jamejam/features/divan/divan_store.dart';
import 'package:jamejam/features/ganjoor/ganjoor_options.dart';
import 'package:jamejam/features/ganjoor/ganjoor_store.dart';
import 'package:jamejam/features/haftkhan/task_repository.dart';
import 'package:jamejam/features/raz/raz_defaults.dart';
import 'package:jamejam/features/raz/raz_options.dart';
import 'package:jamejam/features/raz/vault_store.dart';
import 'package:jamejam/features/settings/memory_settings_store.dart';
import 'package:jamejam/features/settings/settings_store.dart';
import 'package:jamejam/features/sync/sync_controller.dart';
import 'package:jamejam/features/taqvim/taqvim_store.dart';
import 'package:jamejam/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// Builds a fully wired app graph for widget tests: in-memory settings, an in-memory secret
/// store, and an HTTP client the test controls.
///
/// Every test composes the same services the real app does — nothing is stubbed out except
/// the two things that touch the outside world (the keychain and the network).
class TestHarness {
  TestHarness({
    SettingsStore? settingsStore,
    SecretStore? secretStore,
    http.Client? httpClient,
    TaskRepository? taskRepository,
    VaultStore? vaultStore,
    RazOptions? razOptions,
    DivanStore? divanStore,
    DivanOptions? divanOptions,
    GanjoorStore? ganjoorStore,
    GanjoorOptions? ganjoorOptions,
    TaqvimStore? taqvimStore,
    this.syncClientFactory,
  }) : settingsStore = settingsStore ?? MemorySettingsStore(),
       secretStore = secretStore ?? MemorySecretStore(),
       httpClient = httpClient ?? http.Client(),
       taskRepository = taskRepository ?? MemoryTaskRepository(),
       vaultStore = vaultStore ?? MemoryVaultStore(),
       razOptions =
           razOptions ??
           const RazOptions(
             iterations: RazDefaults.minIterations,
             autoLockMinutes: 0,
           ),
       divanStore = divanStore ?? MemoryDivanStore(),
       divanOptions = divanOptions ?? const DivanOptions(),
       ganjoorStore = ganjoorStore ?? MemoryGanjoorStore(),
       ganjoorOptions = ganjoorOptions ?? const GanjoorOptions(),
       taqvimStore = taqvimStore ?? MemoryTaqvimStore();

  final SettingsStore settingsStore;
  final SecretStore secretStore;
  final http.Client httpClient;

  /// The task store the Haft Khan engine writes to.
  ///
  /// Defaults to [MemoryTaskRepository]: widget tests run inside a fake-async zone, where the
  /// real SQLite (an FFI isolate) never gets to answer. The SQLite implementation has its own
  /// suite (`settings_stores_parity_test.dart`'s sibling, `task_repository_parity_test.dart`),
  /// where real async is available.
  final TaskRepository taskRepository;

  /// The vault store the Raz engine writes to.
  ///
  /// Defaults to [MemoryVaultStore] for the same reason as [taskRepository]: a widget test's
  /// fake-async zone never lets the SQLite FFI isolate answer. `SqliteVaultStore` has its own
  /// suite in `test/features/raz/vault_store_and_assistant_test.dart`.
  final VaultStore vaultStore;

  /// The vault options the Raz engine runs with.
  ///
  /// Two departures from the real graph, both about time:
  ///
  /// * the KDF runs at its 100 000-iteration floor instead of 210 000 — it is the slow part
  ///   of every unlock and no widget test needs the extra work;
  /// * auto-lock is off. The controller checks it on a periodic timer, and a widget test's
  ///   fake clock has no idle time to measure; the framework also fails a test that ends
  ///   with a timer still pending. The timer's own suite is
  ///   `test/features/raz/vault_controller_test.dart`.
  final RazOptions razOptions;

  /// The pad store the Divan engine writes to.
  ///
  /// Defaults to [MemoryDivanStore] for the same reason as [taskRepository]: a widget test's
  /// fake-async zone never lets the SQLite FFI isolate answer. `SqliteDivanStore` has its own
  /// suites (`divan_store_test.dart`, `divan_sync_test.dart`).
  final DivanStore divanStore;

  /// The pad options the Divan engine runs with.
  final DivanOptions divanOptions;

  /// The wallet store the Ganjoor engine writes to.
  ///
  /// Defaults to [MemoryGanjoorStore] for the same reason as [taskRepository]: a widget
  /// test's fake-async zone never lets the SQLite FFI isolate answer.
  /// `SqliteGanjoorStore` has its own suite in `ganjoor_backup_store_test.dart`.
  final GanjoorStore ganjoorStore;

  /// The wallet options the Ganjoor engine runs with.
  final GanjoorOptions ganjoorOptions;

  /// The calendar store the Taqvim engine writes to.
  ///
  /// Defaults to [MemoryTaqvimStore] for the same reason as [taskRepository]: a widget test's
  /// fake-async zone never lets the SQLite FFI isolate answer. `SqliteTaqvimStore` has its own
  /// suite in `test/features/taqvim/taqvim_store_test.dart`.
  final TaqvimStore taqvimStore;

  /// The transport the sync screen builds. Null means the real HTTP client — a widget test
  /// supplies a stub so a run never leaves the process.
  final SyncClientFactory? syncClientFactory;

  late final AppServices services;

  /// Builds the graph. Await before pumping widgets.
  Future<AppServices> build() async {
    final graph = await AppServices.fromPaths(
      const JameJamDatabases(
        settings: ':memory:',
        haftkhan: ':memory:',
        ganjoor: ':memory:',
        raz: ':memory:',
        divan: ':memory:',
        taqvim: ':memory:',
      ),
      settingsStoreOverride: settingsStore,
      secretStoreOverride: secretStore,
      httpClient: httpClient,
      taskRepository: taskRepository,
      vaultStore: vaultStore,
      razOptions: razOptions,
      divanStore: divanStore,
      divanOptions: divanOptions,
      ganjoorStore: ganjoorStore,
      ganjoorOptions: ganjoorOptions,
      taqvimStore: taqvimStore,
      syncClientFactory: syncClientFactory,
    );
    return services = graph;
  }

  /// Wraps [child] in every provider the screens expect.
  Widget wrap(Widget child, {String initialRoute = 'dashboard'}) {
    return MultiProvider(
      providers: [
        ...services.providers(),
        ChangeNotifierProvider<AppNavigation>(
          create: (_) => AppNavigation(initial: initialRoute),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  /// Wraps the whole shell — the way the app is actually launched.
  Widget wrapApp() {
    return MultiProvider(
      providers: [
        ...services.providers(),
        ChangeNotifierProvider<AppNavigation>(create: (_) => AppNavigation()),
      ],
      child: const JameJamApp(),
    );
  }

  void dispose() {
    services.dispose();
    httpClient.close();
  }
}
