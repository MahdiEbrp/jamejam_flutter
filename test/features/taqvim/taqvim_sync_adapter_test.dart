/// Parity suite for [TaqvimSyncAdapter] — mirrors
/// `tests/JameJam.Tests/Taqvim/TaqvimSyncAdapterTests.cs`: canonical captures,
/// last-write-wins, tombstone rules, apply alignment and two-device convergence.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/divan/divan_sync_adapter.dart'
    show SyncEngine, SyncRun;
import 'package:jamejam/features/sync/sync_client.dart';
import 'package:jamejam/features/sync/sync_models.dart';
import 'package:jamejam/features/taqvim/models.dart';
import 'package:jamejam/features/taqvim/taqvim_options.dart';
import 'package:jamejam/features/taqvim/taqvim_service.dart';
import 'package:jamejam/features/taqvim/taqvim_store.dart';
import 'package:jamejam/features/taqvim/taqvim_sync_adapter.dart';

final _t0 = DateTime.utc(2026, 9, 20, 12);
final _t1 = _t0.add(const Duration(minutes: 10));
final _t2 = _t0.add(const Duration(minutes: 20));

const _rails = TaqvimOptions(maxEvents: 100);

const _alpha = '11111111-1111-7111-8111-111111111111';
const _beta = '22222222-2222-7222-8222-222222222222';
const _other = '33333333-3333-7333-8333-333333333333';

/// A shared JSON document — the smallest server any host can implement.
class BlobClient implements SyncClient {
  String? document;

  @override
  Future<String?> get() async => document;

  @override
  Future<void> put(String json) async => document = json;
}

void main() {
  TaqvimEvent event(
    String title,
    String syncId,
    DateTime updated, {
    String start = '2026-09-22T10:00:00.000Z',
  }) {
    final from = DateTime.parse(start);
    return TaqvimEvent(
      id: 0,
      calendar: 'Work',
      title: title,
      location: 'Room 4',
      notes: '',
      tags: 'team',
      start: from,
      end: from.add(const Duration(hours: 1)),
      isAllDay: false,
      rule: null,
      reminders: const [10],
      createdAt: _t0,
      updatedAt: updated,
      syncId: syncId,
    );
  }

  TaqvimService serviceFor(MemoryTaqvimStore store, DateTime now) =>
      TaqvimService(store: store, clock: () => now, options: _rails);

  TaqvimSyncAdapter adapterFor(MemoryTaqvimStore store) =>
      TaqvimSyncAdapter(service: serviceFor(store, _t2), store: store);

  Map<String, Object?> wireEvent(
    String syncId,
    String title,
    DateTime updated, {
    String start = '2026-09-22T10:00:00.000Z',
  }) {
    final from = DateTime.parse(start);
    return {
      'syncId': syncId,
      'calendar': 'Work',
      'title': title,
      'location': 'Room 4',
      'notes': '',
      'tags': '',
      'start': from.toIso8601String(),
      'end': from.add(const Duration(hours: 1)).toIso8601String(),
      'isAllDay': false,
      'reminders': <int>[10],
      'createdAt': _t0.toIso8601String(),
      'updatedAt': updated.toIso8601String(),
    };
  }

  Map<String, Object?> wireTombstone(String syncId, DateTime deletedAt) => {
    'syncId': syncId,
    'deletedAt': deletedAt.toIso8601String(),
  };

  String payload(
    List<Map<String, Object?>> events,
    List<Map<String, Object?>> tombstones,
  ) => jsonEncode({'events': events, 'tombstones': tombstones});

  /// One merge-pull-push exchange against a shared blob, exactly like the app flow.
  Future<void> syncOnce(
    MemoryTaqvimStore store,
    TaqvimService service,
    DateTime now,
    BlobClient blob,
  ) async {
    final adapter = TaqvimSyncAdapter(service: service, store: store);
    await SyncEngine.run(
      blob,
      adapter,
      deviceId: 'device-${store.hashCode}',
      deviceName: 'Test',
      mode: SyncMode.merge,
      now: now,
    );
  }

  group('TaqvimSyncAdapter', () {
    test(
      'capture is canonically ordered — two stores with different row ids match',
      () async {
        final storeA = MemoryTaqvimStore();
        final storeB = MemoryTaqvimStore();

        // Device A: Alpha arrives first; device B: Beta arrives first.
        await storeA.addEvent(event('Alpha', _alpha, _t1));
        await storeA.addEvent(event('Beta', _beta, _t1));
        await storeB.addEvent(event('Beta', _beta, _t1));
        await storeB.addEvent(event('Alpha', _alpha, _t1));

        expect(
          await adapterFor(storeA).capture(),
          await adapterFor(storeB).capture(),
        );
      },
    );

    test('merge keeps the newer edit (last write wins)', () async {
      final store = MemoryTaqvimStore();
      final adapter = adapterFor(store);

      final local = payload([wireEvent(_other, 'Old title', _t1)], const []);
      final remote = payload([wireEvent(_other, 'New title', _t2)], const []);

      final merged = await adapter.merge(local, remote, 'a', 'b');
      expect(merged, contains('New title'));
      expect(merged, isNot(contains('Old title')));
    });

    test('merge of an exact tie is deterministic on both devices', () async {
      final store = MemoryTaqvimStore();
      final adapter = adapterFor(store);

      final left = payload([wireEvent(_other, 'Alpha', _t1)], const []);
      final right = payload([wireEvent(_other, 'Beta', _t1)], const []);

      expect(
        await adapter.merge(left, right, 'a', 'b'),
        await adapter.merge(right, left, 'b', 'a'),
      );
    });

    test('merge — a tombstone beats an equally old event', () async {
      final store = MemoryTaqvimStore();
      final adapter = adapterFor(store);

      final events = payload([wireEvent(_other, 'Alive', _t1)], const []);
      final tombstoned = payload(const [], [wireTombstone(_other, _t1)]);

      final merged = await adapter.merge(events, tombstoned, 'a', 'b');
      expect(merged, isNot(contains('Alive')));
    });

    test('merge — a newer edit resurrects from a tombstone', () async {
      final store = MemoryTaqvimStore();
      final adapter = adapterFor(store);

      final events = payload([wireEvent(_other, 'Revived', _t2)], const []);
      final tombstoned = payload(const [], [wireTombstone(_other, _t1)]);

      final merged = await adapter.merge(events, tombstoned, 'a', 'b');
      expect(merged, contains('Revived'));
    });

    test('merge ignores empty sync ids', () async {
      final store = MemoryTaqvimStore();
      final adapter = adapterFor(store);
      final empty = payload(const [], const []);
      final merged = await adapter.merge(empty, empty, 'a', 'b');
      expect(merged.replaceAll(' ', ''), contains('"events":[]'));
    });

    test('merge of invalid json throws SyncException', () async {
      await expectLater(
        adapterFor(MemoryTaqvimStore()).merge('{bad', '{bad', 'a', 'b'),
        throwsA(isA<SyncException>()),
      );
    });

    test('full cycle — insert, update, delete converges', () async {
      // Device A creates; both sync; B edits; both sync; B deletes; both sync.
      final clockA = _t0;
      final clockB = _t0.add(const Duration(seconds: 1));
      final storeA = MemoryTaqvimStore();
      final storeB = MemoryTaqvimStore();
      final serviceA = serviceFor(storeA, clockA);
      final serviceB = serviceFor(storeB, clockB);
      final blob = BlobClient();

      final created = await serviceA.addEvent(
        title: 'Planning',
        start: DateTime.parse('2026-09-22T10:00:00.000Z'),
        end: DateTime.parse('2026-09-22T11:00:00.000Z'),
        reminders: const [10],
      );

      await syncOnce(storeA, serviceA, clockA, blob);
      await syncOnce(storeB, serviceB, clockB, blob);
      expect(await storeB.listEvents(), hasLength(1));

      await serviceB.reschedule(
        created.id,
        DateTime.parse('2026-09-22T14:00:00.000Z'),
      );
      await syncOnce(storeB, serviceB, clockB, blob);
      await syncOnce(storeA, serviceA, clockA, blob);
      expect((await storeA.findEvent(created.id))!.title, 'Planning');
      expect((await storeA.findEvent(created.id))!.start.hour, 14);

      await serviceB.delete(created.id);
      await syncOnce(storeB, serviceB, clockB, blob);
      await syncOnce(storeA, serviceA, clockA, blob);
      expect(await storeA.listEvents(), isEmpty);
      expect(await storeB.listEvents(), isEmpty);

      // Both captures are byte-identical after convergence.
      expect(
        await TaqvimSyncAdapter(service: serviceA, store: storeA).capture(),
        await TaqvimSyncAdapter(service: serviceB, store: storeB).capture(),
      );
    });

    test(
      'full cycle — both delete the same event and tombstone times converge',
      () async {
        final clockA = _t0;
        final clockB = _t0.add(const Duration(seconds: 1));
        final storeA = MemoryTaqvimStore();
        final storeB = MemoryTaqvimStore();
        final serviceA = serviceFor(storeA, clockA);
        final serviceB = serviceFor(storeB, clockB);
        final blob = BlobClient();

        final created = await serviceA.addEvent(
          title: 'Shared',
          start: DateTime.parse('2026-09-22T10:00:00.000Z'),
          end: DateTime.parse('2026-09-22T11:00:00.000Z'),
        );
        await syncOnce(storeA, serviceA, clockA, blob);
        await syncOnce(storeB, serviceB, clockB, blob);

        await serviceA.delete(created.id);
        await serviceB.delete(created.id);
        await syncOnce(storeA, serviceA, clockA, blob);
        await syncOnce(storeB, serviceB, clockB, blob);
        await syncOnce(storeA, serviceA, clockA, blob);

        final tombA = (await storeA.getTombstones()).single;
        final tombB = (await storeB.getTombstones()).single;
        expect(tombA.syncId, tombB.syncId);
        expect(tombA.deletedAt, tombB.deletedAt);

        expect(
          await TaqvimSyncAdapter(service: serviceA, store: storeA).capture(),
          await TaqvimSyncAdapter(service: serviceB, store: storeB).capture(),
        );
      },
    );

    test('full cycle — reminders and rules travel', () async {
      final clockA = _t0;
      final clockB = _t0.add(const Duration(seconds: 1));
      final storeA = MemoryTaqvimStore();
      final storeB = MemoryTaqvimStore();
      final serviceA = serviceFor(storeA, clockA);
      final serviceB = serviceFor(storeB, clockB);
      final blob = BlobClient();

      await serviceA.addEvent(
        title: 'Yoga',
        start: DateTime.parse('2026-09-23T08:00:00.000Z'),
        end: DateTime.parse('2026-09-23T09:15:00.000Z'),
        tags: 'health',
        rule: const Recurrence(
          RecurrenceKind.weekly,
          onWeekdays: [3],
          count: 10,
        ),
        reminders: const [30, 5],
      );

      await syncOnce(storeA, serviceA, clockA, blob);
      await syncOnce(storeB, serviceB, clockB, blob);

      final mirrored = (await storeB.listEvents()).single;
      expect(mirrored.title, 'Yoga');
      expect(mirrored.reminders, [5, 30]);
      expect(mirrored.tags, 'health');
      expect(mirrored.rule!.kind, RecurrenceKind.weekly);
    });

    test('apply pushes one undo snapshot and counts the changes', () async {
      final store = MemoryTaqvimStore();
      final service = serviceFor(store, _t2);
      final adapter = TaqvimSyncAdapter(service: service, store: store);
      final incoming = payload([
        wireEvent(_other, 'From afar', _t1, start: '2026-09-25T09:00:00.000Z'),
      ], const []);

      expect(await adapter.apply(incoming), 1);
      expect(await store.undoCount, 1); // one snapshot reverts the whole apply
      expect(await store.listEvents(), hasLength(1));
    });

    test('apply — a local event dropped by the merge is deleted', () async {
      final store = MemoryTaqvimStore();
      final service = serviceFor(store, _t0);
      final doomed = await service.addEvent(
        title: 'Doomed',
        start: DateTime.parse('2026-09-22T10:00:00.000Z'),
        end: DateTime.parse('2026-09-22T11:00:00.000Z'),
      );

      final adapter = TaqvimSyncAdapter(
        service: serviceFor(store, _t2),
        store: store,
      );
      final incoming = payload(const [], [wireTombstone(doomed.syncId, _t1)]);

      expect(await adapter.apply(incoming), 1);
      expect(await store.listEvents(), isEmpty);
      final tombstone = (await store.getTombstones()).single;
      expect(tombstone.syncId, doomed.syncId);
      expect(tombstone.deletedAt, _t1);
    });

    test('apply aligns tombstone timestamps with the payload', () async {
      final store = MemoryTaqvimStore();
      final adapter = adapterFor(store);
      await store.upsertTombstone(
        TaqvimTombstone(syncId: _other, deletedAt: _t0), // stale local time
      );

      final incoming = payload(const [], [wireTombstone(_other, _t2)]);
      await adapter.apply(incoming);

      expect((await store.getTombstones()).single.deletedAt, _t2);
    });

    test('the service name is taqvim', () {
      expect(adapterFor(MemoryTaqvimStore()).service, 'taqvim');
    });

    test('a sync run reports what happened', () async {
      final store = MemoryTaqvimStore();
      final service = serviceFor(store, _t0);
      await service.addEvent(
        title: 'Seeded',
        start: DateTime.parse('2026-09-22T10:00:00.000Z'),
        end: DateTime.parse('2026-09-22T11:00:00.000Z'),
      );
      final blob = BlobClient();
      final run = await SyncEngine.run(
        blob,
        TaqvimSyncAdapter(service: service, store: store),
        deviceId: 'device-a',
        deviceName: 'Test',
        now: _t0,
      );
      expect(run, isA<SyncRun>());
      expect(run.firstSync, isTrue);
      expect(run.pushed, isTrue);
      expect(blob.document, contains('taqvim'));
    });
  });
}
