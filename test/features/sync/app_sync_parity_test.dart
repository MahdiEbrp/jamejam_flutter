// Parity port of tests/JameJam.Tests/AppSyncTests.cs (10 cases) — the `haftkhan sync` CLI
// verb's URL resolution, modes and safety gates, now driven through the sync screen's
// controller.
//
// Mapping, case by case:
//   Sync_WithoutAnyUrl_FailsWithGuidance  → 'no URL anywhere names the setting to save'
//   Sync_InsecureUrl_FailsBeforeAnyCall   → 'an insecure URL is refused before any call'
//   Sync_UnknownMode_Fails                → "unknown modes are refused like the CLI's --mode"
//   Sync_WithCustomUrl_ResolvesPrecedence_AndSyncs
//                                         → 'a typed URL beats the stored one and syncs'
//   Sync_UsesSettingUrl_WhenNoFlag        → 'the stored URL is used when nothing else is set'
//   Sync_EnvironmentUrl_OverridesSetting  → 'the environment URL overrides the stored one'
//   Sync_TokenFlowsFromEnvironment        → 'the bearer token comes from the environment'
//   Sync_PushRefusedWithoutForce          → 'a push over a differing remote needs confirmation'
//   Sync_TransportFailure_SurfacesMessage → 'a transport failure surfaces its message'
//   (plus the report line and the first-sync seed, asserted where they land)
//
// The CLI's `--url` flag is the URL field on the card: an unsaved value applies to that run
// only, and "Save URL" is what makes it outlive the run. Everything else — the precedence,
// the modes, the token source, the push gate — is the CLI's behaviour verbatim.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/divan/divan_service.dart';
import 'package:jamejam/features/divan/divan_store.dart';
import 'package:jamejam/features/haftkhan/haftkhan_service.dart';
import 'package:jamejam/features/haftkhan/models.dart';
import 'package:jamejam/features/haftkhan/task_repository.dart';
import 'package:jamejam/features/settings/memory_settings_store.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/settings/settings_controller.dart';
import 'package:jamejam/features/sync/sync_client.dart';
import 'package:jamejam/features/sync/sync_controller.dart';
import 'package:jamejam/features/sync/sync_models.dart';
import 'package:jamejam/features/sync/sync_options.dart';
import 'package:jamejam/features/sync/sync_targets.dart';
import 'package:jamejam/features/taqvim/taqvim_service.dart';
import 'package:jamejam/features/taqvim/taqvim_store.dart';

final _now = DateTime.utc(2026, 9, 19, 10);

/// The .NET suite's `StubSyncClient`: holds a remote document and records what it was sent.
class StubSyncClient implements SyncClient {
  StubSyncClient({this.remote});

  String? remote;
  String? lastUpload;

  @override
  Future<String?> get() async => remote;

  @override
  Future<void> put(String json) async {
    lastUpload = json;
    remote = json;
  }
}

/// The .NET suite's `ThrowingSyncClient`.
class ThrowingSyncClient implements SyncClient {
  @override
  Future<String?> get() async =>
      throw const SyncException('The sync remote is down.');

  @override
  Future<void> put(String json) async =>
      throw const SyncException('The sync remote is down.');
}

void main() {
  /// The harness both the CLI tests and the screen share: in-memory settings, a memory task
  /// store, and a recording client factory.
  Future<
    ({
      SyncController controller,
      MemoryTaskRepository tasks,
      List<String> endpoints,
      List<String?> tokens,
    })
  >
  build({
    Map<String, String> environment = const {},
    SyncClient? client,
    Map<String, String> settings = const {},
  }) async {
    final store = MemorySettingsStore();
    for (final entry in settings.entries) {
      await store.setValue(entry.key, entry.value);
    }

    final settingsController = SettingsController(store);
    final tasks = MemoryTaskRepository();
    final haftKhan = HaftKhanService(repository: tasks, clock: () => _now);
    final endpoints = <String>[];
    final tokens = <String?>[];
    final pad = MemoryDivanStore();
    final calendar = MemoryTaqvimStore();

    final controller = SyncController(
      targets: defaultSyncTargets(
        haftKhan: haftKhan,
        divan: DivanService(store: pad, clock: () => _now),
        divanStore: pad,
        taqvim: TaqvimService(store: calendar, clock: () => _now),
        taqvimStore: calendar,
        clock: () => _now,
      ),
      settings: settingsController,
      environment: (key) => environment[key] ?? '',
      clientFactory: (url, {token}) {
        endpoints.add(url);
        tokens.add(token);
        return client ?? StubSyncClient();
      },
    );

    await controller.load();
    return (
      controller: controller,
      tasks: tasks,
      endpoints: endpoints,
      tokens: tokens,
    );
  }

  /// A remote document holding one task — the .NET's `MakeRemoteBackup()`.
  String remoteWithOneTask() => jsonEncode({
    'version': 1,
    'exportedAt': '2026-09-19T00:00:00Z',
    'tasks': [
      {
        'id': 1,
        'title': 'remote',
        'notes': '',
        'priority': 1,
        'state': 0,
        'dueDate': null,
        'createdAt': _now.toIso8601String(),
        'updatedAt': _now.toIso8601String(),
        'completedAt': null,
        'project': '',
        'tags': <String>[],
        'effort': 0,
        'recurrence': 0,
        'recurrenceInterval': 1,
        'parentId': null,
        'uid': 'uid-remote',
      },
    ],
    'dependencies': <Object?>[],
  });

  test('no URL anywhere names the setting to save', () async {
    final harness = await build();
    final controller = harness.controller;

    final outcome = await controller.run('haftkhan');

    expect(outcome, isNull);
    expect(controller.error, contains('No sync URL'));
    expect(controller.error, contains(SyncDefaults.urlSettingKey));
  });

  test('an insecure URL is refused before any call', () async {
    final harness = await build();
    final controller = harness.controller;

    await controller.run('haftkhan', url: 'http://sync.example.com/x');

    expect(controller.error, contains('Insecure sync endpoint'));
    // Nothing was built, so nothing could have left the process.
    expect(controller.outcomeFor('haftkhan'), isNull);
  });

  test("unknown modes are refused like the CLI's --mode", () async {
    final harness = await build(
      settings: const {SettingKeys.syncUrl: 'https://x.test'},
    );
    final controller = harness.controller;

    final outcome = await controller.runWithModeText('haftkhan', 'teleport');

    expect(outcome, isNull);
    expect(controller.error, contains("Unknown sync mode 'teleport'"));
  });

  test('a typed URL beats the stored one and syncs', () async {
    final harness = await build(
      settings: const {SettingKeys.syncUrl: 'https://from-setting.test/x'},
      client: StubSyncClient(),
    );
    await harness.tasks.add(const NewTask(title: 'local'));

    final outcome = await harness.controller.run(
      'haftkhan',
      url: 'https://custom.test/x',
    );

    expect(outcome, isNotNull);
    // The CLI printed exactly this line for one local task and an empty remote.
    expect(
      outcome!.summary,
      'Merged: pulled 0, pushed 1 — 1 local task(s) now.',
    );
    expect(harness.endpoints, ['https://custom.test/x']);
    expect(harness.controller.error, isNull);
  });

  test('the first sync seeds the remote', () async {
    final harness = await build(
      settings: const {SettingKeys.syncUrl: 'https://x.test'},
      client: StubSyncClient(),
    );
    await harness.tasks.add(const NewTask(title: 'local'));

    final outcome = await harness.controller.run('haftkhan');

    expect(
      outcome!.firstSync,
      isFalse,
    ); // the task backup has no first-sync flag
    expect(outcome.remoteWritten, isTrue);
  });

  test('the stored URL is used when nothing else is set', () async {
    final harness = await build(
      settings: const {SettingKeys.syncUrl: 'https://from-setting.test/x'},
      client: StubSyncClient(),
    );

    await harness.controller.run('haftkhan');

    expect(harness.endpoints, ['https://from-setting.test/x']);
  });

  test('the environment URL overrides the stored one', () async {
    final harness = await build(
      settings: const {SettingKeys.syncUrl: 'https://from-setting.test/x'},
      environment: const {'JAMEJAM_SYNC_URL': 'https://from-env.test/x'},
      client: StubSyncClient(),
    );

    await harness.controller.run('haftkhan');

    expect(harness.endpoints, ['https://from-env.test/x']);
    expect(harness.controller.environmentOverrides, isTrue);
    // The card still shows what a run would really use.
    expect(
      harness.controller.effectiveUrlFor('haftkhan'),
      'https://from-env.test/x',
    );
  });

  test('the bearer token comes from the environment', () async {
    final harness = await build(
      environment: const {'JAMEJAM_SYNC_TOKEN': 'env-token-4321'},
      client: StubSyncClient(),
    );
    await harness.tasks.add(const NewTask(title: 't'));

    await harness.controller.run(
      'haftkhan',
      mode: SyncMode.push,
      url: 'https://x.test',
    );

    expect(harness.tokens, ['env-token-4321']);
    expect(harness.controller.hasToken, isTrue);
  });

  test('a push over a differing remote needs confirmation', () async {
    final client = StubSyncClient(remote: remoteWithOneTask());
    final harness = await build(
      environment: const {'JAMEJAM_SYNC_URL': 'https://x.test'},
      client: client,
    );

    final outcome = await harness.controller.run(
      'haftkhan',
      mode: SyncMode.push,
    );

    final error = harness.controller.error ?? '';
    expect(outcome, isNull);
    expect(error.toLowerCase(), contains('pushing replaces them'));
    expect(client.lastUpload, isNull); // the remote was never touched
  });

  test('a transport failure surfaces its message', () async {
    final harness = await build(
      environment: const {'JAMEJAM_SYNC_URL': 'https://x.test'},
      client: ThrowingSyncClient(),
    );

    final outcome = await harness.controller.run('haftkhan');

    expect(outcome, isNull);
    expect(harness.controller.error, contains('remote is down'));
  });
}
