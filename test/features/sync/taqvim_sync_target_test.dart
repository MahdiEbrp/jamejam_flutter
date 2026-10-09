/// The calendar on the shared sync screen — the third card phase 10 adds to
/// [defaultSyncTargets], and the two-device convergence the `taqvim sync` verb promised,
/// driven through [TaqvimSyncRunner] exactly as the screen drives it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/sqlite_database.dart';
import 'package:jamejam/features/divan/divan_service.dart';
import 'package:jamejam/features/divan/divan_store.dart';
import 'package:jamejam/features/haftkhan/haftkhan_service.dart';
import 'package:jamejam/features/haftkhan/task_repository.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/sync/sync_client.dart';
import 'package:jamejam/features/sync/sync_models.dart';
import 'package:jamejam/features/sync/sync_targets.dart';
import 'package:jamejam/features/taqvim/sqlite_taqvim_store.dart';
import 'package:jamejam/features/taqvim/taqvim_service.dart';
import 'package:jamejam/features/taqvim/taqvim_store.dart';

final _now = DateTime.utc(2026, 9, 21, 9);

/// A blob server in a variable — the smallest remote any host can implement.
class _BlobClient implements SyncClient {
  String? document;

  @override
  Future<String?> get() async => document;

  @override
  Future<void> put(String json) async => document = json;
}

void main() {
  Future<TaqvimService> calendar(TaqvimStore store) async {
    final service = TaqvimService(store: store, clock: () => _now);
    await service.addEvent(
      title: 'Planning',
      start: DateTime.utc(2026, 9, 22, 10),
      end: DateTime.utc(2026, 9, 22, 11),
      reminders: const [10],
    );
    return service;
  }

  group('TaqvimSyncRunner', () {
    test('reports the calendar as the taqvim service', () {
      final store = MemoryTaqvimStore();
      final runner = TaqvimSyncRunner(
        service: TaqvimService(store: store, clock: () => _now),
        store: store,
      );
      expect(runner.service, 'taqvim');
    });

    test('an empty remote is seeded with the local calendar', () async {
      final store = MemoryTaqvimStore();
      final service = await calendar(store);
      final runner = TaqvimSyncRunner(service: service, store: store);
      final blob = _BlobClient();

      final outcome = await runner.run(
        blob,
        mode: SyncMode.merge,
        force: false,
        deviceId: 'device-a',
        deviceName: 'Test',
      );

      expect(outcome.firstSync, isTrue);
      expect(outcome.remoteWritten, isTrue);
      expect(outcome.applied, 0);
      expect(blob.document, contains('taqvim'));
      expect(blob.document, contains('Planning'));
    });

    test('two devices converge on one blob', () async {
      final storeA = MemoryTaqvimStore();
      final storeB = MemoryTaqvimStore();
      final serviceA = await calendar(storeA);
      final serviceB = TaqvimService(store: storeB, clock: () => _now);
      final blob = _BlobClient();

      await TaqvimSyncRunner(service: serviceA, store: storeA).run(
        blob,
        mode: SyncMode.merge,
        force: false,
        deviceId: 'device-a',
        deviceName: 'A',
      );
      final second = await TaqvimSyncRunner(service: serviceB, store: storeB)
          .run(
            blob,
            mode: SyncMode.merge,
            force: false,
            deviceId: 'device-b',
            deviceName: 'B',
          );

      expect(second.applied, 1); // the event arrived
      final mirrored = (await storeB.listEvents()).single;
      expect(mirrored.title, 'Planning');
      expect(mirrored.reminders, [10]);

      // A second run on the first device changes nothing: the states already agree.
      final third = await TaqvimSyncRunner(service: serviceA, store: storeA)
          .run(
            blob,
            mode: SyncMode.merge,
            force: false,
            deviceId: 'device-a',
            deviceName: 'A',
          );
      expect(third.applied, 0);
    });

    test('a run against another service is refused', () async {
      final store = MemoryTaqvimStore();
      final service = await calendar(store);
      final blob = _BlobClient()
        ..document = jsonEncode({
          'protocol': 'jamejam.sync/1',
          'service': 'divan',
          'deviceId': 'device-a',
          'deviceName': 'A',
          'updatedAt': _now.toIso8601String(),
          'payload': '{"notebooks":[],"notes":[],"tombstones":[]}',
        });

      await expectLater(
        TaqvimSyncRunner(service: service, store: store).run(
          blob,
          mode: SyncMode.merge,
          force: false,
          deviceId: 'device-b',
          deviceName: 'B',
        ),
        throwsA(isA<SyncException>()),
      );
    });

    test('the target list ends with the calendar and its own URL key', () {
      final store = MemoryTaqvimStore();
      final targets = defaultSyncTargets(
        haftKhan: HaftKhanService(
          repository: MemoryTaskRepository(),
          clock: () => _now,
        ),
        divan: DivanService(store: MemoryDivanStore(), clock: () => _now),
        divanStore: MemoryDivanStore(),
        taqvim: TaqvimService(store: store, clock: () => _now),
        taqvimStore: store,
        clock: () => _now,
      );

      expect(targets.map((target) => target.id), [
        'haftkhan',
        'divan',
        'taqvim',
      ]);
      expect(targets.last.settingKey, SettingKeys.taqvimSyncUrl);
      expect(targets.last.service, 'taqvim');
    });

    test('the SQLite calendar syncs through the same runner', () async {
      SqliteBootstrap.ensure();
      final directory = Directory.systemTemp.createTempSync('taqvim-sync');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });

      final path = '${directory.path}/taqvim.db';
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      addTearDown(store.close);
      final service = await calendar(store);
      final blob = _BlobClient();

      final outcome = await TaqvimSyncRunner(service: service, store: store)
          .run(
            blob,
            mode: SyncMode.merge,
            force: false,
            deviceId: 'device-a',
            deviceName: 'A',
          );
      expect(outcome.firstSync, isTrue);
      expect(blob.document, contains('Planning'));
    });
  });
}
