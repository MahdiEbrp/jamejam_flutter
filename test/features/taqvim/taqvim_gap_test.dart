/// Branch-completion suite for the whole Taqvim package — mirrors the remainder of
/// `tests/JameJam.Tests/Taqvim/TaqvimGapTests.cs` (its text, recurrence, ICS, prompt and
/// SQLite-branch halves; the capture/text halves live in `taqvim_core_test.dart`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/sync/sync_models.dart';
import 'package:jamejam/features/taqvim/models.dart';
import 'package:jamejam/features/taqvim/recurrence.dart';
import 'package:jamejam/features/taqvim/schedule_assistant.dart';
import 'package:jamejam/features/taqvim/sqlite_taqvim_store.dart';
import 'package:jamejam/features/taqvim/taqvim_defaults.dart';
import 'package:jamejam/features/taqvim/taqvim_ics.dart';
import 'package:jamejam/features/taqvim/taqvim_options.dart';
import 'package:jamejam/features/taqvim/taqvim_service.dart';
import 'package:jamejam/features/taqvim/taqvim_store.dart';
import 'package:jamejam/features/taqvim/taqvim_sync_adapter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _now = DateTime.utc(2026, 9, 20, 12);

TaqvimEvent _event(
  String title, {
  String calendar = 'Work',
  String notes = '',
  String tags = '',
  String location = '',
  DateTime? start,
  DateTime? end,
  Recurrence? rule,
}) => TaqvimEvent(
  id: 1,
  calendar: calendar,
  title: title,
  location: location,
  notes: notes,
  tags: tags,
  start: start ?? _now,
  end: end ?? _now.add(const Duration(hours: 1)),
  isAllDay: false,
  rule: rule,
  reminders: const [],
  createdAt: _now,
  updatedAt: _now,
  syncId: '',
);

void main() {
  group('TaqvimText branches', () {
    test('parseWhen failures are friendly', () {
      expect(
        () => TaqvimText.parseWhen('gibberish', _now),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('parseWhen accepts a slash date and seconds', () {
      expect(TaqvimText.parseWhen('2026/09/22', _now).day, 22);
      final seconds = TaqvimText.parseWhen('2026-09-22 14:30:15', _now);
      expect(seconds.hour, 14);
      expect(seconds.minute, 30);
      expect(seconds.second, 15);
    });

    test('parseClock failures name the label', () {
      expect(
        () => TaqvimText.parseClock('25:99', 'window start'),
        throwsA(
          isA<TaqvimException>().having(
            (ex) => ex.message,
            'message',
            contains('window start'),
          ),
        ),
      );
    });

    test('parseDay failures are friendly', () {
      expect(
        () => TaqvimText.parseDay('soon', 'day'),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('cleanTags stops at the total-length rail', () {
      final tags = TaqvimText.cleanTags(
        'aaaaaaaaaaaaaaaaaaaa,bbbbbbbbbbbbbbbbbbbb,cccccccccccccccccccc,'
        'dddddddddddddddddddd',
        12,
        30,
        40,
      );
      expect(tags.length, lessThanOrEqualTo(40));
      expect(tags, isNot(contains('dddd'))); // the tail was dropped
    });

    test('cleanTags of null or punctuation is empty', () {
      expect(TaqvimText.cleanTags(null, 12, 30, 400), isEmpty);
      expect(TaqvimText.cleanTags(',,, ;;;', 12, 30, 400), isEmpty);
    });

    test('cleanReminders skips junk and breaks at max', () {
      expect(
        TaqvimText.cleanReminders(
          '15, x, 30',
          8,
          TaqvimDefaults.maxReminderMinutes,
        ),
        [15, 30],
      );
      expect(
        TaqvimText.cleanReminders(
          '5,10,15,20,25,30,35,40',
          3,
          TaqvimDefaults.maxReminderMinutes,
        ),
        [5, 10, 15],
      );
      expect(TaqvimText.cleanReminders(null, 8, 100), isEmpty);
      expect(TaqvimText.cleanReminders('  ', 8, 100), isEmpty);
    });

    test('remindersFromCsv skips junk', () {
      expect(TaqvimText.remindersFromCsv('15,x,30'), [15, 30]);
      expect(TaqvimText.remindersFromCsv(''), isEmpty);
    });

    test('icsEscape handles every special', () {
      expect(TaqvimText.icsEscape('a\nb'), r'a\nb');
      expect(TaqvimText.icsEscape('a\rb'), 'ab');
      expect(TaqvimText.icsEscape(r'c,d;e\f'), r'c\,d\;e\\f');
    });

    test('clip trims and clips', () {
      expect(TaqvimText.clip('  trimmed  ', 50), 'trimmed');
      expect(TaqvimText.clip('0123456789xxx', 10), '0123456789');
    });

    test('tagsOf splits the csv', () {
      final ev = _event('T', tags: 'a,b,c');
      expect(TaqvimText.tagsOf(ev), ['a', 'b', 'c']);
      expect(TaqvimText.tagsOf(_event('T')), isEmpty);
    });
  });

  group('Recurrence branches', () {
    test('describe falls back to once for an unknown kind', () {
      expect(Recurrence(RecurrenceKind.fromCode(99)).describe(), 'once');
    });

    test('short names cover every day', () {
      expect(Recurrence.shortName(DateTime.thursday), 'Th');
      expect(Recurrence.shortName(DateTime.friday), 'Fr');
      expect(Recurrence.shortName(DateTime.saturday), 'Sa');
    });

    test('toRrule round-trips all weekdays', () {
      final text = Recurrences.toRrule(
        const Recurrence(
          RecurrenceKind.weekly,
          onWeekdays: [1, 2, 3, 4, 5, 6, 7],
        ),
      );
      expect(text, contains('BYDAY=MO,TU,WE,TH,FR,SA,SU'));
      expect(text, isNotNull);
      final parsed = Recurrences.fromRrule(text!);
      expect(parsed, isNotNull);
      expect(parsed!.weekdays, hasLength(7));
    });

    test('fromRrule with a time in UNTIL uses the date prefix', () {
      final rule = Recurrences.fromRrule('FREQ=DAILY;UNTIL=20261231T235959Z');
      expect(rule, isNotNull);
      expect(rule!.until, const DateOnly(2026, 12, 31));
    });

    test('yearly is stopped by until', () {
      final first = DateTime.utc(2026, 6, 1, 9);
      const rule = Recurrence(
        RecurrenceKind.yearly,
        until: DateOnly(2027, 12, 31),
      );
      final starts = Recurrences.starts(rule, first, DateTime.utc(2030));
      expect(starts, hasLength(2)); // 2026 and 2027 only
    });

    test('daily starts beyond the window end yield nothing', () {
      final first = DateTime.utc(2026, 9, 25, 9);
      const rule = Recurrence(RecurrenceKind.daily);
      expect(
        Recurrences.starts(rule, first, DateTime.utc(2026, 9, 20)),
        isEmpty,
      );
    });
  });

  group('service branches', () {
    test('overlapping events extend the busy cursor', () async {
      final store = MemoryTaqvimStore();
      final service = TaqvimService(store: store, clock: () => _now);
      await service.addEvent(
        title: 'First',
        start: DateTime.parse('2026-09-22T10:00:00Z'),
        end: DateTime.parse('2026-09-22T11:00:00Z'),
      );
      await service.addEvent(
        title: 'Overlap',
        start: DateTime.parse('2026-09-22T10:30:00Z'),
        end: DateTime.parse('2026-09-22T12:30:00Z'),
      );

      final slots = await service.freeSlots(
        const DateOnly(2026, 9, 22),
        const ClockTime(9, 0),
        const ClockTime(14, 0),
        30,
      );
      expect(slots, hasLength(2));
      expect(slots[0].start, DateTime.utc(2026, 9, 22, 9));
      expect(slots[0].end, DateTime.utc(2026, 9, 22, 10));
      expect(slots[1].start, DateTime.utc(2026, 9, 22, 12, 30));
    });

    test('createValidated without arguments uses the defaults', () {
      expect(
        TaqvimOptions.createValidated().maxEvents,
        TaqvimDefaults.maxEvents,
      );
    });
  });

  group('ICS deeper branches', () {
    test('duration variants', () {
      const days =
          'BEGIN:VEVENT\r\nSUMMARY:Retreat\r\nDTSTART;VALUE=DATE:20261001\r\n'
          'DURATION:P2D\r\nEND:VEVENT\r\n';
      final retreat = Ics.parse(days).single;
      expect(retreat.end.difference(retreat.start), const Duration(days: 2));

      const hours =
          'BEGIN:VEVENT\r\nSUMMARY:Seminar\r\nDTSTART:20261001T090000\r\n'
          'DURATION:P1DT2H30M\r\nEND:VEVENT\r\n';
      final seminar = Ics.parse(hours).single;
      expect(
        seminar.end.difference(seminar.start),
        const Duration(hours: 26, minutes: 30),
      );
    });

    test('malformed durations fall back to the default length', () {
      for (final text in [
        'BEGIN:VEVENT\r\nSUMMARY:A\r\nDTSTART:20261001T090000\r\nDURATION:P9X\r\nEND:VEVENT\r\n',
        'BEGIN:VEVENT\r\nSUMMARY:B\r\nDTSTART:20261001T090000\r\nDURATION:PT\r\nEND:VEVENT\r\n',
        'BEGIN:VEVENT\r\nSUMMARY:C\r\nDTSTART:20261001T090000\r\nDURATION:XD1\r\nEND:VEVENT\r\n',
      ]) {
        final ev = Ics.parse(text).single;
        expect(
          ev.end.difference(ev.start),
          Duration(minutes: TaqvimDefaults.defaultEventMinutes),
        );
      }
    });

    test('utc full format and loose formats', () {
      const zSuffix =
          'BEGIN:VEVENT\r\nSUMMARY:Z\r\nDTSTART:20261001T090000Z\r\nEND:VEVENT\r\n';
      expect(Ics.parse(zSuffix).single.start, DateTime.utc(2026, 10, 1, 9));

      const loose =
          'BEGIN:VEVENT\r\nSUMMARY:L\r\nDTSTART:2026-10-01 09:00\r\nEND:VEVENT\r\n';
      expect(Ics.parse(loose).single.start.hour, 9);
    });

    test('a bad trigger is ignored', () {
      const ics =
          'BEGIN:VEVENT\r\nSUMMARY:T\r\nDTSTART:20261001T090000\r\n'
          'DTEND:20261001T100000\r\nBEGIN:VALARM\r\nTRIGGER:-PTbroken\r\n'
          'END:VALARM\r\nEND:VEVENT\r\n';
      expect(Ics.parse(ics).single.reminders, isEmpty);
    });

    test('lines without a colon are skipped', () {
      expect(Ics.parse('junk line without colon'), isEmpty);
      final ok = Ics.parse(
        'junk line\nBEGIN:VEVENT\r\nSUMMARY:Ok\r\nDTSTART:20261001T090000\r\nEND:VEVENT\r\n',
      ).single;
      expect(ok.title, 'Ok');
    });

    test('a fold at the very start is ignored', () {
      const ics =
          ' folded\r\nBEGIN:VEVENT\r\nSUMMARY:S\r\nDTSTART:20261001T090000\r\nEND:VEVENT\r\n';
      expect(Ics.parse(ics).single.title, 'S');
    });
  });

  group('sync adapter branches', () {
    test('merge ignores empty sync ids inside payloads', () async {
      final payload = jsonEncode({
        'events': [
          {
            'syncId': '',
            'calendar': 'Work',
            'title': 'Ghost',
            'location': '',
            'notes': '',
            'tags': '',
            'start': _now.toIso8601String(),
            'end': _now.add(const Duration(hours: 1)).toIso8601String(),
            'isAllDay': false,
            'reminders': <int>[],
            'createdAt': _now.toIso8601String(),
            'updatedAt': _now.toIso8601String(),
          },
        ],
        'tombstones': [
          {'syncId': '', 'deletedAt': _now.toIso8601String()},
        ],
      });
      final store = MemoryTaqvimStore();
      final adapter = TaqvimSyncAdapter(
        service: TaqvimService(store: store, clock: () => _now),
        store: store,
      );
      final merged = await adapter.merge(payload, payload, 'a', 'b');
      expect(merged.replaceAll(' ', ''), contains('"events":[]'));
    });

    test('a payload without an envelope is rejected', () async {
      final store = MemoryTaqvimStore();
      final adapter = TaqvimSyncAdapter(
        service: TaqvimService(store: store, clock: () => _now),
        store: store,
      );
      await expectLater(
        adapter.merge('[]', '[]', 'a', 'b'),
        throwsA(isA<SyncException>()),
      );
    });
  });

  group('ScheduleAssistant branches', () {
    test('the brief prompt includes location, calendar and notes', () {
      final ev = _event(
        'Review',
        calendar: 'Ops',
        location: 'Room 9',
        notes: 'bring slides',
      );
      final prompt = ScheduleAssistant().buildBriefPrompt([
        Occurrence(
          event: ev,
          start: _now,
          end: _now.add(const Duration(hours: 1)),
        ),
      ], _now);
      expect(prompt, contains('Room 9'));
      expect(prompt, contains('calendar: Ops'));
      expect(prompt, contains('bring slides'));
    });
  });

  group('SQLite store branches', () {
    late Directory directory;
    late String path;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('taqvim-gap');
      path = '${directory.path}/taqvim.db';
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    test('a negative undo depth throws, depth zero is allowed', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        expect(() => store.undoDepth = -1, throwsA(isA<TaqvimException>()));
        store.undoDepth = 0;
        expect(store.undoDepth, 0);
      } finally {
        await store.close();
      }
    });

    test('pushing with depth zero clears the log', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        store.undoDepth = 0;
        await store.pushUndo('one');
        expect(await store.undoCount, 0);
        expect(await store.popUndo(), isNull);
      } finally {
        await store.close();
      }
    });

    test('upserting a tombstone with an empty sync id is a no-op', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        await store.upsertTombstone(
          TaqvimTombstone(syncId: '', deletedAt: _now),
        );
        expect(await store.getTombstones(), isEmpty);
      } finally {
        await store.close();
      }
    });

    test('LIKE escapes bracket, percent and underscore', () async {
      final store = SqliteTaqvimStore(path);
      await store.initialize();
      try {
        await store.addEvent(_event('C++ [vol 2] 100%'));
        await store.addEvent(
          _event('Plain title', end: _now.add(const Duration(hours: 2))),
        );

        // Via either engine: % _ and [ must match literally.
        expect(await store.searchIds('[vol', 10), hasLength(1));
        expect(await store.searchIds('100%', 10), hasLength(1));
        expect(await store.searchIds('vol 1', 10), isEmpty);
        expect(await store.searchIds('Plain title', 10), hasLength(1));
      } finally {
        await store.close();
      }
    });

    test('reopening with dropped FTS falls back to LIKE', () async {
      final first = SqliteTaqvimStore(path);
      await first.initialize();
      await first.addEvent(_event('Needle event', notes: 'haystack words'));
      await first.close();

      // Simulate an engine without FTS5: drop the index behind the store's back.
      final raw = await databaseFactory.openDatabase(path);
      await raw.execute(
        'DROP TABLE IF EXISTS event_fts; '
        'DROP TRIGGER IF EXISTS events_ai; '
        'DROP TRIGGER IF EXISTS events_ad; '
        'DROP TRIGGER IF EXISTS events_au;',
      );
      await raw.close();

      final second = SqliteTaqvimStore(
        path,
      ); // the schema probe fails → LIKE fallback
      await second.initialize();
      try {
        expect(await second.searchIds('needle', 10), hasLength(1));
        expect(await second.searchIds('haystack', 10), hasLength(1));
        expect(await second.searchIds('absent', 10), isEmpty);
      } finally {
        await second.close();
      }
    });
  });
}
