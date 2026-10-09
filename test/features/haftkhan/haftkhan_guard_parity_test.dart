// Parity port of tests/JameJam.Tests/HaftKhan/TaskGuardTests.cs (42 cases) and
// HaftKhan/RecurrenceTests.cs (7 cases).
//
// Haft Khan's security gate: every task field that arrives from a dialog, a backup file, or a
// sync payload passes these functions before it can reach storage, so the acceptance
// conditions are reproduced one-for-one — including the exact natural-language date grammar
// and the "bare weekday means today when it matches" rule.
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/haftkhan/models.dart';
import 'package:jamejam/features/haftkhan/recurrence.dart';
import 'package:jamejam/features/haftkhan/task_guard.dart';

void main() {
  group('TaskGuard parity', () {
    // CleanTitle_Sanitizes
    test('cleanTitle trims and strips control characters', () {
      expect(TaskGuard.cleanTitle('  Ship it  '), 'Ship it');
      expect(TaskGuard.cleanTitle('a\u0007b'), 'ab');
      expect(TaskGuard.cleanTitle('multi\nline'), 'multi\nline');
    });

    // CleanTitle_Empty_Throws
    test('cleanTitle rejects null, empty and whitespace-only titles', () {
      for (final title in [null, '', '   ']) {
        expect(() => TaskGuard.cleanTitle(title), throwsArgumentError);
      }
    });

    // CleanTitle_TooLong_Throws
    test('cleanTitle rejects a title over the length rail', () {
      expect(() => TaskGuard.cleanTitle('t' * 201), throwsA(isA<RangeError>()));
    });

    // CleanNotes_Sanitizes
    test('cleanNotes sanitizes and collapses whitespace-only to empty', () {
      expect(TaskGuard.cleanNotes(null), '');
      expect(TaskGuard.cleanNotes(''), '');
      expect(TaskGuard.cleanNotes('  '), '');
      expect(TaskGuard.cleanNotes('note\u0002'), 'note');
    });

    // CleanNotes_TooLong_Throws
    test('cleanNotes rejects notes over the length rail', () {
      expect(
        () => TaskGuard.cleanNotes('n' * 4001),
        throwsA(isA<RangeError>()),
      );
    });

    // ParsePriority_KnownNames
    test('parsePriority maps known names, defaulting to normal', () {
      expect(TaskGuard.parsePriority(null), TaskPriority.normal);
      expect(TaskGuard.parsePriority(''), TaskPriority.normal);
      expect(TaskGuard.parsePriority('low'), TaskPriority.low);
      expect(TaskGuard.parsePriority('HIGH'), TaskPriority.high);
      expect(TaskGuard.parsePriority(' Critical '), TaskPriority.critical);
    });

    // ParsePriority_Unknown_Throws
    test('parsePriority rejects unknown names', () {
      expect(() => TaskGuard.parsePriority('urgent'), throwsArgumentError);
      expect(() => TaskGuard.parsePriority('2'), throwsArgumentError);
    });

    final today = DateOnly(2026, 9, 19); // a Saturday

    // ParseDueDate_Null_StaysNull
    test('parseDueDate leaves null alone', () {
      expect(TaskGuard.parseDueDate(null, today), isNull);
    });

    // ParseDueDate_ValidIso_Parses
    test('parseDueDate reads a strict ISO date', () {
      expect(
        TaskGuard.parseDueDate('2026-12-31', today),
        DateOnly(2026, 12, 31),
      );
    });

    // ParseDueDate_NaturalLanguage_RelativeDays
    test('parseDueDate understands the relative natural-language forms', () {
      expect(TaskGuard.parseDueDate('today', today), today);
      expect(TaskGuard.parseDueDate('tod', today), today);
      expect(TaskGuard.parseDueDate('tomorrow', today), today.addDays(1));
      expect(TaskGuard.parseDueDate('tmr', today), today.addDays(1));
      expect(TaskGuard.parseDueDate('next week', today), today.addDays(7));
      expect(TaskGuard.parseDueDate('in 3 days', today), today.addDays(3));
      expect(TaskGuard.parseDueDate('in 2 weeks', today), today.addDays(14));
    });

    // ParseDueDate_InMonths_UsesCalendarMonths
    test('parseDueDate counts months on the calendar, not 30-day blocks', () {
      expect(TaskGuard.parseDueDate('in 2 months', today), today.addMonths(2));
    });

    // ParseDueDate_BareWeekday_TodayWhenMatching_ElseNextOccurrence
    test(
      'a bare weekday means today when it matches, otherwise the next one',
      () {
        expect(TaskGuard.parseDueDate('saturday', today), today);
        expect(TaskGuard.parseDueDate('sat', today), today);
        expect(TaskGuard.parseDueDate('monday', today), DateOnly(2026, 9, 21));
      },
    );

    // ParseDueDate_NextWeekday_AlwaysStrictlyFuture
    test('"next <weekday>" is always strictly in the future', () {
      expect(
        TaskGuard.parseDueDate('next saturday', today),
        DateOnly(2026, 9, 26),
      );
      expect(
        TaskGuard.parseDueDate('next monday', today),
        DateOnly(2026, 9, 21),
      );
    });

    // ParseDueDate_Invalid_Throws
    test('parseDueDate rejects ambiguous and nonsense dates', () {
      for (final text in [
        '31/12/2026',
        '2026-13-01',
        'yesterday',
        'in 0 days',
        'in x days',
        'next someday',
      ]) {
        expect(
          () => TaskGuard.parseDueDate(text, today),
          throwsArgumentError,
          reason: text,
        );
      }
    });

    // ParseEffort_KnownNames
    test('parseEffort maps short and long names, defaulting to none', () {
      expect(TaskGuard.parseEffort(null), TaskEffort.none);
      expect(TaskGuard.parseEffort('none'), TaskEffort.none);
      expect(TaskGuard.parseEffort('s'), TaskEffort.small);
      expect(TaskGuard.parseEffort('LARGE'), TaskEffort.large);
      expect(TaskGuard.parseEffort('xl'), TaskEffort.xLarge);
    });

    // ParseEffort_Unknown_Throws
    test('parseEffort rejects unknown names', () {
      expect(() => TaskGuard.parseEffort('huge'), throwsArgumentError);
    });

    // ParseRecurrenceKind_KnownNames
    test('parseRecurrenceKind maps known names, defaulting to none', () {
      expect(TaskGuard.parseRecurrenceKind(null), RecurrenceKind.none);
      expect(TaskGuard.parseRecurrenceKind('daily'), RecurrenceKind.daily);
      expect(TaskGuard.parseRecurrenceKind('WEEKLY'), RecurrenceKind.weekly);
      expect(TaskGuard.parseRecurrenceKind('month'), RecurrenceKind.monthly);
    });

    // ParseRecurrenceKind_Unknown_Throws
    test('parseRecurrenceKind rejects unknown names', () {
      expect(
        () => TaskGuard.parseRecurrenceKind('hourly'),
        throwsArgumentError,
      );
    });

    // ParseRecurrenceInterval_DefaultsToOne_Bounded
    test('parseRecurrenceInterval defaults to one and enforces the rail', () {
      expect(TaskGuard.parseRecurrenceInterval(null, 365), 1);
      expect(TaskGuard.parseRecurrenceInterval('3', 365), 3);
      expect(
        () => TaskGuard.parseRecurrenceInterval('0', 365),
        throwsArgumentError,
      );
      expect(
        () => TaskGuard.parseRecurrenceInterval('11', 10),
        throwsArgumentError,
      );
    });

    // CleanTags_Trims_Dedupes_Bounded
    test(
      'cleanTags trims, de-duplicates case-insensitively, and stays bounded',
      () {
        expect(TaskGuard.cleanTags(' alpha , beta ,ALPHA'), ['alpha', 'beta']);
        expect(TaskGuard.cleanTags(null), isEmpty);
        expect(TaskGuard.cleanTags('  '), isEmpty);
        expect(
          () => TaskGuard.cleanTags('a,b,c', maxTags: 2),
          throwsArgumentError,
        );
        expect(
          () => TaskGuard.cleanTags('way-too-long-tag', maxTagLength: 4),
          throwsA(isA<RangeError>()),
        );
      },
    );

    // CleanProject_SanitizesToSingleLine
    test('cleanProject flattens a project name onto one line', () {
      expect(TaskGuard.cleanProject(' home\nstuff '), 'home stuff');
      expect(TaskGuard.cleanProject(null), '');
    });

    // ParseIdList_ParsesDeduplicated
    test('parseIdList parses comma lists, trimming and de-duplicating', () {
      expect(TaskGuard.parseIdList('1,2,3'), [1, 2, 3]);
      expect(TaskGuard.parseIdList(' 1, 2,1 '), [1, 2]);
      expect(() => TaskGuard.parseIdList('1,x'), throwsArgumentError);
    });

    // ParseId_Valid / ParseId_Invalid_Throws
    test('parseId accepts positive integers and rejects everything else', () {
      expect(TaskGuard.parseId('3'), 3);
      expect(TaskGuard.parseId(' 42 '), 42);
      for (final text in ['0', '-1', 'abc', '', null]) {
        expect(
          () => TaskGuard.parseId(text),
          throwsArgumentError,
          reason: '$text',
        );
      }
    });

    // ParseView_KnownNames / ParseView_Unknown_Throws
    test('parseView maps names and defaults to open', () {
      expect(TaskGuard.parseView(null), TaskView.open);
      expect(TaskGuard.parseView('ALL'), TaskView.all);
      expect(TaskGuard.parseView('today'), TaskView.today);
      expect(TaskGuard.parseView('overdue'), TaskView.overdue);
      expect(TaskGuard.parseView('done'), TaskView.done);
      expect(() => TaskGuard.parseView('someday'), throwsArgumentError);
    });
  });

  group('Recurrence parity', () {
    const day = DateOnly(2026, 9, 19);

    // NextDue_Daily_AddsIntervalDays
    test('daily adds the interval in days', () {
      for (final interval in [1, 3]) {
        expect(
          Recurrence.nextDue(RecurrenceKind.daily, interval, day, day),
          day.addDays(interval),
        );
      }
    });

    // NextDue_Weekly_MultipliesBySeven
    test('weekly multiplies the interval by seven', () {
      expect(
        Recurrence.nextDue(RecurrenceKind.weekly, 2, day, day),
        day.addDays(14),
      );
    });

    // NextDue_Monthly_ClampsToMonthLength
    test('monthly clamps to the target month length', () {
      const lastOfJanuary = DateOnly(2026, 1, 31);
      expect(
        Recurrence.nextDue(
          RecurrenceKind.monthly,
          1,
          lastOfJanuary,
          lastOfJanuary,
        ),
        DateOnly(2026, 2, 28),
      );
    });

    // NextDue_WithoutDueDate_UsesCompletionDate
    test('without a due date the completion date is the base', () {
      expect(
        Recurrence.nextDue(RecurrenceKind.weekly, 1, null, day),
        day.addDays(7),
      );
    });

    // NextDue_NonRecurring_Throws
    test('a non-recurring task has no next due date', () {
      expect(
        () => Recurrence.nextDue(RecurrenceKind.none, 1, day, day),
        throwsArgumentError,
      );
    });

    // NextDue_ZeroInterval_Throws
    test('an interval below one is rejected', () {
      expect(
        () => Recurrence.nextDue(RecurrenceKind.daily, 0, day, day),
        throwsArgumentError,
      );
    });
  });
}
