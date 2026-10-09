import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/jamejam_paths.dart';
import '../core/secret_store.dart';
import '../core/sqlite_database.dart';
import '../features/anahita/anahita_defaults.dart';
import '../features/anahita/anahita_options.dart';
import '../features/anahita/anahita_service.dart';
import '../features/anahita/open_meteo_client.dart';
import '../features/anahita/weather_controller.dart';
import '../features/divan/divan_controller.dart';
import '../features/divan/divan_options.dart';
import '../features/divan/divan_service.dart';
import '../features/divan/divan_store.dart';
import '../features/divan/pad_assistant.dart';
import '../features/divan/sqlite_divan_store.dart';
import '../features/ganjoor/ganjoor_controller.dart';
import '../features/ganjoor/ganjoor_options.dart';
import '../features/ganjoor/ganjoor_service.dart';
import '../features/ganjoor/ganjoor_store.dart';
import '../features/ganjoor/sqlite_ganjoor_store.dart';
import '../features/greeter/greeter_controller.dart';
import '../features/haftkhan/haftkhan_controller.dart';
import '../features/haftkhan/haftkhan_service.dart';
import '../features/haftkhan/models.dart';
import '../features/haftkhan/sqlite_task_repository.dart';
import '../features/haftkhan/task_repository.dart';
import '../features/raz/raz_options.dart';
import '../features/raz/security_assistant.dart';
import '../features/raz/sqlite_vault_store.dart';
import '../features/raz/vault_controller.dart';
import '../features/raz/vault_service.dart';
import '../features/raz/vault_store.dart';
import '../features/settings/settings_controller.dart';
import '../features/settings/settings_store.dart';
import '../features/settings/sqlite_settings_store.dart';
import '../features/soroush/ai_funnel.dart';
import '../features/soroush/soroush_controller.dart';
import '../features/sync/sync_client.dart';
import '../features/sync/sync_controller.dart';
import '../features/sync/sync_options.dart';
import '../features/sync/sync_targets.dart';
import '../features/taqvim/sqlite_taqvim_store.dart';
import '../features/taqvim/taqvim_controller.dart';
import '../features/taqvim/taqvim_service.dart';
import '../features/taqvim/taqvim_store.dart';

/// The composition root.
///
/// The .NET CLI registers every service in `Program.cs` and injects them into `App`. This is
/// the same idea in Dart: bootstrap the platform bits (SQLite factory, toolbox directory,
/// secret store), build the services once, and hand the whole graph to the widget tree
/// through `provider` — so every screen receives its dependencies instead of reaching for
/// globals, and tests can compose the same graph with fakes.
class AppServices {
  AppServices({
    required this.databasePaths,
    required this.settingsStore,
    required this.settings,
    required this.secrets,
    required this.funnel,
    required this.soroush,
    required this.greeter,
    required this.haftKhan,
    required this.taskRepository,
    required this.anahita,
    required this.raz,
    required this.divan,
    required this.divanStore,
    required this.ganjoor,
    required this.ganjoorStore,
    required this.taqvim,
    required this.taqvimStore,
    required this.sync,
    required this.httpClient,
  });

  /// Where each service's SQLite file lives.
  final JameJamDatabases databasePaths;

  /// The encrypted vault screen state (Step 7).
  final VaultController raz;

  /// The notes pad screen state (Step 8).
  final DivanController divan;

  /// The pad store in use (SQLite in the app, memory in tests).
  final DivanStore divanStore;

  /// The wallet screen state (Step 6).
  final GanjoorController ganjoor;

  /// The wallet store in use (SQLite in the app, memory in tests).
  final GanjoorStore ganjoorStore;

  /// The calendar screen state (Step 10).
  final TaqvimController taqvim;

  /// The calendar store in use (SQLite in the app, memory in tests).
  final TaqvimStore taqvimStore;

  /// The toolbox-wide sync screen state (Step 9).
  final SyncController sync;

  /// The settings store in use (SQLite in the app, memory in tests).
  final SettingsStore settingsStore;

  /// Live settings, cached for the UI.
  final SettingsController settings;

  /// Secret storage — keychain, with the environment taking precedence.
  final SecretStore secrets;

  /// The single AI path.
  final AiFunnel funnel;

  /// Soroush screen state.
  final SoroushController soroush;

  /// Greeter screen state.
  final GreeterController greeter;

  /// Haft Khan screen state (backed by the SQLite task store).
  final HaftKhanController haftKhan;

  /// The task store in use (SQLite in the app, memory in tests).
  final TaskRepository taskRepository;

  /// Anahita screen state (weather, backed by the Open-Meteo transport).
  final WeatherController anahita;

  /// Shared HTTP client (closed on shutdown).
  final http.Client httpClient;

  /// Builds the production graph.
  ///
  /// Fails loudly if the platform cannot provide a keychain — the app still runs, but the
  /// AI key area will report that it cannot persist secrets rather than pretending to.
  static Future<AppServices> bootstrap() async {
    SqliteBootstrap.ensure();
    await JameJamPaths.ensureRoot();

    final paths = await JameJamDatabases.resolve();
    return fromPaths(paths);
  }

  /// Builds the graph for explicit paths — what tests and the desktop "portable" mode use.
  static Future<AppServices> fromPaths(
    JameJamDatabases paths, {
    SettingsStore? settingsStoreOverride,
    SecretStore? secretStoreOverride,
    http.Client? httpClient,
    TaskRepository? taskRepository,
    VaultStore? vaultStore,
    RazOptions? razOptions,
    DivanStore? divanStore,
    DivanOptions? divanOptions,
    GanjoorStore? ganjoorStore,
    GanjoorOptions? ganjoorOptions,
    SyncClientFactory? syncClientFactory,
    TaqvimStore? taqvimStore,
  }) async {
    SqliteBootstrap.ensure();

    final store = settingsStoreOverride ?? SqliteSettingsStore(paths.settings);
    final settings = SettingsController(store);
    await settings.load();

    final secrets = SafeSecretStore(
      EnvironmentFirstSecretStore(secretStoreOverride ?? KeychainSecretStore()),
    );

    final client = httpClient ?? http.Client();
    // The production transport, unless a test supplies its own (the same seam the CLI got
    // from its `syncClientFactory` constructor argument).
    final syncClients =
        syncClientFactory ??
        (String url, {String? token}) => HttpSyncClient(
          httpClient: client,
          options: SyncOptions(endpoint: url, bearerToken: token),
        );
    final funnel = AiFunnel(
      settings: settings,
      secrets: secrets,
      httpClient: client,
    );

    final tasks = taskRepository ?? SqliteTaskRepository(paths.haftkhan);
    final haftKhanService = HaftKhanService(
      repository: tasks,
      clock: DateTime.now,
    );

    final weatherClient = OpenMeteoClient(
      httpClient: client,
      options: AnahitaOptions.fromEnvironment(),
    );
    final anahita = WeatherController(
      service: AnahitaService(
        client: weatherClient,
        clock: DateTime.now,
        savedLocation: () => settings.read(AnahitaDefaults.locationSettingKey),
      ),
      settings: settings,
      funnel: funnel,
      taskRepository: tasks,
    );

    final vaultOptions =
        razOptions ?? RazOptions.fromEnvironment(Platform.environment);
    final raz = VaultController(
      service: VaultService(
        store: vaultStore ?? SqliteVaultStore(paths.raz),
        clock: DateTime.now,
        options: vaultOptions,
      ),
      settings: settings,
      secrets: secrets,
      funnel: funnel,
      assistant: SecurityAssistant(vaultOptions),
      environment: (key) => Platform.environment[key] ?? '',
    );

    final padOptions =
        divanOptions ?? DivanOptions.fromEnvironment(Platform.environment);
    final padStore = divanStore ?? SqliteDivanStore(paths.divan);
    if (padStore is SqliteDivanStore) {
      await padStore.initialize();
    }
    final divanService = DivanService(
      store: padStore,
      clock: DateTime.now,
      options: padOptions,
    );
    final divan = DivanController(
      service: divanService,
      settings: settings,
      funnel: funnel,
      assistant: PadAssistant(padOptions),
      // The CLI read the remote URL from its own flags; here it comes from settings, and
      // the token still comes from the environment only.
      syncClientFactory: syncClients,
      environment: (key) => Platform.environment[key] ?? '',
    );

    final walletOptions =
        ganjoorOptions ?? GanjoorOptions.fromEnvironment(Platform.environment);
    final walletStore = ganjoorStore ?? SqliteGanjoorStore(paths.ganjoor);
    if (walletStore is SqliteGanjoorStore) {
      await walletStore.initialize();
    }
    final ganjoor = GanjoorController(
      service: GanjoorService(
        store: walletStore,
        clock: DateTime.now,
        options: walletOptions,
      ),
      settings: settings,
      funnel: funnel,
      environment: (key) => Platform.environment[key] ?? '',
    );

    final calendarStore = taqvimStore ?? SqliteTaqvimStore(paths.taqvim);
    if (calendarStore is SqliteTaqvimStore) {
      await calendarStore.initialize();
    }
    final taqvimService = TaqvimService(
      store: calendarStore,
      clock: DateTime.now,
    );
    final taqvim = TaqvimController(
      service: taqvimService,
      settings: settings,
      funnel: funnel,
      // The CLI's `--due` flag listed Haft Khan's open tasks in the plan prompt.
      dueTasks: () async => [
        for (final task in await haftKhanService.list(TaskView.open))
          task.title,
      ],
    );

    // One screen drives every syncable service: the task list through its own merge verb,
    // the pad and the calendar through the shared engine.
    final sync = SyncController(
      targets: defaultSyncTargets(
        haftKhan: haftKhanService,
        divan: divanService,
        divanStore: padStore,
        taqvim: taqvimService,
        taqvimStore: calendarStore,
        clock: DateTime.now,
      ),
      settings: settings,
      environment: (key) => Platform.environment[key] ?? '',
      clientFactory: syncClients,
    );
    await sync.load();

    return AppServices(
      databasePaths: paths,
      settingsStore: store,
      settings: settings,
      secrets: secrets,
      funnel: funnel,
      soroush: SoroushController(funnel),
      greeter: GreeterController(settings: settings, funnel: funnel),
      haftKhan: HaftKhanController(service: haftKhanService, funnel: funnel),
      taskRepository: tasks,
      anahita: anahita,
      raz: raz,
      divan: divan,
      divanStore: padStore,
      ganjoor: ganjoor,
      ganjoorStore: walletStore,
      taqvim: taqvim,
      taqvimStore: calendarStore,
      sync: sync,
      httpClient: client,
    );
  }

  /// The provider tree every screen reads from.
  List<SingleChildWidget> providers() => [
    Provider<AppServices>.value(value: this),
    ChangeNotifierProvider<SettingsController>.value(value: settings),
    ChangeNotifierProvider<SoroushController>.value(value: soroush),
    ChangeNotifierProvider<GreeterController>.value(value: greeter),
    ChangeNotifierProvider<HaftKhanController>.value(value: haftKhan),
    ChangeNotifierProvider<WeatherController>.value(value: anahita),
    ChangeNotifierProvider<VaultController>.value(value: raz),
    ChangeNotifierProvider<DivanController>.value(value: divan),
    ChangeNotifierProvider<GanjoorController>.value(value: ganjoor),
    ChangeNotifierProvider<TaqvimController>.value(value: taqvim),
    ChangeNotifierProvider<SyncController>.value(value: sync),
  ];

  /// Releases the resources the graph owns.
  void dispose() {
    funnel.dispose();
    settings.dispose();
    soroush.dispose();
    greeter.dispose();
    haftKhan.dispose();
    anahita.dispose();
    raz.dispose();
    divan.dispose();
    ganjoor.dispose();
    sync.dispose();
  }
}
