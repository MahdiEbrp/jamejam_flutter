// Parity port of tests/JameJam.Tests/Taqvim/RecurrenceTests.cs (31 cases),
// TaqvimOptionsTests.cs (9 cases), IcsTests.cs (18 cases) and the text/capture halves of
// TaqvimGapTests.cs — the rails, the RFC 5545 subset, the recurrence expansion, and the
// natural-language capture.
//
// One recorded divergence: the .NET used `DateOnly`/`DayOfWeek`; Dart uses `DateTime.weekday`
// (1 = Monday … 7 = Sunday), so weekday lists are asserted in that convention.
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/taqvim/models.dart';
import 'package:jamejam/features/taqvim/recurrence.dart';
import 'package:jamejam/features/taqvim/taqvim_capture.dart';
import 'package:jamejam/features/taqvim/taqvim_defaults.dart';
import 'package:jamejam/features/taqvim/taqvim_ics.dart';
import 'package:jamejam/features/taqvim/taqvim_options.dart';

/// The .NET fixtures ran against a local clock; the assertions below use a fixed instant and
/// compare local wall-clock values, which is what the original asserted too.
final now = DateTime.utc(2026, 9, 21, 10);

TaqvimEvent event({
  int id = 1,
  String title = 'Standup',
  String calendar = 'Work',
  DateTime? start,
  DateTime? end,
  bool allDay = false,
  Recurrence? rule,
  String location = '',
  String notes = '',
  List<int> reminders = const [],
}) => TaqvimEvent(
  id: id,
  calendar: calendar,
  title: title,
  location: location,
  notes: notes,
  start: start ?? DateTime.utc(2026, 9, 21, 9),
  end: end ?? DateTime.utc(2026, 9, 21, 10),
  isAllDay: allDay,
  rule: rule,
  reminders: reminders,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
  syncId: 'uid-$id',
);

void main() {
  group('options parity', () {
    test('the defaults validate', () {
      expect(() => const TaqvimOptions().validate(), returnsNormally);
      expect(TaqvimOptions.createValidated().maxEvents, 10000);
    });

    test('title and notes rails', () {
      expect(
        () => const TaqvimOptions(maxTitleLength: 0).validate(),
        throwsA(isA<TaqvimException>()),
      );
      expect(
        () => TaqvimOptions(maxNotesLength: 10001).validate(),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('the reminder rail is the stricter of the two checks', () {
      // The .NET checked 0…8 and then 1…8; Eight is fine, nine is refused.
      expect(
        () => const TaqvimOptions(maxRemindersPerEvent: 8).validate(),
        returnsNormally,
      );
      expect(
        () => const TaqvimOptions(maxRemindersPerEvent: 9).validate(),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('the undo rail is the stricter of the two checks', () {
      expect(
        () => const TaqvimOptions(undoDepth: 20).validate(),
        returnsNormally,
      );
      expect(
        () => const TaqvimOptions(undoDepth: 21).validate(),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('the agenda, horizon and search rails', () {
      expect(
        () => TaqvimOptions(maxAgendaDays: 371).validate(),
        throwsA(isA<TaqvimException>()),
      );
      expect(
        () => TaqvimOptions(maxScheduleHorizonYears: 11).validate(),
        throwsA(isA<TaqvimException>()),
      );
      expect(
        () => TaqvimOptions(searchLimit: 101).validate(),
        throwsA(isA<TaqvimException>()),
      );
      expect(
        () => TaqvimOptions(maxAiEvents: 0).validate(),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('the outdoor tag is clipped by the tag rail', () {
      expect(
        () => TaqvimOptions(outdoorTag: 'x' * 31).validate(),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('positiveInt refuses zero and junk', () {
      expect(TaqvimParse.positiveInt('30', 'Take'), 30);
      expect(
        () => TaqvimParse.positiveInt('0', 'Take'),
        throwsA(isA<TaqvimException>()),
      );
      expect(
        () => TaqvimParse.positiveInt('many', 'Take'),
        throwsA(isA<TaqvimException>()),
      );
    });
  });

  group('text parity', () {
    test('clip trims then cuts', () {
      expect(TaqvimText.clip('  hello  ', 10), 'hello');
      expect(TaqvimText.clip('abcdef', 3), 'abc');
    });

    test('cleanTags dedupes, clips and keeps order', () {
      final cleaned = TaqvimText.cleanTags(
        'work, work , reading;deep\nwork',
        12,
        30,
        400,
      );
      expect(cleaned, 'work,reading,deep');
    });

    test('cleanTags gives up when the list rail is exhausted', () {
      final cleaned = TaqvimText.cleanTags('aaaa,bbbb,cccc', 12, 30, 6);
      expect(cleaned, 'aaaa'); // 9 characters for two tags would exceed 6
    });

    test('tagsOf splits the stored list', () {
      expect(TaqvimText.tagsOf(event()), isEmpty);
      final tagged = event().copyWith(tags: 'a,b');
      expect(TaqvimText.tagsOf(tagged), ['a', 'b']);
    });

    test('parseWhen reads the documented shapes', () {
      final fromClock = TaqvimText.parseWhen('09:30', now);
      expect(fromClock.toLocal().hour, 9);
      expect(fromClock.toLocal().minute, 30);

      final dated = TaqvimText.parseWhen('2026-09-22', now);
      expect(dated.toLocal().day, 22);
      expect(dated.toLocal().hour, 0);

      final stamped = TaqvimText.parseWhen('2026-09-22 14:30:15', now);
      expect(stamped.toLocal().hour, 14);
      expect(stamped.toLocal().second, 15);

      final slashed = TaqvimText.parseWhen('2026/09/22', now);
      expect(slashed.toLocal().day, 22);

      final isoT = TaqvimText.parseWhen('2026-09-22T14:30', now);
      expect(isoT.toLocal().minute, 30);
    });

    test('parseWhen refuses junk with a friendly message', () {
      expect(
        () => TaqvimText.parseWhen('gibberish', now),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('parseClock and parseDay refuse junk friendly', () {
      expect(
        TaqvimText.parseClock('09:00', 'window start'),
        const ClockTime(9, 0),
      );
      expect(
        () => TaqvimText.parseClock('25:99', 'window start'),
        throwsA(
          isA<TaqvimException>().having(
            (error) => error.message,
            'message',
            contains('window start'),
          ),
        ),
      );
      expect(
        TaqvimText.parseDay('2026-09-21', 'day'),
        const DateOnly(2026, 9, 21),
      );
      expect(
        () => TaqvimText.parseDay('21/09/2026', 'day'),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('reminders dedupe, sort and clamp', () {
      expect(TaqvimText.cleanReminders('15, 5, 15, 0', 8, 40320), [0, 5, 15]);
      expect(TaqvimText.cleanReminders('15, 99999', 8, 40320), [15]);
      expect(TaqvimText.cleanReminders('15, 30, 45', 2, 40320), [15, 30]);
      expect(TaqvimText.cleanReminders('', 8, 40320), isEmpty);
    });

    test('reminders round trip through storage', () {
      expect(TaqvimText.remindersToCsv([30, 15]), '30,15');
      expect(TaqvimText.remindersFromCsv('30,15'), [30, 15]);
      expect(TaqvimText.remindersFromCsv(''), isEmpty);
    });

    test('ics escaping round trips', () {
      const raw = 'line1\nline2, with ; and \\';
      final escaped = TaqvimText.icsEscape(raw);
      expect(escaped, r'line1\nline2\, with \; and \\');
      expect(TaqvimText.icsUnescape(escaped), raw);
    });

    test('whenLine renders all-day and timed occurrences', () {
      final timed = Occurrence(
        event: event(),
        start: DateTime.utc(2026, 9, 21, 9),
        end: DateTime.utc(2026, 9, 21, 10),
      );
      final line = TaqvimText.whenLine(timed);
      expect(line, isNot(contains('all day')));
      expect(line, contains('09:00'));

      final allDay = Occurrence(
        event: event(allDay: true),
        start: DateTime.utc(2026, 9, 21),
        end: DateTime.utc(2026, 9, 22),
      );
      expect(TaqvimText.whenLine(allDay), contains('(all day)'));
    });

    test('jalali formatting names the Persian month', () {
      expect(
        TaqvimText.jalaliDate(DateTime.utc(2026, 9, 21, 12)),
        'Shahrivar 30, 1405',
      );
      expect(Jalali.fromGregorian(2025, 3, 21).toString(), '1404/1/1');
      expect(Jalali.isLeapYear(1403), isTrue);
      expect(Jalali.isLeapYear(1404), isFalse);
    });
  });

  group('recurrence parity', () {
    test('a one-off yields exactly one start', () {
      final starts = Recurrences.starts(
        const Recurrence(RecurrenceKind.once),
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 12, 31),
      );
      expect(starts, [DateTime.utc(2026, 9, 21, 9)]);
    });

    test('a one-off after the window yields nothing', () {
      final starts = Recurrences.starts(
        const Recurrence(RecurrenceKind.once),
        DateTime.utc(2027, 1, 1),
        DateTime.utc(2026, 12, 31),
      );
      expect(starts, isEmpty);
    });

    test('daily repeats every day inside the window', () {
      final starts = Recurrences.starts(
        const Recurrence(RecurrenceKind.daily),
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 9, 24, 23),
      );
      expect(starts.length, 4);
      expect(starts.first, DateTime.utc(2026, 9, 21, 9));
      expect(starts.last, DateTime.utc(2026, 9, 24, 9));
    });

    test('an interval skips days', () {
      final starts = Recurrences.starts(
        const Recurrence(RecurrenceKind.daily, interval: 3),
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 10, 2, 23),
      );
      expect(starts.length, 4);
      expect(starts[1], DateTime.utc(2026, 9, 24, 9));
    });

    test('a count caps the expansion', () {
      final starts = Recurrences.starts(
        const Recurrence(RecurrenceKind.daily, count: 2),
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 12, 31),
      );
      expect(starts.length, 2);
    });

    test('the until day is inclusive', () {
      final starts = Recurrences.starts(
        const Recurrence(RecurrenceKind.daily, until: DateOnly(2026, 9, 23)),
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 12, 31),
      );
      expect(starts.length, 3);
      expect(starts.last, DateTime.utc(2026, 9, 23, 9));
    });

    test('count and until: the earlier one wins', () {
      final starts = Recurrences.starts(
        const Recurrence(
          RecurrenceKind.daily,
          count: 10,
          until: DateOnly(2026, 9, 22),
        ),
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 12, 31),
      );
      expect(starts.length, 2);
    });

    test('weekly without weekdays fires on the anchor weekday', () {
      // 2026-09-21 is a Monday.
      final starts = Recurrences.starts(
        const Recurrence(RecurrenceKind.weekly),
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 10, 12, 23),
      );
      expect(starts, [
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 9, 28, 9),
        DateTime.utc(2026, 10, 5, 9),
        DateTime.utc(2026, 10, 12, 9),
      ]);
    });

    test('weekly weekdays fire in the same week', () {
      final starts = Recurrences.starts(
        const Recurrence(
          RecurrenceKind.weekly,
          onWeekdays: [DateTime.monday, DateTime.wednesday],
        ),
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 9, 27, 23),
      );
      expect(starts, [
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 9, 23, 9),
      ]);
    });

    test('a weekly interval skips whole weeks', () {
      final starts = Recurrences.starts(
        const Recurrence(
          RecurrenceKind.weekly,
          interval: 2,
          onWeekdays: [DateTime.monday],
        ),
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 10, 12, 23),
      );
      expect(starts, [
        DateTime.utc(2026, 9, 21, 9),
        DateTime.utc(2026, 10, 5, 9),
      ]);
    });

    test('monthly clamps a 31st to the month length', () {
      final starts = Recurrences.starts(
        const Recurrence(RecurrenceKind.monthly),
        DateTime.utc(2026, 1, 31, 9),
        DateTime.utc(2026, 4, 30, 23),
      );
      expect(starts, [
        DateTime.utc(2026, 1, 31, 9),
        DateTime.utc(2026, 2, 28, 9),
        DateTime.utc(2026, 3, 31, 9),
        DateTime.utc(2026, 4, 30, 9),
      ]);
    });

    test('monthly never fires before the anchor', () {
      final starts = Recurrences.starts(
        const Recurrence(RecurrenceKind.monthly),
        DateTime.utc(2026, 1, 31, 9),
        DateTime.utc(2026, 1, 31, 23),
      );
      expect(starts.length, 1);
    });

    test('yearly clamps Feb 29 to Feb 28 in a common year', () {
      final starts = Recurrences.starts(
        const Recurrence(RecurrenceKind.yearly),
        DateTime.utc(2024, 2, 29, 9),
        DateTime.utc(2028, 3, 1),
      );
      expect(starts, [
        DateTime.utc(2024, 2, 29, 9),
        DateTime.utc(2025, 2, 28, 9),
        DateTime.utc(2026, 2, 28, 9),
        DateTime.utc(2027, 2, 28, 9),
        DateTime.utc(2028, 2, 29, 9),
      ]);
    });

    test('occurrences carry the event duration and overlap the window', () {
      final expanded = Recurrences.occurrences(
        event(
          start: DateTime.utc(2026, 9, 21, 23),
          end: DateTime.utc(2026, 9, 22, 1),
          rule: const Recurrence(RecurrenceKind.daily),
        ),
        DateTime.utc(2026, 9, 22),
        DateTime.utc(2026, 9, 24),
      );
      expect(expanded.length, 3); // the 21st overlaps midnight
      expect(expanded.first.start, DateTime.utc(2026, 9, 21, 23));
      expect(expanded.first.duration, const Duration(hours: 2));
    });

    test('describe renders the rail words', () {
      expect(const Recurrence(RecurrenceKind.once).describe(), 'once');
      expect(const Recurrence(RecurrenceKind.daily).describe(), 'every day');
      expect(
        const Recurrence(RecurrenceKind.daily, interval: 3).describe(),
        'every 3 days',
      );
      expect(
        const Recurrence(RecurrenceKind.monthly).describe(),
        'every month',
      );
      expect(
        const Recurrence(RecurrenceKind.yearly, interval: 2).describe(),
        'every 2 years',
      );
      expect(
        const Recurrence(
          RecurrenceKind.weekly,
          onWeekdays: [DateTime.wednesday, DateTime.monday],
        ).describe(),
        'every week on Mo, We',
      );
      expect(
        const Recurrence(RecurrenceKind.weekly, interval: 2).describe(),
        'every 2 weeks',
      );
    });

    test('shortName covers every weekday', () {
      expect(Recurrence.shortName(1), 'Mo');
      expect(Recurrence.shortName(7), 'Su');
      expect(Recurrence.shortNameOfDotNetDay(0), 'Su');
      expect(Recurrence.shortNameOfDotNetDay(6), 'Sa');
    });

    test('fromRrule reads the documented subset', () {
      final daily = Recurrences.fromRrule('FREQ=DAILY;INTERVAL=2')!;
      expect(daily.kind, RecurrenceKind.daily);
      expect(daily.interval, 2);

      final weekly = Recurrences.fromRrule('FREQ=WEEKLY;BYDAY=MO,WE;COUNT=5')!;
      expect(weekly.kind, RecurrenceKind.weekly);
      expect(weekly.onWeekdays, [DateTime.monday, DateTime.wednesday]);
      expect(weekly.count, 5);

      final monthly = Recurrences.fromRrule('FREQ=MONTHLY;UNTIL=20261231')!;
      expect(monthly.until, const DateOnly(2026, 12, 31));

      expect(Recurrences.fromRrule('FREQ=HOURLY'), isNull);
      expect(Recurrences.fromRrule(''), isNull);
      expect(Recurrences.fromRrule('nonsense'), isNull);
    });

    test('fromRrule clamps out-of-rail values', () {
      final huge = Recurrences.fromRrule('FREQ=DAILY;INTERVAL=99999')!;
      expect(huge.interval, 1); // outside 1…1000 → the default stands
      final counted = Recurrences.fromRrule('FREQ=DAILY;COUNT=999999')!;
      expect(counted.count, isNull);
    });

    test('toRrule renders what fromRrule reads', () {
      expect(Recurrences.toRrule(null), isNull);
      expect(
        Recurrences.toRrule(const Recurrence(RecurrenceKind.once)),
        isNull,
      );
      expect(
        Recurrences.toRrule(const Recurrence(RecurrenceKind.daily)),
        'FREQ=DAILY',
      );
      expect(
        Recurrences.toRrule(
          const Recurrence(RecurrenceKind.daily, interval: 3),
        ),
        'FREQ=DAILY;INTERVAL=3',
      );
      expect(
        Recurrences.toRrule(
          const Recurrence(
            RecurrenceKind.weekly,
            onWeekdays: [DateTime.monday, DateTime.wednesday],
          ),
        ),
        'FREQ=WEEKLY;BYDAY=MO,WE',
      );
      // UNTIL wins over COUNT, exactly like the .NET writer.
      expect(
        Recurrences.toRrule(
          const Recurrence(
            RecurrenceKind.daily,
            count: 5,
            until: DateOnly(2026, 12, 31),
          ),
        ),
        'FREQ=DAILY;UNTIL=20261231',
      );
      expect(
        Recurrences.toRrule(const Recurrence(RecurrenceKind.daily, count: 5)),
        'FREQ=DAILY;COUNT=5',
      );
    });
  });

  group('ics parity', () {
    test('parse reads a timed event', () {
      const document = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:abc@jamejam
DTSTAMP:20260921T090000Z
SUMMARY:Standup
DTSTART:20260921T090000Z
DTEND:20260921T093000Z
LOCATION:Room 3
DESCRIPTION:Daily sync
CATEGORIES:work;team
END:VEVENT
END:VCALENDAR''';
      final events = Ics.parse(document);
      expect(events.length, 1);
      final parsed = events.first;
      expect(parsed.title, 'Standup');
      expect(parsed.location, 'Room 3');
      expect(parsed.notes, 'Daily sync');
      expect(parsed.tags, 'work,team'); // semicolons become commas
      expect(parsed.isAllDay, isFalse);
      expect(parsed.start, DateTime.utc(2026, 9, 21, 9));
      expect(parsed.end, DateTime.utc(2026, 9, 21, 9, 30));
    });

    test('parse reads an all-day event', () {
      const document = '''
BEGIN:VEVENT
SUMMARY:Holiday
DTSTART;VALUE=DATE:20260921
DTEND;VALUE=DATE:20260922
END:VEVENT''';
      final events = Ics.parse(document);
      expect(events.single.isAllDay, isTrue);
      expect(events.single.start, DateTime.utc(2026, 9, 21));
      expect(events.single.end, DateTime.utc(2026, 9, 22));
    });

    test('an all-day event with no DTEND spans one day', () {
      const document = '''
BEGIN:VEVENT
SUMMARY:Holiday
DTSTART;VALUE=DATE:20260921
END:VEVENT''';
      final parsed = Ics.parse(document).single;
      expect(parsed.end, DateTime.utc(2026, 9, 22));
    });

    test('a timed event with no DTEND gets the default duration', () {
      const document = '''
BEGIN:VEVENT
SUMMARY:Call
DTSTART:20260921T090000Z
END:VEVENT''';
      final parsed = Ics.parse(document).single;
      expect(parsed.end, DateTime.utc(2026, 9, 21, 10));
    });

    test('DURATION is honored, and all-day durations floor at one day', () {
      const timed = '''
BEGIN:VEVENT
SUMMARY:Workshop
DTSTART:20260921T090000Z
DURATION:PT90M
END:VEVENT''';
      expect(Ics.parse(timed).single.end, DateTime.utc(2026, 9, 21, 10, 30));

      const dayLong = '''
BEGIN:VEVENT
SUMMARY:Retreat
DTSTART;VALUE=DATE:20260921
DURATION:P2D
END:VEVENT''';
      expect(Ics.parse(dayLong).single.end, DateTime.utc(2026, 9, 23));
    });

    test('an inverted window falls back to the default duration', () {
      const document = '''
BEGIN:VEVENT
SUMMARY:Backwards
DTSTART:20260921T100000Z
DTEND:20260921T090000Z
END:VEVENT''';
      final parsed = Ics.parse(document).single;
      expect(parsed.end, DateTime.utc(2026, 9, 21, 11));
    });

    test('events without a title or a start are skipped', () {
      const noTitle = '''
BEGIN:VEVENT
DTSTART:20260921T090000Z
END:VEVENT''';
      const noStart = '''
BEGIN:VEVENT
SUMMARY:Lost
END:VEVENT''';
      expect(Ics.parse(noTitle), isEmpty);
      expect(Ics.parse(noStart), isEmpty);
    });

    test('folded lines are unfolded', () {
      const document =
          'BEGIN:VEVENT\r\n'
          'SUMMARY:A very long title that was folded\r\n'
          ' right here\r\n'
          'DTSTART:20260921T090000Z\r\n'
          'END:VEVENT\r\n';
      expect(
        Ics.parse(document).single.title,
        'A very long title that was foldedright here',
      );
    });

    test('RRULE is parsed and unknown parts are ignored', () {
      const document = '''
BEGIN:VEVENT
SUMMARY:Weekly
DTSTART:20260921T090000Z
RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4;X-JUNK=1
END:VEVENT''';
      final rule = Ics.parse(document).single.rule!;
      expect(rule.kind, RecurrenceKind.weekly);
      expect(rule.onWeekdays, [DateTime.monday, DateTime.wednesday]);
      expect(rule.count, 4);
    });

    test('VALARM triggers become reminder offsets', () {
      const document = '''
BEGIN:VEVENT
SUMMARY:Standup
DTSTART:20260921T090000Z
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER:-PT15M
END:VALARM
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER:-PT1H
END:VALARM
END:VEVENT''';
      expect(Ics.parse(document).single.reminders, [15, 60]);
    });

    test('a positive trigger is not a reminder-before', () {
      const document = '''
BEGIN:VEVENT
SUMMARY:Standup
DTSTART:20260921T090000Z
BEGIN:VALARM
TRIGGER:PT15M
END:VALARM
END:VEVENT''';
      expect(Ics.parse(document).single.reminders, isEmpty);
    });

    test('escaping is read back', () {
      const document = r'''
BEGIN:VEVENT
SUMMARY:Lunch\, with Sara\; bring the notes
DTSTART:20260921T120000Z
END:VEVENT''';
      expect(
        Ics.parse(document).single.title,
        'Lunch, with Sara; bring the notes',
      );
    });

    test('export writes an event with its rule and alarms', () {
      final document = Ics.export([
        event(
          title: 'Standup; daily',
          location: 'Room 3',
          notes: 'line1\nline2',
          reminders: const [15],
          rule: const Recurrence(RecurrenceKind.daily),
        ),
      ]);

      expect(document, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(document, contains('PRODID:-//JameJam//Taqvim//EN'));
      expect(document, contains('UID:uid-1@jamejam'));
      expect(document, contains(r'SUMMARY:Standup\; daily'));
      expect(document, contains(r'DESCRIPTION:line1\nline2'));
      expect(document, contains('DTSTART:20260921T090000Z'));
      expect(document, contains('DTEND:20260921T100000Z'));
      expect(document, contains('RRULE:FREQ=DAILY'));
      expect(document, contains('TRIGGER:-PT15M'));
      expect(document, contains('END:VCALENDAR\r\n'));
    });

    test('export writes all-day dates without a clock', () {
      final document = Ics.export([
        event(
          allDay: true,
          start: DateTime.utc(2026, 9, 21),
          end: DateTime.utc(2026, 9, 22),
        ),
      ]);
      expect(document, contains('DTSTART;VALUE=DATE:20260921'));
      expect(document, contains('DTEND;VALUE=DATE:20260922'));
    });

    test('an exported document parses back to the same event', () {
      final original = event(
        title: 'Deep work',
        location: 'Office',
        notes: 'no meetings',
        reminders: const [5, 30],
        rule: const Recurrence(
          RecurrenceKind.weekly,
          onWeekdays: [DateTime.monday],
          count: 3,
        ),
      );
      final parsed = Ics.parse(Ics.export([original])).single;
      expect(parsed.title, original.title);
      expect(parsed.location, original.location);
      expect(parsed.notes, original.notes);
      expect(parsed.start, original.start);
      expect(parsed.end, original.end);
      expect(parsed.reminders, [5, 30]);
      expect(parsed.rule!.kind, RecurrenceKind.weekly);
      expect(parsed.rule!.count, 3);
    });
  });

  group('capture parity', () {
    test('a sentence with no date or time signal parses to null', () {
      expect(TaqvimCapture.tryParse('buy milk', now), isNull);
      expect(TaqvimCapture.tryParse('', now), isNull);
      expect(TaqvimCapture.tryParse('   ', now), isNull);
    });

    test('a bare clock time lands today', () {
      final captured = TaqvimCapture.tryParse('standup at 09:30', now)!;
      final local = captured.start.toLocal();
      expect(local.hour, 9);
      expect(local.minute, 30);
      expect(captured.isAllDay, isFalse);
      expect(captured.title, 'standup');
    });

    test('tomorrow and an ISO date both resolve', () {
      final tomorrow = TaqvimCapture.tryParse(
        'dentist tomorrow at 15:00',
        now,
      )!;
      expect(tomorrow.start.toLocal().day, 22);
      final iso = TaqvimCapture.tryParse('flight 2026-09-25 at 06:00', now)!;
      expect(iso.start.toLocal().day, 25);
    });

    test('next Tuesday means the following week', () {
      final plain = TaqvimCapture.tryParse('review tuesday at 11:00', now)!;
      expect(plain.start.toLocal().day, 22); // the coming Tuesday
      final next = TaqvimCapture.tryParse('review next tuesday at 11:00', now)!;
      expect(next.start.toLocal().day, 29);
    });

    test('a bare small hour reads as afternoon, 8-12 as morning', () {
      expect(
        TaqvimCapture.tryParse('lunch at 1', now)!.start.toLocal().hour,
        13,
      );
      expect(TaqvimCapture.tryParse('call at 9', now)!.start.toLocal().hour, 9);
      expect(
        TaqvimCapture.tryParse('call at 15', now)!.start.toLocal().hour,
        15,
      );
    });

    test('meridians are honored', () {
      expect(
        TaqvimCapture.tryParse('call at 1pm', now)!.start.toLocal().hour,
        13,
      );
      expect(
        TaqvimCapture.tryParse('call at 1am', now)!.start.toLocal().hour,
        1,
      );
      expect(
        TaqvimCapture.tryParse('call at 12am', now)!.start.toLocal().hour,
        0,
      );
      expect(
        TaqvimCapture.tryParse('call at 12pm', now)!.start.toLocal().hour,
        12,
      );
    });

    test('noon and midnight are read', () {
      expect(
        TaqvimCapture.tryParse('lunch noon', now)!.start.toLocal().hour,
        12,
      );
      expect(
        TaqvimCapture.tryParse('deploy midnight', now)!.start.toLocal().hour,
        0,
      );
    });

    test('a date without a clock is an all-day event', () {
      final captured = TaqvimCapture.tryParse('conference 2026-10-01', now)!;
      expect(captured.isAllDay, isTrue);
      expect(captured.end.difference(captured.start), const Duration(days: 1));
    });

    test('durations are read in minutes, hours and days', () {
      expect(
        TaqvimCapture.tryParse(
          'workshop tomorrow at 9 for 90m',
          now,
        )!.end.difference(
          TaqvimCapture.tryParse('workshop tomorrow at 9', now)!.start,
        ),
        const Duration(minutes: 90),
      );
      expect(
        TaqvimCapture.tryParse(
          'workshop tomorrow at 9 for 2 hours',
          now,
        )!.end.difference(
          TaqvimCapture.tryParse('workshop tomorrow at 9', now)!.start,
        ),
        const Duration(hours: 2),
      );
      final dayLong = TaqvimCapture.tryParse(
        'trip tomorrow at 9 for 2 days',
        now,
      )!;
      expect(dayLong.end.difference(dayLong.start), const Duration(days: 2));
    });

    test('an unreadable duration stays in the title', () {
      final captured = TaqvimCapture.tryParse('standup at 9 for ages', now)!;
      expect(captured.title, 'standup for ages');
    });

    test('tags are collected and removed', () {
      final captured = TaqvimCapture.tryParse(
        'lunch with Sara tomorrow at 13:00 #friends #work',
        now,
      )!;
      expect(captured.tags, 'friends,work');
      expect(captured.title, 'lunch with Sara');
    });

    test('locations come from "at <Place>" and "@place"', () {
      final place = TaqvimCapture.tryParse(
        'lunch tomorrow at 13:00 at Cafe Riviera',
        now,
      )!;
      expect(place.location, 'Cafe Riviera');
      expect(place.title, 'lunch');

      final handle = TaqvimCapture.tryParse(
        'meet tomorrow at 13:00 @office',
        now,
      )!;
      expect(handle.location, 'office');
    });

    test('a month-day the sentence names rolls to next year when past', () {
      final captured = TaqvimCapture.tryParse('renewal Mar 5', now)!;
      expect(captured.start.toLocal().month, 3);
      expect(captured.start.toLocal().day, 5);
      expect(captured.start.toLocal().year, 2027); // March is behind September

      final ahead = TaqvimCapture.tryParse('renewal Nov 5', now)!;
      expect(ahead.start.toLocal().year, 2026);
    });

    test('a sentence that is only a time still yields a title', () {
      final captured = TaqvimCapture.tryParse('at 9', now)!;
      expect(captured.title, 'Event');
    });

    test('a sentence that is only a date is titled by the date', () {
      final captured = TaqvimCapture.tryParse('2026-10-01', now)!;
      expect(captured.title, '2026-10-01');
    });

    test('dangling connectives are peeled off the title', () {
      expect(
        TaqvimCapture.tryParse('football tomorrow at 9 on', now)!.title,
        'football',
      );
    });
  });
}
