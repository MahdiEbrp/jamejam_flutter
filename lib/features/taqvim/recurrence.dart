/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import '../../core/date_only.dart';
import 'models.dart';
import 'taqvim_defaults.dart';

abstract final class Recurrences {
  /// Every occurrence start of [first] under [rule], up to [windowEnd] (inclusive of events
  /// overlapping the window start).
  static List<DateTime> starts(
    Recurrence rule,
    DateTime first,
    DateTime windowEnd,
  ) {
    final out = <DateTime>[];
    if (rule.kind == RecurrenceKind.once) {
      if (!first.isAfter(windowEnd)) out.add(first);
      return out;
    }

    var produced = 0;
    for (final start in _expand(rule, first, windowEnd)) {
      if (start.isAfter(windowEnd)) break;
      produced++;
      out.add(start);
      if (rule.count != null && produced >= rule.count!) break;
    }
    return out;
  }

  /// Expands candidate starts without applying the count cap (the engine's iterator).
  static List<DateTime> _expand(
    Recurrence rule,
    DateTime first,
    DateTime windowEnd,
  ) {
    final out = <DateTime>[];
    // The until-rail (inclusive day, evaluated in UTC) bounds every unbounded rule.
    // Inclusive through the whole until day: the last millisecond of that date.
    final until = rule.until != null
        ? DateTime.utc(
            rule.until!.year,
            rule.until!.month,
            rule.until!.day + 1,
          ).subtract(const Duration(milliseconds: 1))
        : windowEnd;

    switch (rule.kind) {
      case RecurrenceKind.once:
        return out;

      case RecurrenceKind.daily:
        var next = first;
        while (!next.isAfter(until)) {
          out.add(next);
          next = next.add(Duration(days: rule.interval));
        }

      case RecurrenceKind.weekly:
        final weekdays = rule.weekdays.isEmpty
            ? <int>[first.weekday]
            : rule.weekdays.toSet().toList();
        final firstDay = DateTime.utc(first.year, first.month, first.day);
        var day = firstDay;
        var stepped = 0;
        while (!day.isAfter(until)) {
          // Weeks are anchored to the first occurrence's week; the interval skips weeks.
          final weeks = day.difference(firstDay).inDays ~/ 7;
          if (weekdays.contains(day.weekday) && weeks % rule.interval == 0) {
            out.add(day.add(_timeOfDay(first)));
          }
          day = day.add(const Duration(days: 1));
          if (++stepped > TaqvimDefaults.maxAgendaDays * 2 + 8) {
            return out; // defensive horizon — rules never iterate unbounded
          }
        }

      case RecurrenceKind.monthly:
        final anchor = DateTime.utc(first.year, first.month, first.day);
        var monthCursor = DateTime.utc(anchor.year, anchor.month);
        final lastMonth = DateTime.utc(until.year, until.month);
        var index = 0;
        while (!monthCursor.isAfter(lastMonth)) {
          if (index % rule.interval == 0) {
            final clamped = anchor.day <= _daysInMonth(monthCursor)
                ? anchor.day
                : _daysInMonth(monthCursor);
            final candidateDay = monthCursor.add(Duration(days: clamped - 1));
            if (!candidateDay.isBefore(anchor)) {
              final candidate = candidateDay.add(_timeOfDay(first));
              if (!candidate.isAfter(until)) out.add(candidate);
            }
          }
          monthCursor = DateTime.utc(monthCursor.year, monthCursor.month + 1);
          index++;
        }

      case RecurrenceKind.yearly:
        final anchor = DateTime.utc(first.year, first.month, first.day);
        var year = anchor.year;
        while (!DateTime.utc(year).isAfter(until)) {
          if ((year - anchor.year) % rule.interval == 0) {
            final day =
                anchor.month == 2 && anchor.day == 29 && !_isLeapYear(year)
                ? 28
                : anchor.day;
            final candidate = DateTime.utc(
              year,
              anchor.month,
              day,
            ).add(_timeOfDay(first));
            if (!candidate.isBefore(first) && !candidate.isAfter(until)) {
              out.add(candidate);
            }
          }
          year++;
        }
    }

    return out;
  }

  /// Expands an event into full occurrences (with its duration) inside the window.
  static List<Occurrence> occurrences(
    TaqvimEvent ev,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final duration = ev.end.difference(ev.start);
    final rule = ev.rule ?? const Recurrence(RecurrenceKind.once);
    final out = <Occurrence>[];
    for (final start in starts(rule, ev.start, windowEnd)) {
      final end = start.add(duration);
      if (end.isAfter(windowStart)) {
        out.add(Occurrence(event: ev, start: start, end: end));
      }
    }
    return out;
  }

  /// Parses an RFC 5545 RRULE subset (FREQ, INTERVAL, COUNT, UNTIL, BYDAY).
  ///
  /// Unknown or malformed rules return null — callers import the event as a one-off.
  static Recurrence? fromRrule(String rrule) {
    if (rrule.trim().isEmpty) return null;

    String? freq;
    var interval = 1;
    int? count;
    DateOnly? until;
    var days = <int>[];
    for (final part in rrule.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final key = trimmed.substring(0, eq).trim().toUpperCase();
      final value = trimmed.substring(eq + 1).trim();
      switch (key) {
        case 'FREQ':
          freq = value.toUpperCase();
        case 'INTERVAL':
          final parsed = int.tryParse(value);
          if (parsed != null &&
              parsed >= 1 &&
              parsed <= TaqvimDefaults.maxRecurrenceInterval) {
            interval = parsed;
          }
        case 'COUNT':
          final counted = int.tryParse(value);
          if (counted != null &&
              counted >= 1 &&
              counted <= TaqvimDefaults.maxRecurrenceCount) {
            count = counted;
          }
        case 'UNTIL':
          until = _parseUntil(value);
        case 'BYDAY':
          if (freq == 'WEEKLY') days = _parseByDays(value);
      }
    }

    switch (freq) {
      case 'DAILY':
        return Recurrence(
          RecurrenceKind.daily,
          interval: interval,
          onWeekdays: const [],
          count: count,
          until: until,
        );
      case 'WEEKLY':
        return Recurrence(
          RecurrenceKind.weekly,
          interval: interval,
          onWeekdays: days,
          count: count,
          until: until,
        );
      case 'MONTHLY':
        return Recurrence(
          RecurrenceKind.monthly,
          interval: interval,
          onWeekdays: const [],
          count: count,
          until: until,
        );
      case 'YEARLY':
        return Recurrence(
          RecurrenceKind.yearly,
          interval: interval,
          onWeekdays: const [],
          count: count,
          until: until,
        );
      default:
        return null;
    }
  }

  /// Renders the rule as an RRULE value, or null for one-off events.
  static String? toRrule(Recurrence? rule) {
    if (rule == null || rule.kind == RecurrenceKind.once) return null;

    final freq = switch (rule.kind) {
      RecurrenceKind.daily => 'DAILY',
      RecurrenceKind.weekly => 'WEEKLY',
      RecurrenceKind.monthly => 'MONTHLY',
      RecurrenceKind.yearly => 'YEARLY',
      RecurrenceKind.once => 'DAILY',
    };
    final builder = StringBuffer('FREQ=$freq');
    if (rule.interval != 1) builder.write(';INTERVAL=${rule.interval}');
    if (rule.weekdays.isNotEmpty) {
      builder.write(';BYDAY=${rule.weekdays.map(_toByDay).join(',')}');
    }
    if (rule.until != null) {
      builder.write(';UNTIL=${_compact(rule.until!)}');
    } else if (rule.count != null) {
      builder.write(';COUNT=${rule.count}');
    }
    return builder.toString();
  }

  // ── Internals ──

  static Duration _timeOfDay(DateTime instant) => Duration(
    hours: instant.hour,
    minutes: instant.minute,
    seconds: instant.second,
    milliseconds: instant.millisecond,
  );

  static int _daysInMonth(DateTime month) =>
      DateTime.utc(month.year, month.month + 1, 0).day;

  /// True when [year] has a 29 February — the yearly clamp's own rail.
  static bool _isLeapYear(int year) => DateTime.utc(year, 2, 29).day == 29;

  static String _compact(DateOnly day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  static List<int> _parseByDays(String value) {
    final out = <int>[];
    for (final token in value.split(',')) {
      final trimmed = token.trim().toUpperCase();
      if (trimmed.isEmpty) continue;
      out.add(switch (trimmed) {
        'MO' => DateTime.monday,
        'TU' => DateTime.tuesday,
        'WE' => DateTime.wednesday,
        'TH' => DateTime.thursday,
        'FR' => DateTime.friday,
        'SA' => DateTime.saturday,
        _ => DateTime.sunday,
      });
    }
    return out;
  }

  static String _toByDay(int weekday) => switch (weekday) {
    DateTime.monday => 'MO',
    DateTime.tuesday => 'TU',
    DateTime.wednesday => 'WE',
    DateTime.thursday => 'TH',
    DateTime.friday => 'FR',
    DateTime.saturday => 'SA',
    _ => 'SU',
  };

  static DateOnly? _parseUntil(String value) {
    final text = value.trim();
    if (text.length < 8) return null;
    try {
      return DateOnly.parseIso(
        '${text.substring(0, 4)}-${text.substring(4, 6)}-${text.substring(6, 8)}',
      );
    } on FormatException {
      return null;
    }
  }
}
