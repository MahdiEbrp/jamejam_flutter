/// sync — see doc/sync.md and AGENTS.md
library;

import '../../l10n/generated/app_localizations.dart';
import '../divan/divan_defaults.dart';
import '../divan/divan_service.dart';
import '../divan/divan_store.dart';
import '../divan/divan_sync_adapter.dart';
import '../divan/models.dart' show DivanText;
import '../haftkhan/haftkhan_service.dart';
import '../settings/setting_keys.dart';
import '../taqvim/taqvim_service.dart';
import '../taqvim/taqvim_store.dart';
import '../taqvim/taqvim_sync_adapter.dart';
import 'sync_client.dart';
import 'sync_models.dart';

class SyncOutcome {
  const SyncOutcome({
    required this.mode,
    required this.applied,
    required this.remoteWritten,
    required this.firstSync,
    required this.total,
    required this.summary,
  });

  /// The mode that ran.
  final SyncMode mode;

  /// Records changed locally by the merge (0 when local was already current).
  final int applied;

  /// True when the remote document was (re)written.
  final bool remoteWritten;

  /// True when the remote was empty and this run seeded it.
  final bool firstSync;

  /// Records held locally after the run, when the service can count them.
  final int? total;

  /// The owning service's own summary line, verbatim (culture-invariant).
  final String summary;

  @override
  String toString() => summary;
}

abstract interface class SyncRunner {
  /// The service tag this runner exchanges (the envelope's service field).
  String get service;

  /// Runs one exchange, throwing [SyncException] for a transport, protocol, or safety failure.
  Future<SyncOutcome> run(
    SyncClient client, {
    required SyncMode mode,
    required bool force,
    required String deviceId,
    required String deviceName,
  });
}

class SyncTarget {
  const SyncTarget({
    required this.id,
    required this.settingKey,
    required this.title,
    required this.runner,
  });

  /// Stable id — also the service tag on the wire (`haftkhan`, `divan`, `taqvim`).
  final String id;

  /// The settings key holding this service's saved URL (`haftkhan.syncUrl`, …).
  final String settingKey;

  /// Localized name for the card.
  final String Function(AppLocalizations l10n) title;

  /// How a run for this service executes.
  final SyncRunner runner;

  /// The tag the envelopes carry.
  String get service => runner.service;
}

class HaftKhanSyncRunner implements SyncRunner {
  HaftKhanSyncRunner(this._service);

  final HaftKhanService _service;

  @override
  String get service => 'haftkhan';

  @override
  Future<SyncOutcome> run(
    SyncClient client, {
    required SyncMode mode,
    required bool force,
    required String deviceId,
    required String deviceName,
  }) async {
    // The task backup carries no device stamp, so the identity is not part of its wire
    // format — exactly like the CLI, where `haftkhan sync` never sent one either.
    final report = await _service.sync(client, mode: mode, force: force);
    return SyncOutcome(
      mode: report.mode,
      applied: report.pulled,
      remoteWritten: report.pushed > 0,
      firstSync: false,
      total: report.total,
      summary: report.describe(),
    );
  }
}

class DivanSyncRunner implements SyncRunner {
  DivanSyncRunner({
    required DivanService service,
    required DivanStore store,
    required DateTime Function() clock,
  }) : _service = service,
       _store = store,
       _clock = clock;

  final DivanService _service;
  final DivanStore _store;
  final DateTime Function() _clock;

  @override
  String get service => 'divan';

  @override
  Future<SyncOutcome> run(
    SyncClient client, {
    required SyncMode mode,
    required bool force,
    required String deviceId,
    required String deviceName,
  }) async {
    final adapter = DivanSyncAdapter(
      service: _service,
      store: _store,
      clock: _clock,
    );
    final run = await SyncEngine.run(
      client,
      adapter,
      deviceId: deviceId,
      // The CLI clipped the device name to the pad's own name rail before sealing.
      deviceName: DivanText.clip(
        deviceName,
        DivanDefaults.maxNotebookNameLength,
      ),
      mode: mode,
      force: force,
    );
    return SyncOutcome(
      mode: run.mode,
      applied: run.applied,
      remoteWritten: run.pushed,
      firstSync: run.firstSync,
      total: null,
      summary: run.describe(),
    );
  }
}

class TaqvimSyncRunner implements SyncRunner {
  TaqvimSyncRunner({required TaqvimService service, required TaqvimStore store})
    : _service = service,
      _store = store;

  final TaqvimService _service;
  final TaqvimStore _store;

  @override
  String get service => 'taqvim';

  @override
  Future<SyncOutcome> run(
    SyncClient client, {
    required SyncMode mode,
    required bool force,
    required String deviceId,
    required String deviceName,
  }) async {
    final adapter = TaqvimSyncAdapter(service: _service, store: _store);
    final run = await SyncEngine.run(
      client,
      adapter,
      deviceId: deviceId,
      deviceName: deviceName,
      mode: mode,
      force: force,
    );
    return SyncOutcome(
      mode: run.mode,
      applied: run.applied,
      remoteWritten: run.pushed,
      firstSync: run.firstSync,
      total: null,
      summary: run.describe(),
    );
  }
}

List<SyncTarget> defaultSyncTargets({
  required HaftKhanService haftKhan,
  required DivanService divan,
  required DivanStore divanStore,
  required TaqvimService taqvim,
  required TaqvimStore taqvimStore,
  required DateTime Function() clock,
}) => [
  SyncTarget(
    id: 'haftkhan',
    settingKey: SettingKeys.syncUrl,
    title: (l10n) => l10n.navHaftKhan,
    runner: HaftKhanSyncRunner(haftKhan),
  ),
  SyncTarget(
    id: 'divan',
    settingKey: SettingKeys.divanSyncUrl,
    title: (l10n) => l10n.navDivan,
    runner: DivanSyncRunner(service: divan, store: divanStore, clock: clock),
  ),
  SyncTarget(
    id: 'taqvim',
    settingKey: SettingKeys.taqvimSyncUrl,
    title: (l10n) => l10n.navTaqvim,
    runner: TaqvimSyncRunner(service: taqvim, store: taqvimStore),
  ),
];
