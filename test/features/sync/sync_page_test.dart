// The sync screen, end to end over the in-memory graph: the device identity, a card per
// service, saving a URL, a run that reports what it did, and the push confirmation that
// stands in for the CLI's `--force`.
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/haftkhan/models.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/sync/sync_client.dart';
import 'package:jamejam/features/sync/sync_models.dart';
import 'package:jamejam/features/sync/sync_page.dart';

import '../../helpers/test_harness.dart';

/// A transport that holds one document and remembers what it was sent.
class StubClient implements SyncClient {
  StubClient({this.remote});

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

/// A transport that is always down.
class ThrowingClient implements SyncClient {
  @override
  Future<String?> get() async =>
      throw const SyncException('The sync remote is down.');

  @override
  Future<void> put(String json) async =>
      throw const SyncException('The sync remote is down.');
}

/// A remote document holding one task, addressed by uid — what a second device would hold.
String remoteBackup() => jsonEncode({
  'version': 1,
  'exportedAt': '2026-09-19T00:00:00Z',
  'tasks': [
    {
      'id': 1,
      'title': 'remote task',
      'notes': '',
      'priority': 1,
      'state': 0,
      'dueDate': null,
      'createdAt': '2026-09-19T00:00:00Z',
      'updatedAt': '2026-09-19T00:00:00Z',
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

void main() {
  /// Pumps the sync screen with a stubbed transport.
  Future<TestHarness> pumpSync(
    WidgetTester tester, {
    SyncClient? client,
    Map<String, String> settings = const {},
  }) async {
    // The screen is a long list; a phone-sized surface would not build the cards below the
    // fold, and an unbuilt widget cannot be asserted on.
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = TestHarness(
      syncClientFactory: (url, {token}) => client ?? StubClient(),
    );
    await harness.build();
    for (final entry in settings.entries) {
      await harness.services.settings.set(entry.key, entry.value);
    }
    await harness.services.sync.load();

    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.wrap(const SyncPage()));
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('the screen lists every syncable service and this device', (
    tester,
  ) async {
    await pumpSync(tester);

    expect(find.text('Sync'), findsWidgets);
    expect(find.byKey(syncTargetKey('haftkhan')), findsOneWidget);
    expect(find.byKey(syncTargetKey('divan')), findsOneWidget);
    // Raz is deliberately absent — the vault has no adapter.
    expect(find.byKey(syncTargetKey('raz')), findsNothing);
    expect(find.byKey(syncDeviceIdKey), findsOneWidget);
    expect(find.textContaining('Raz never syncs'), findsOneWidget);
    expect(find.textContaining('No sync token'), findsOneWidget);
  });

  testWidgets('a device identity is minted by the first run and kept', (
    tester,
  ) async {
    final harness = await pumpSync(tester);

    // Nothing is written before a sync actually needs an identity.
    expect(harness.services.settings.value(SettingKeys.syncDeviceId), isNull);
    expect(find.textContaining('Created by the first sync'), findsOneWidget);
    expect(find.text('—'), findsWidgets);

    await harness.services.sync.run('haftkhan', url: 'https://x.test');

    final id = harness.services.settings.value(SettingKeys.syncDeviceId);
    expect(id, isNotNull);
    expect(id!.length, greaterThan(10));
    expect(
      harness.services.settings.value(SettingKeys.syncDeviceName),
      isNotNull,
    );

    // The same identity is reused by the next run.
    await harness.services.sync.run('haftkhan', url: 'https://x.test');
    expect(harness.services.settings.value(SettingKeys.syncDeviceId), id);
  });

  testWidgets('renaming this device is saved', (tester) async {
    final harness = await pumpSync(tester);

    await tester.enterText(find.byKey(syncDeviceNameKey), 'Workstation');
    await tester.tap(find.byKey(syncDeviceSaveKey));
    await tester.pumpAndSettle();

    expect(
      harness.services.settings.value(SettingKeys.syncDeviceName),
      'Workstation',
    );
    expect(find.textContaining('now called Workstation'), findsWidgets);
  });

  testWidgets('saving a URL stores it on the service\'s setting', (
    tester,
  ) async {
    final harness = await pumpSync(tester);

    await tester.enterText(
      find.byKey(syncUrlFieldKey('divan')),
      'https://pad.example.dev/sync',
    );
    await tester.tap(find.byKey(syncSaveUrlKey('divan')));
    await tester.pumpAndSettle();

    expect(
      harness.services.settings.value(SettingKeys.divanSyncUrl),
      'https://pad.example.dev/sync',
    );
    expect(find.textContaining('Sync URL saved'), findsWidgets);
  });

  testWidgets('an insecure URL is refused before any call', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var built = 0;
    final harness = TestHarness(
      syncClientFactory: (url, {token}) {
        built++;
        return StubClient();
      },
    );
    await harness.build();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.wrap(const SyncPage()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(syncUrlFieldKey('haftkhan')),
      'http://sync.example.com/x',
    );
    await tester.tap(find.byKey(syncRunKey('haftkhan')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Insecure sync endpoint'), findsWidgets);
    expect(built, 0); // no transport was even built
    expect(
      harness.services.settings.value(SettingKeys.syncUrl),
      isNull, // and nothing was saved
    );
  });

  testWidgets('a run reports what it did', (tester) async {
    final client = StubClient();
    final harness = await pumpSync(tester, client: client);
    await harness.services.taskRepository.add(
      const NewTask(title: 'local task'),
    );
    await harness.services.sync.run(
      'haftkhan',
      url: 'https://x.test',
    ); // warm run, as the report line is drawn from the last outcome
    await tester.pumpAndSettle();

    expect(find.byKey(syncReportKey('haftkhan')), findsOneWidget);
    expect(find.textContaining('Merged:'), findsWidgets);
    expect(client.lastUpload, isNotNull);
    expect(client.remote, contains('local task'));
  });

  testWidgets('a push over a differing remote asks before overwriting', (
    tester,
  ) async {
    final client = StubClient(remote: remoteBackup());
    await pumpSync(tester, client: client);

    await tester.enterText(
      find.byKey(syncUrlFieldKey('haftkhan')),
      'https://x.test',
    );
    // The mode dropdown is the CLI's `--mode push`.
    await tester.tap(find.byKey(syncModeKey('haftkhan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(syncRunKey('haftkhan')));
    await tester.pumpAndSettle();

    // Refused, and the question is on screen with the remote's own line.
    expect(find.byKey(syncConfirmPushKey), findsOneWidget);
    // The dialog and the feedback strip both carry the reason.
    expect(find.textContaining('pushing replaces them'), findsWidgets);
    expect(client.lastUpload, isNull);

    await tester.tap(find.text('Overwrite'));
    await tester.pumpAndSettle();

    expect(client.lastUpload, isNotNull);
    expect(find.byKey(syncConfirmPushKey), findsNothing);
  });

  testWidgets('cancelling the push question leaves the remote alone', (
    tester,
  ) async {
    final client = StubClient(remote: remoteBackup());
    await pumpSync(tester, client: client);

    await tester.enterText(
      find.byKey(syncUrlFieldKey('haftkhan')),
      'https://x.test',
    );
    await tester.tap(find.byKey(syncModeKey('haftkhan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(syncRunKey('haftkhan')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(client.lastUpload, isNull);
    expect(find.byKey(syncConfirmPushKey), findsNothing);
  });

  testWidgets('the pull mode never writes the remote', (tester) async {
    final client = StubClient(remote: remoteBackup());
    await pumpSync(tester, client: client);

    await tester.enterText(
      find.byKey(syncUrlFieldKey('haftkhan')),
      'https://x.test',
    );
    await tester.tap(find.byKey(syncModeKey('haftkhan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pull').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(syncRunKey('haftkhan')));
    await tester.pumpAndSettle();

    expect(client.lastUpload, isNull);
    // The task store words its own report ("Pulled 1 task(s) — 1 local task(s) now."), while
    // the shared engine says "Pulled: 1 record(s) changed locally." — both are shown as-is.
    expect(find.textContaining('Pulled'), findsWidgets);
    expect(find.textContaining('local task(s) now'), findsWidgets);
  });

  testWidgets('a transport failure is shown, not swallowed', (tester) async {
    await pumpSync(tester, client: ThrowingClient());

    await tester.enterText(
      find.byKey(syncUrlFieldKey('haftkhan')),
      'https://down.test/x',
    );
    await tester.tap(find.byKey(syncRunKey('haftkhan')));
    await tester.pumpAndSettle();

    expect(find.textContaining('remote is down'), findsWidgets);
    expect(find.byKey(syncReportKey('haftkhan')), findsNothing);
  });

  testWidgets('an empty remote is seeded by the first run', (tester) async {
    final client = StubClient();
    await pumpSync(tester, client: client);

    await tester.enterText(
      find.byKey(syncUrlFieldKey('haftkhan')),
      'https://fresh.test/x',
    );
    await tester.tap(find.byKey(syncRunKey('haftkhan')));
    await tester.pumpAndSettle();

    expect(client.lastUpload, isNotNull);
    expect(find.byKey(syncReportKey('haftkhan')), findsOneWidget);
  });

  testWidgets('the wire rules are spelled out on the screen', (tester) async {
    await pumpSync(tester);

    expect(find.textContaining('HTTPS only'), findsOneWidget);
    expect(find.textContaining('never stored or shown'), findsOneWidget);
    expect(find.textContaining('jamejam.sync/1'), findsOneWidget);
  });
}
