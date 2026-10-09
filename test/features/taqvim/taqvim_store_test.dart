/// Parity suite for the two [TaqvimStore] implementations — mirrors
/// `tests/JameJam.Tests/Taqvim/TaqvimStoreTests.cs` (`MemoryTaqvimStoreTests` and
/// `SqliteTaqvimStoreTests`).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/uids.dart';
import 'package:jamejam/features/taqvim/models.dart';
import 'package:jamejam/features/taqvim/sqlite_taqvim_store.dart';
import 'package:jamejam/features/taqvim/taqvim_defaults.dart';
import 'package:jamejam/features/taqvim/taqvim_store.dart';

final _t1 = DateTime.utc(2026, 9, 21, 9);
final _t2 = DateTime.utc(2026, 9, 21, 15);

TaqvimEvent _event(
  String title, {
  int id = 0,
  String? notes,
  String? location,
  Recurrence? rule,
  String tags = '',
  List<int> reminders = const [10],
  String syncId = '',
}) => TaqvimEvent(
  id: id,
  calendar: 'Work',
  title: title,
  location: location ?? '',
  notes: notes ?? '',
  tags: tags,
  start: _t1,
  end: _t2,
  isAllDay: false,
  rule: rule,
  reminders: reminders,
  createdAt: _t1,
  updatedAt: _t1,
  syncId: syncId,
);

void main() {
  group('MemoryTaqvimStore', () {
    late MemoryTaqvimStore store;

    setUp(() => store = MemoryTaqvimStore());

    test('add assigns ids and normalizes the sync id', () async {
      final first = await store.addEvent(_event('One'));
      final second = await store.addEvent(_event('Two'));
      expect(first.id, 1);
      expect(second.id, 2);
      expect(first.syncId, isNotEmpty);
      expect(first.syncId, isNot(second.syncId));
    });

    test('add preserves a supplied sync id', () async {
      final known = Uids.newUid();
      final ev = await store.addEvent(_event('One', syncId: known));
      expect(ev.syncId, known);
    });

    test('update with an unknown id throws', () async {
      await expectLater(
        store.updateEvent(_event('ghost', id: 42)),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('list orders by start', () async {
      await store.addEvent(
        _event(
          'Late',
        ).copyWith(start: _t2, end: _t2.add(const Duration(hours: 1))),
      );
      await store.addEvent(
        _event(
          'Early',
        ).copyWith(start: _t1.subtract(const Duration(hours: 1)), end: _t1),
      );
      expect((await store.listEvents()).map((ev) => ev.title), [
        'Early',
        'Late',
      ]);
    });

    test('search is AND logic and scores the title higher', () async {
      await store.addEvent(_event('Sprint planning', notes: 'nothing here'));
      await store.addEvent(
        _event('Retrospective', notes: 'talk about the sprint'),
      );
      expect(await store.searchIds('sprint', 10), hasLength(2));
      expect(await store.searchIds('sprint planning', 10), hasLength(1));
      expect(await store.searchIds('nonexistent', 10), isEmpty);
    });

    test('search rejects an empty query', () async {
      await expectLater(
        store.searchIds('  ', 10),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('undo stack is LIFO with depth trimming', () async {
      store.undoDepth = 2;
      await store.pushUndo('one');
      await store.pushUndo('two');
      await store.pushUndo('three');
      expect(await store.undoCount, 2);
      expect(await store.popUndo(), 'three');
      expect(await store.popUndo(), 'two');
      expect(await store.popUndo(), isNull);
    });

    test('undo depth zero drops everything', () async {
      store.undoDepth = 0;
      await store.pushUndo('one');
      expect(await store.undoCount, 0);
      expect(await store.popUndo(), isNull);
    });

    test('a negative undo depth throws', () {
      expect(
        () => store.undoDepth = -1,
        throwsA(
          isA<TaqvimException>().having(
            (ex) => ex.message,
            'message',
            'UndoDepth must not be negative.',
          ),
        ),
      );
    });

    test('pushing an empty undo snapshot throws', () async {
      await expectLater(store.pushUndo('   '), throwsA(isA<TaqvimException>()));
    });

    test('remove writes a tombstone and a restore clears it', () async {
      final ev = await store.addEvent(_event('Doomed'));
      expect(await store.removeEvent(ev.id, _t2), isTrue);
      expect(await store.removeEvent(ev.id, _t2), isFalse);

      final tombstone = (await store.getTombstones()).single;
      expect(tombstone.syncId, ev.syncId);
      expect(tombstone.deletedAt, _t2);

      await store.addEvent(_event('Doomed', syncId: ev.syncId));
      expect(await store.getTombstones(), isEmpty);
    });

    test('upserting a tombstone with an empty sync id is a no-op', () async {
      await store.upsertTombstone(TaqvimTombstone(syncId: '', deletedAt: _t1));
      expect(await store.getTombstones(), isEmpty);
    });

    test('replace restores ids and clears tombstones', () async {
      final ev = await store.addEvent(_event('One'));
      await store.removeEvent(ev.id, _t2);
      await store.replaceEvents([_event('One', id: ev.id, syncId: ev.syncId)]);

      final restored = (await store.listEvents()).single;
      expect(restored.id, ev.id);
      expect(await store.getTombstones(), isEmpty);

      final next = await store.addEvent(_event('Two'));
      expect(next.id, greaterThan(ev.id));
    });

    test(
      'null arguments are a runtime TypeError, not an ArgumentNullException',
      () async {
        // C# asserted ArgumentNullException for a null event / tombstone. Dart's sound null
        // safety makes the call unwritable — the dynamic path is the only way to get there.
        final dynamic memory = store;
        expect(() => memory.addEvent(null), throwsA(isA<TypeError>()));
        expect(() => memory.updateEvent(null), throwsA(isA<TypeError>()));
        expect(() => memory.replaceEvents(null), throwsA(isA<TypeError>()));
        expect(() => memory.upsertTombstone(null), throwsA(isA<TypeError>()));
      },
    );
  });

  group('SqliteTaqvimStore', () {
    late Directory directory;
    late String path;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('taqvim-sqlite-test');
      path = '${directory.path}/taqvim.db';
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    TaqvimEvent row(
      String title, {
      int id = 0,
      String? notes,
      String? location,
      Recurrence? rule,
      String syncId = '',
    }) => _event(
      title,
      id: id,
      notes: notes,
      location: location ?? 'Room 4',
      rule: rule,
      tags: 'team,work',
      reminders: const [10, 20],
      syncId: syncId,
    );

    test('persistence round-trips everything', () async {
      const rule = Recurrence(
        RecurrenceKind.weekly,
        interval: 2,
        onWeekdays: [1, 5],
        count: 10,
      );
      {
        final first = SqliteTaqvimStore(path);
        await first.initialize();
        await first.addEvent(row('Standup', notes: 'sync notes', rule: rule));
        await first.close();
      }

      final second = SqliteTaqvimStore(path);
      await second.initialize();
      try {
        final ev = (await second.listEvents()).single;
        expect(ev.title, 'Standup');
        expect(ev.location, 'Room 4');
        expect(ev.notes, 'sync notes');
        expect(ev.tags, 'team,work');
        expect(ev.reminders, [10, 20]);
        expect(ev.rule, isNotNull);
        expect(ev.rule!.kind, RecurrenceKind.weekly);
        expect(ev.rule!.interval, 2);
        expect(ev.rule!.weekdays, hasLength(2));
        expect(ev.rule!.count, 10);
        expect(ev.syncId, isNotEmpty);
      } finally {
        await second.close();
      }
    });

    test('add, update, delete and find', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        var ev = await store.addEvent(row('One'));
        expect(ev.id, 1);

        ev = ev.copyWith(
          title: 'One edited',
          updatedAt: ev.updatedAt.add(const Duration(minutes: 5)),
        );
        await store.updateEvent(ev);
        expect((await store.findEvent(ev.id))!.title, 'One edited');

        expect(
          await store.removeEvent(
            ev.id,
            ev.updatedAt.add(const Duration(minutes: 10)),
          ),
          isTrue,
        );
        expect(await store.findEvent(ev.id), isNull);
        expect(await store.removeEvent(ev.id, ev.updatedAt), isFalse);
      } finally {
        await store.close();
      }
    });

    test('update with an unknown id throws', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        await expectLater(
          store.updateEvent(row('ghost', id: 99)),
          throwsA(isA<TaqvimException>()),
        );
      } finally {
        await store.close();
      }
    });

    test('search finds by title, notes and location', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        await store.addEvent(row('Sprint review', notes: 'demo day'));
        await store.addEvent(row('Retrospective', notes: 'review the sprint'));
        await store.addEvent(
          row('Offsite', notes: 'elsewhere', location: 'review terrace'),
        );

        expect(await store.searchIds('review', 10), hasLength(3));
        expect(await store.searchIds('sprint demo', 10), hasLength(1));
        expect(await store.searchIds('terrace', 10), hasLength(1));
      } finally {
        await store.close();
      }
    });

    test('quotes in the query do not break the match', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        await store.addEvent(row('The "great" escape'));
        expect(await store.searchIds('"great"', 10), hasLength(1));
      } finally {
        await store.close();
      }
    });

    test('search rejects an empty query', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        await expectLater(
          store.searchIds(' ', 10),
          throwsA(isA<TaqvimException>()),
        );
      } finally {
        await store.close();
      }
    });

    test('the undo log persists and trims', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      store.undoDepth = 2;
      await store.pushUndo('one');
      await store.pushUndo('two');
      await store.pushUndo('three');
      expect(await store.undoCount, 2);
      await store.close();

      // A fresh instance sees the same log.
      final reopened = SqliteTaqvimStore(path);
      await reopened.initialize();
      try {
        expect(await reopened.undoCount, 2);
        expect(await reopened.popUndo(), 'three');
        expect(await reopened.undoCount, 1);
      } finally {
        await reopened.close();
      }
    });

    test('tombstones persist and align', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        final ev = await store.addEvent(row('Doomed'));
        await store.removeEvent(ev.id, _t1);

        final tombstone = (await store.getTombstones()).single;
        expect(tombstone.syncId, ev.syncId);

        // Upserting can re-time an existing deletion.
        await store.upsertTombstone(
          TaqvimTombstone(syncId: ev.syncId, deletedAt: _t2),
        );
        expect((await store.getTombstones()).single.deletedAt, _t2);
      } finally {
        await store.close();
      }
    });

    test('tombstones hide live events', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        final ev = await store.addEvent(row('Alive'));
        await store.upsertTombstone(
          TaqvimTombstone(syncId: ev.syncId, deletedAt: _t1),
        );
        expect(await store.getTombstones(), isEmpty);
      } finally {
        await store.close();
      }
    });

    test('replace clears and retracts', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        final ev = await store.addEvent(row('One'));
        await store.removeEvent(ev.id, _t1);
        await store.replaceEvents([row('One', id: ev.id, syncId: ev.syncId)]);
        expect(await store.getTombstones(), isEmpty);
        expect(await store.listEvents(), hasLength(1));
      } finally {
        await store.close();
      }
    });

    test('the database file is owner-only', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        expect(File(path).existsSync(), isTrue);
        if (Platform.isWindows) return; // Unix permission bits do not apply
        final mode = File(path).statSync().mode & 0x1FF;
        expect(mode & 0x077, 0, reason: 'group and other bits must be clear');
      } finally {
        await store.close();
      }
    });

    test(
      'null arguments are a runtime TypeError, not an ArgumentNullException',
      () async {
        final store = SqliteTaqvimStore(path);
        await store.initialize();
        try {
          final dynamic sqlite = store;
          expect(() => sqlite.addEvent(null), throwsA(isA<TypeError>()));
          expect(() => sqlite.updateEvent(null), throwsA(isA<TypeError>()));
          expect(() => sqlite.replaceEvents(null), throwsA(isA<TypeError>()));
          expect(() => sqlite.upsertTombstone(null), throwsA(isA<TypeError>()));
        } finally {
          await store.close();
        }
      },
    );
  });
}
