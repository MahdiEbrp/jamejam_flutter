/// Parity suite for [TaqvimService] — mirrors `tests/JameJam.Tests/Taqvim/TaqvimServiceTests.cs`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/taqvim/models.dart';
import 'package:jamejam/features/taqvim/taqvim_defaults.dart';
import 'package:jamejam/features/taqvim/taqvim_options.dart';
import 'package:jamejam/features/taqvim/taqvim_service.dart';
import 'package:jamejam/features/taqvim/taqvim_store.dart';

/// 2026-09-20T12:00:00Z — a Sunday, the instant every rail is measured against.
final _now = DateTime.utc(2026, 9, 20, 12);

void main() {
  late MemoryTaqvimStore store;
  late TaqvimService service;
  late DateTime clockNow;

  TaqvimService build({TaqvimOptions? options, MemoryTaqvimStore? into}) {
    final target = into ?? store;
    return TaqvimService(
      store: target,
      clock: () => clockNow,
      options: options,
    );
  }

  setUp(() {
    store = MemoryTaqvimStore();
    clockNow = _now;
    service = build();
  });

  Future<TaqvimEvent> add({
    String title = 'Lunch',
    String start = '2026-09-22T12:00:00Z',
    String end = '2026-09-22T13:00:00Z',
    bool allDay = false,
    String? calendar,
    String? location,
    String tags = '',
    Recurrence? rule,
    List<int>? reminders,
    String notes = '',
    TaqvimService? via,
  }) => (via ?? service).addEvent(
    title: title,
    start: DateTime.parse(start),
    end: DateTime.parse(end),
    allDay: allDay,
    calendar: calendar,
    location: location,
    notes: notes,
    tags: tags,
    rule: rule,
    reminders: reminders,
  );

  /// `Assert.Throws<TaqvimException>` for an async call.
  Future<void> fails(Future<Object?> Function() action) async {
    await expectLater(action, throwsA(isA<TaqvimException>()));
  }

  group('service parity', () {
    test('add assigns id, sync id and defaults', () async {
      final ev = await add();
      expect(ev.id, 1);
      expect(ev.syncId, isNotEmpty);
      expect(ev.calendar, TaqvimDefaults.defaultCalendar);
      expect(ev.createdAt, _now);
      expect(ev.updatedAt, _now);
      expect(ev.reminders, isEmpty);
    });

    test('add trims title and calendar', () async {
      final ev = await service.addEvent(
        title: '  Yoga  ',
        start: _now,
        end: _now.add(const Duration(hours: 1)),
        calendar: ' Health ',
      );
      expect(ev.title, 'Yoga');
      expect(ev.calendar, 'Health');
    });

    for (final blank in ['', '   ']) {
      test('add empty title throws [${blank.length}]', () async {
        await fails(
          () => service.addEvent(
            title: blank,
            start: _now,
            end: _now.add(const Duration(hours: 1)),
          ),
        );
      });
    }

    test('add end before start throws', () async {
      await expectLater(
        service.addEvent(
          title: 'Backwards',
          start: _now.add(const Duration(hours: 1)),
          end: _now,
        ),
        throwsA(
          isA<TaqvimException>().having(
            (ex) => ex.message,
            'message',
            contains('end must be after'),
          ),
        ),
      );
    });

    test('add all-day must end on a later day', () async {
      final day = DateTime.utc(2026, 9, 22);
      await fails(
        () => service.addEvent(
          title: 'Same day',
          start: day,
          end: day,
          allDay: true,
        ),
      );
    });

    test('add span beyond the agenda rail throws', () async {
      final start = DateTime.utc(2026, 9, 22);
      await fails(
        () => service.addEvent(
          title: 'Eon',
          start: start,
          end: start.add(Duration(days: TaqvimDefaults.maxAgendaDays + 1)),
        ),
      );
    });

    test('add too far ahead or behind throws', () async {
      final far = _now.add(
        Duration(days: 366 * TaqvimDefaults.maxScheduleHorizonYears + 1),
      );
      await fails(
        () => service.addEvent(
          title: 'Far future',
          start: far,
          end: far.add(const Duration(hours: 1)),
        ),
      );

      final past = _now.subtract(
        Duration(days: 366 * TaqvimDefaults.maxScheduleHorizonYears + 1),
      );
      await fails(
        () => service.addEvent(
          title: 'Ancient',
          start: past,
          end: past.add(const Duration(hours: 1)),
        ),
      );
    });

    test('add past year is allowed', () async {
      final start = DateTime.utc(2025, 9, 20, 12);
      final ev = await service.addEvent(
        title: 'Memory lane',
        start: start,
        end: start.add(const Duration(hours: 1)),
      );
      expect(ev.title, 'Memory lane');
    });

    test('add event cap throws', () async {
      final capped = build(options: const TaqvimOptions(maxEvents: 2));
      await add(via: capped);
      await capped.addEvent(
        title: 'Two',
        start: _now.add(const Duration(hours: 1)),
        end: _now.add(const Duration(hours: 2)),
      );
      await fails(
        () => capped.addEvent(
          title: 'Three',
          start: _now.add(const Duration(hours: 2)),
          end: _now.add(const Duration(hours: 3)),
        ),
      );
    });

    test('add tags are cleaned', () async {
      final ev = await add(tags: 'work, deep, work, , missing');
      expect(ev.tags, 'work,deep,missing');
    });

    test('add reminders are sorted and deduplicated', () async {
      final ev = await add(reminders: [30, 10, 30, 5]);
      expect(ev.reminders, [5, 10, 30]);
    });

    test('add reminder outside the rail throws', () async {
      await fails(() => add(reminders: [-1]));
      await fails(
        () => add(reminders: [TaqvimDefaults.maxReminderMinutes + 1]),
      );
    });

    test('add too many reminders throws', () async {
      final capped = build(
        options: const TaqvimOptions(maxRemindersPerEvent: 2),
      );
      await fails(
        () => capped.addEvent(
          title: 'Buzzing',
          start: _now,
          end: _now.add(const Duration(hours: 1)),
          reminders: [5, 10, 15],
        ),
      );
    });

    test('rule rails', () async {
      await fails(
        () => add(rule: const Recurrence(RecurrenceKind.daily, interval: 0)),
      );
      await fails(
        () => add(
          rule: const Recurrence(
            RecurrenceKind.daily,
            interval: TaqvimDefaults.maxRecurrenceInterval + 1,
          ),
        ),
      );
      await fails(
        () => add(rule: const Recurrence(RecurrenceKind.weekly, count: 0)),
      );
      await fails(
        () => add(
          rule: const Recurrence(
            RecurrenceKind.weekly,
            count: TaqvimDefaults.maxRecurrenceCount + 1,
          ),
        ),
      );
      await fails(
        () => add(
          rule: const Recurrence(
            RecurrenceKind.weekly,
            onWeekdays: [1, 2, 3, 4, 5, 6, 7],
          ),
        ),
      );
    });

    test('edit updates only the given fields', () async {
      final ev = await add(location: 'Old place', notes: 'old', tags: 'work');
      clockNow = _now.add(const Duration(minutes: 5));
      final updated = await service.editEvent(
        ev.id,
        title: 'New name',
        notes: 'fresh notes',
      );
      expect(updated.title, 'New name');
      expect(updated.location, 'Old place');
      expect(updated.notes, 'fresh notes');
      expect(updated.tags, 'work');
      expect(updated.updatedAt.isAfter(ev.updatedAt), isTrue);
    });

    test('edit start moves end keeping duration when end omitted', () async {
      final ev = await add();
      final moved = await service.editEvent(
        ev.id,
        start: DateTime.utc(2026, 9, 23, 15),
      );
      expect(moved.end.difference(moved.start), const Duration(hours: 1));
    });

    test('edit empty calendar keeps the old one', () async {
      final ev = await add(calendar: 'Work');
      final updated = await service.editEvent(ev.id, calendar: '   ');
      expect(updated.calendar, 'Work');
    });

    test('edit unknown id throws', () async {
      await fails(() => service.editEvent(999, title: 'ghost'));
    });

    test('reschedule keeps duration and can set end', () async {
      final ev = await add();
      final moved = await service.reschedule(
        ev.id,
        DateTime.utc(2026, 9, 24, 9),
      );
      expect(moved.end.difference(moved.start), const Duration(hours: 1));

      final stretched = await service.reschedule(
        ev.id,
        DateTime.utc(2026, 9, 24, 9),
        newEnd: DateTime.utc(2026, 9, 24, 12),
      );
      expect(
        stretched.end.difference(stretched.start),
        const Duration(hours: 3),
      );
    });

    test('set rule and clear', () async {
      final ev = await add();
      final weekly = await service.setRule(
        ev.id,
        const Recurrence(RecurrenceKind.weekly),
      );
      expect(weekly.rule!.kind, RecurrenceKind.weekly);

      final cleared = await service.setRule(ev.id, null);
      expect(cleared.rule, isNull);
    });

    test('set reminders and clear', () async {
      final ev = await add();
      final set = await service.setReminders(ev.id, [45, 15]);
      expect(set.reminders, [15, 45]);

      final cleared = await service.setReminders(ev.id, const []);
      expect(cleared.reminders, isEmpty);
    });

    test('delete removes and undo restores', () async {
      final ev = await add();
      final deleted = await service.delete(ev.id);
      expect(deleted.id, ev.id);
      expect(await service.get(ev.id), isNull);

      expect(await service.undo(), isTrue);
      final restored = await service.get(ev.id);
      expect(restored, isNotNull);
      expect(restored!.title, ev.title);
      expect(restored.syncId, ev.syncId);
    });

    test('undo with an empty stack returns false', () async {
      expect(await service.undo(), isFalse);
    });

    test('undo of a corrupt snapshot throws', () async {
      await store.pushUndo('{ this is not json');
      await fails(() => service.undo());
    });

    test('undo of a null snapshot returns false', () async {
      await store.pushUndo('null');
      expect(await service.undo(), isFalse);
    });

    test('push undo snapshot counts as a step', () async {
      await service.pushUndoSnapshot();
      expect(await store.undoCount, 1);
      expect(await service.undo(), isTrue);
    });

    test('occurrences are ordered by start', () async {
      await add(
        title: 'Late',
        start: '2026-09-22T18:00:00Z',
        end: '2026-09-22T19:00:00Z',
      );
      await add(
        title: 'Early',
        start: '2026-09-22T08:00:00Z',
        end: '2026-09-22T09:00:00Z',
      );
      final window = await service.occurrences(
        DateTime.utc(2026, 9, 22),
        DateTime.utc(2026, 9, 23),
      );
      expect(window.length, 2);
      expect(window[0].event.title, 'Early');
      expect(window[1].event.title, 'Late');
    });

    test('occurrences with a reversed window is swapped', () async {
      final window = await service.occurrences(
        DateTime.utc(2026, 9, 23),
        DateTime.utc(2026, 9, 22),
      );
      expect(window, isEmpty);
    });

    test('occurrences clamp an overlong window to the rail', () async {
      await add(
        title: 'Someday',
        start: '2028-06-01T10:00:00Z',
        end: '2028-06-01T11:00:00Z',
      );
      final window = await service.occurrences(
        _now,
        _now.add(const Duration(days: 10000)),
      );
      expect(window, isEmpty);
    });

    test('day, week and month', () async {
      await add(
        title: 'Tuesday lunch',
        start: '2026-09-22T12:00:00Z',
        end: '2026-09-22T13:00:00Z',
      );
      await add(
        title: 'Sunday coffee',
        start: '2026-09-20T10:00:00Z',
        end: '2026-09-20T11:00:00Z',
      );

      expect(await service.day(const DateOnly(2026, 9, 22)), hasLength(1));
      // Mon 21 – Sun 27; Sunday 20 sits in the previous week.
      expect(await service.week(const DateOnly(2026, 9, 22)), hasLength(1));
      expect(await service.month(2026, 9), hasLength(2));
    });

    test('week is Monday anchored', () async {
      await add(
        title: 'Tuesday lunch',
        start: '2026-09-22T12:00:00Z',
        end: '2026-09-22T13:00:00Z',
      );
      final week = await service.week(const DateOnly(2026, 9, 22));
      expect(week.single.event.title, 'Tuesday lunch');
    });

    test('month with an invalid month throws', () async {
      await fails(() => service.month(2026, 0));
      await fails(() => service.month(2026, 13));
    });

    test('upcoming filters by calendar and tag', () async {
      await add(
        title: 'Work thing',
        start: '2026-09-21T10:00:00Z',
        end: '2026-09-21T11:00:00Z',
        calendar: 'Work',
        tags: 'focus',
      );
      await add(
        title: 'Home thing',
        start: '2026-09-21T12:00:00Z',
        end: '2026-09-21T13:00:00Z',
        calendar: 'Home',
        tags: 'family',
      );

      expect(await service.upcoming(10), hasLength(2));
      expect(await service.upcoming(10, calendar: 'Work'), hasLength(1));
      expect(await service.upcoming(10, tag: 'family'), hasLength(1));

      final limited = await service.upcoming(1);
      expect(limited, hasLength(1));
      expect(limited[0].event.title, 'Work thing');
    });

    test('search finds by title and distributes the limit', () async {
      await add(title: 'Dentist appointment', notes: 'bring the x-rays');
      await add(title: 'Sprint planning', notes: 'quarterly dentist chat');
      await add(title: 'Unrelated');

      expect(await service.search('dentist'), hasLength(2));
      expect(await service.search('dentist x-rays'), hasLength(1));
      expect(await service.search('unrelated'), hasLength(1));
    });

    test('search with an empty query throws', () async {
      await fails(() => service.search('   '));
    });

    test('conflicts detect overlaps ignoring all-day and self', () async {
      await add(
        title: 'Deep work',
        start: '2026-09-22T14:00:00Z',
        end: '2026-09-22T16:00:00Z',
      );
      await add(
        title: 'Gym',
        start: '2026-09-22T14:30:00Z',
        end: '2026-09-22T15:30:00Z',
      );
      await add(
        title: 'All-day festival',
        start: '2026-09-22T00:00:00Z',
        end: '2026-09-23T00:00:00Z',
        allDay: true,
      );

      final conflicts = await service.conflicts(
        DateTime.utc(2026, 9, 22),
        DateTime.utc(2026, 9, 23),
      );
      final conflict = conflicts.single;
      expect(conflict.first.event.title, 'Deep work');
      expect(conflict.second.event.title, 'Gym');
    });

    test('free slots between events with clipping', () async {
      await add(
        title: 'Morning',
        start: '2026-09-22T10:00:00Z',
        end: '2026-09-22T11:30:00Z',
      );
      final slots = await service.freeSlots(
        const DateOnly(2026, 9, 22),
        const ClockTime(9, 0),
        const ClockTime(14, 0),
        60,
      );
      expect(slots, hasLength(2));
      expect(slots[0].start, DateTime.utc(2026, 9, 22, 9));
      expect(slots[0].end, DateTime.utc(2026, 9, 22, 10));
      expect(slots[1].start, DateTime.utc(2026, 9, 22, 11, 30));
      expect(slots[1].end, DateTime.utc(2026, 9, 22, 14));
    });

    test('free slots skip slots shorter than the minimum', () async {
      await add(
        title: 'Blocker',
        start: '2026-09-22T10:00:00Z',
        end: '2026-09-22T10:30:00Z',
      );
      final slots = await service.freeSlots(
        const DateOnly(2026, 9, 22),
        const ClockTime(9, 0),
        const ClockTime(12, 0),
        60,
      );
      expect(slots, hasLength(2));
    });

    test('free slots rails and errors', () async {
      await fails(
        () => service.freeSlots(
          const DateOnly(2026, 9, 22),
          const ClockTime(9, 0),
          const ClockTime(17, 0),
          0,
        ),
      );
      await fails(
        () => service.freeSlots(
          const DateOnly(2026, 9, 22),
          const ClockTime(9, 0),
          const ClockTime(17, 0),
          TaqvimDefaults.maxFreeSlotMinutes + 1,
        ),
      );
      await fails(
        () => service.freeSlots(
          const DateOnly(2026, 9, 22),
          const ClockTime(17, 0),
          const ClockTime(9, 0),
          30,
        ),
      );
    });

    test('free slots with nothing scheduled is the whole window', () async {
      final slots = await service.freeSlots(
        const DateOnly(2026, 9, 22),
        const ClockTime(9, 0),
        const ClockTime(12, 0),
        30,
      );
      expect(slots.single.duration, const Duration(hours: 3));
    });

    test('stats aggregate', () async {
      await add(
        title: 'Plain',
        start: '2026-09-21T10:00:00Z',
        end: '2026-09-21T11:00:00Z',
        tags: 'work',
      );
      await add(
        title: 'Weekly',
        start: '2026-09-21T12:00:00Z',
        end: '2026-09-21T13:00:00Z',
        rule: const Recurrence(RecurrenceKind.weekly),
        reminders: [10, 30],
      );
      await add(
        title: 'Holiday',
        start: '2026-10-01T00:00:00Z',
        end: '2026-10-02T00:00:00Z',
        allDay: true,
      );

      final stats = await service.stats();
      expect(stats.events, 3);
      expect(stats.recurring, 1);
      expect(stats.allDay, 1);
      expect(stats.tagged, 1);
      expect(stats.reminders, 2);
      expect(stats.nextSevenDays, inInclusiveRange(2, 3));
      expect(stats.busyMinutesNextSevenDays, 120);
    });

    test('undo stack respects the configured depth', () async {
      final shallow = build(options: const TaqvimOptions(undoDepth: 2));
      await shallow.addEvent(
        title: 'One',
        start: _now,
        end: _now.add(const Duration(hours: 1)),
      );
      await shallow.addEvent(
        title: 'Two',
        start: _now.add(const Duration(hours: 1)),
        end: _now.add(const Duration(hours: 2)),
      );
      await shallow.addEvent(
        title: 'Three',
        start: _now.add(const Duration(hours: 2)),
        end: _now.add(const Duration(hours: 3)),
      );
      expect(await store.undoCount, 2);

      expect(await shallow.undo(), isTrue);
      expect(await shallow.all(), hasLength(2));
      expect(await shallow.undo(), isTrue);
      expect(await shallow.all(), hasLength(1));
    });

    test('edit null keeps the rule and reminders', () async {
      final ev = await add(
        rule: const Recurrence(RecurrenceKind.daily),
        reminders: [20],
      );
      final updated = await service.editEvent(ev.id, title: 'Renamed');
      expect(updated.rule!.kind, RecurrenceKind.daily);
      expect(updated.reminders, [20]);
    });

    test('edit clear rule semantics', () async {
      final ev = await add(rule: const Recurrence(RecurrenceKind.daily));
      final updated = await service.editEvent(ev.id, clearRule: true);
      expect(updated.rule, isNull);
    });

    test('edit clear reminders semantics', () async {
      final ev = await add(reminders: [20]);
      final updated = await service.editEvent(ev.id, clearReminders: true);
      expect(updated.reminders, isEmpty);
    });
  });
}
