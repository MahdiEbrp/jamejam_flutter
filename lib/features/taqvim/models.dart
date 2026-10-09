/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import '../../core/date_only.dart';
import '../../core/fa_format.dart';
import '../../core/jalali.dart';
import 'taqvim_defaults.dart';

// Re-exported so the calendar's own callers keep one import for its models.
export '../../core/jalali.dart';

enum RecurrenceKind {
  /// A single occurrence.
  once(0),

  /// Repeats every `interval` days.
  daily(1),

  /// Repeats on the chosen weekdays of every `interval`-th week.
  weekly(2),

  /// Repeats on the same day of every `interval`-th month (clamped to month length).
  monthly(3),

  /// Repeats on the same date of every `interval`-th year (Feb 29 clamps to Feb 28).
  yearly(4);

  const RecurrenceKind(this.code);

  /// Stable integer used by storage and the wire format.
  final int code;

  /// Parses a stored integer, falling back to [RecurrenceKind.once].
  static RecurrenceKind fromCode(int code) => values.firstWhere(
    (kind) => kind.code == code,
    orElse: () => RecurrenceKind.once,
  );
}

class Recurrence {
  const Recurrence(
    this.kind, {
    this.interval = 1,
    this.onWeekdays = const [],
    this.count,
    this.until,
  });

  /// The repeat pattern.
  final RecurrenceKind kind;

  /// Every Nth day/week/month/year (>= 1).
  final int interval;

  /// Weekly only: the weekdays to fire on (1 = Monday … 7 = Sunday); empty means the event's
  /// own weekday.
  final List<int> onWeekdays;

  /// Total occurrences including the first; null means unbounded (until horizon).
  final int? count;

  /// Inclusive last day (UTC); null means unbounded.
  final DateOnly? until;

  /// The chosen weekdays (weekly rules); empty means the event's own weekday.
  List<int> get weekdays => onWeekdays;

  /// Short human description, e.g. "every 2 weeks on Mon, Wed" (culture-invariant).
  String describe() {
    switch (kind) {
      case RecurrenceKind.once:
        return 'once';
      case RecurrenceKind.daily:
        return interval == 1 ? 'every day' : 'every $interval days';
      case RecurrenceKind.weekly:
        return _weeklyText();
      case RecurrenceKind.monthly:
        return interval == 1 ? 'every month' : 'every $interval months';
      case RecurrenceKind.yearly:
        return interval == 1 ? 'every year' : 'every $interval years';
    }
  }

  String _weeklyText() {
    final ordered = [...weekdays]..sort((a, b) => a.compareTo(b));
    final days = ordered.isEmpty
        ? ''
        : ' on ${ordered.map(shortName).join(', ')}';
    final every = interval == 1 ? 'week' : '$interval weeks';
    return 'every $every$days';
  }

  /// Three-letter weekday name (Mo, Tu, …) for Dart's `DateTime.weekday` (1 = Monday).
  static String shortName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mo';
      case DateTime.tuesday:
        return 'Tu';
      case DateTime.wednesday:
        return 'We';
      case DateTime.thursday:
        return 'Th';
      case DateTime.friday:
        return 'Fr';
      case DateTime.saturday:
        return 'Sa';
      default:
        return 'Su';
    }
  }

  /// The three-letter name of a `.NET`-style `DayOfWeek` (0 = Sunday … 6 = Saturday).
  ///
  /// Kept because the RFC 5545 and parity fixtures speak that convention.
  static String shortNameOfDotNetDay(int dayOfWeek) =>
      shortName(dayOfWeek == 0 ? DateTime.sunday : dayOfWeek);

  Recurrence copyWith({
    RecurrenceKind? kind,
    int? interval,
    List<int>? onWeekdays,
    int? count,
    DateOnly? until,
  }) => Recurrence(
    kind ?? this.kind,
    interval: interval ?? this.interval,
    onWeekdays: onWeekdays ?? this.onWeekdays,
    count: count ?? this.count,
    until: until ?? this.until,
  );
}

class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute);

  /// Hour (0-23).
  final int hour;

  /// Minute (0-59).
  final int minute;

  /// Minutes since midnight.
  int get minutesOfDay => hour * 60 + minute;

  @override
  int compareTo(ClockTime other) => minutesOfDay.compareTo(other.minutesOfDay);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => minutesOfDay;

  /// `HH:mm`, zero-padded.
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class TaqvimEvent {
  const TaqvimEvent({
    required this.id,
    required this.calendar,
    required this.title,
    required this.start,
    required this.end,
    required this.createdAt,
    required this.updatedAt,
    this.location = '',
    this.notes = '',
    this.tags = '',
    this.isAllDay = false,
    this.rule,
    this.reminders = const [],
    this.syncId = '',
  });

  /// Assigned by the store.
  final int id;

  /// Named grouping calendar ("Work", "Personal", …).
  final String calendar;

  /// Human title (plain text).
  final String title;

  /// Where it happens (plain text; empty when nowhere).
  final String location;

  /// Markdown notes.
  final String notes;

  /// Comma-joined tags (empty when untagged).
  final String tags;

  /// First occurrence start (UTC; for all-day events, midnight UTC of the day).
  final DateTime start;

  /// First occurrence end, exclusive (all-day: midnight UTC of the next day).
  final DateTime end;

  /// All-day events span whole days and render without a clock time.
  final bool isAllDay;

  /// The repeat rule, or null for a one-off.
  final Recurrence? rule;

  /// Minutes-before-start offsets, deduplicated and sorted.
  final List<int> reminders;

  /// When the event was created.
  final DateTime createdAt;

  /// When the event was last changed (drives sync last-write-wins).
  final DateTime updatedAt;

  /// Stable cross-device identity; empty on a fresh event (the store mints one).
  final String syncId;

  /// Duration of one occurrence.
  Duration get duration => end.difference(start);

  TaqvimEvent copyWith({
    int? id,
    String? calendar,
    String? title,
    String? location,
    String? notes,
    String? tags,
    DateTime? start,
    DateTime? end,
    bool? isAllDay,
    Recurrence? rule,
    bool clearRule = false,
    List<int>? reminders,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncId,
  }) => TaqvimEvent(
    id: id ?? this.id,
    calendar: calendar ?? this.calendar,
    title: title ?? this.title,
    location: location ?? this.location,
    notes: notes ?? this.notes,
    tags: tags ?? this.tags,
    start: start ?? this.start,
    end: end ?? this.end,
    isAllDay: isAllDay ?? this.isAllDay,
    rule: clearRule ? null : (rule ?? this.rule),
    reminders: reminders ?? this.reminders,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncId: syncId ?? this.syncId,
  );

  @override
  bool operator ==(Object other) =>
      other is TaqvimEvent &&
      other.id == id &&
      other.calendar == calendar &&
      other.title == title &&
      other.location == location &&
      other.notes == notes &&
      other.tags == tags &&
      other.start == start &&
      other.end == end &&
      other.isAllDay == isAllDay &&
      other.rule?.kind == rule?.kind &&
      other.rule?.interval == rule?.interval &&
      _sameInts(
        other.rule?.onWeekdays ?? const [],
        rule?.onWeekdays ?? const [],
      ) &&
      other.rule?.count == rule?.count &&
      other.rule?.until?.toIso() == rule?.until?.toIso() &&
      _sameInts(other.reminders, reminders) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.syncId == syncId;

  @override
  int get hashCode => Object.hash(id, title, start, updatedAt, syncId);

  @override
  String toString() => 'TaqvimEvent($id, "$title", ${start.toIso8601String()})';

  static bool _sameInts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class Occurrence {
  const Occurrence({
    required this.event,
    required this.start,
    required this.end,
  });

  /// The master event this occurrence belongs to.
  final TaqvimEvent event;

  /// Occurrence start (UTC).
  final DateTime start;

  /// Occurrence end, exclusive (UTC).
  final DateTime end;

  /// Duration of the occurrence.
  Duration get duration => end.difference(start);
}

class TaqvimTombstone {
  const TaqvimTombstone({required this.syncId, required this.deletedAt});

  /// The deleted event's sync identity.
  final String syncId;

  /// When the deletion happened (UTC).
  final DateTime deletedAt;
}

class FreeSlot {
  const FreeSlot({required this.start, required this.end});

  /// Slot start (UTC).
  final DateTime start;

  /// Slot end (UTC).
  final DateTime end;

  /// Length of the slot.
  Duration get duration => end.difference(start);
}

class Conflict {
  const Conflict({required this.first, required this.second});

  /// The earlier-scheduled occurrence.
  final Occurrence first;

  /// The later-scheduled occurrence.
  final Occurrence second;
}

class TaqvimStats {
  const TaqvimStats({
    required this.events,
    required this.recurring,
    required this.allDay,
    required this.tagged,
    required this.reminders,
    required this.nextSevenDays,
    required this.busyMinutesNextSevenDays,
  });

  /// Stored events (masters).
  final int events;

  /// Events with a repeat rule.
  final int recurring;

  /// All-day events.
  final int allDay;

  /// Events carrying at least one tag.
  final int tagged;

  /// Total reminder offsets across all events.
  final int reminders;

  /// Occurrences scheduled in the next 7 days.
  final int nextSevenDays;

  /// Total scheduled minutes in the next 7 days.
  final int busyMinutesNextSevenDays;
}

abstract final class TaqvimText {
  /// Trims and clips text to a hard length (the shared rail helper).
  static String clip(String value, int maxLength) {
    final trimmed = value.trim();
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }

  /// Normalizes a comma/semicolon/newline separated tag list; empty result → empty string.
  static String cleanTags(
    String? tags,
    int maxTags,
    int maxTagLength,
    int maxLength,
  ) {
    if (tags == null || tags.trim().isEmpty) return '';

    final kept = <String>[];
    var total = 0;
    for (final raw in tags.split(RegExp('[\\n;,]'))) {
      final trimmedRaw = raw.trim();
      if (trimmedRaw.isEmpty) continue;
      final tag = clip(trimmedRaw, maxTagLength);
      if (tag.isEmpty || kept.contains(tag) || kept.length >= maxTags) {
        continue;
      }

      total += tag.length + (kept.isNotEmpty ? 1 : 0);
      if (total > maxLength) break;

      kept.add(tag);
    }

    return kept.join(',');
  }

  /// Splits a stored tag string back into tags.
  static List<String> tagsOf(TaqvimEvent ev) =>
      ev.tags.isEmpty ? const [] : ev.tags.split(',');

  /// Parses a "when" expression into an instant: `2026-09-21`, `2026-09-21 14:30`,
  /// `2026-09-21T14:30`, or `14:30` (today). Unspecified zones are local time.
  static DateTime parseWhen(String text, DateTime now) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const TaqvimException('A time must not be empty.');
    }

    final clock = _tryClock(trimmed);
    if (clock != null) {
      final localNow = now.toLocal();
      final local = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
        clock.hour,
        clock.minute,
      );
      return toLocalInstant(local);
    }

    final patterns = <List<Object>>[
      [RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})$'), false],
      [RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$'), false],
      [RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'), true],
      [RegExp(r'^(\d{4})/(\d{2})/(\d{2})$'), true],
    ];
    for (final pattern in patterns) {
      final match = (pattern[0] as RegExp).firstMatch(trimmed);
      if (match == null) continue;
      final values = [
        for (var g = 1; g <= match.groupCount; g++) int.parse(match.group(g)!),
      ];
      final local = DateTime(
        values[0],
        values[1],
        values[2],
        values.length > 3 ? values[3] : 0,
        values.length > 4 ? values[4] : 0,
        values.length > 5 ? values[5] : 0,
      );
      return toLocalInstant(local);
    }

    throw TaqvimException(
      "Cannot read the time '$trimmed'. Use '2026-09-21 14:30', '2026-09-21', "
      "or '14:30' (today).",
    );
  }

  /// Parses a `HH:mm` clock time or fails friendly.
  static ClockTime parseClock(String text, String label) {
    final clock = _tryClock(text.trim());
    if (clock != null) return clock;
    throw TaqvimException(
      "Cannot read $label '$text' — use 24-hour clock like 09:00.",
    );
  }

  /// Parses a bare date `yyyy-MM-dd` or fails friendly.
  static DateOnly parseDay(String text, String label) {
    DateOnly? day;
    try {
      day = DateOnly.parseIso(text.trim());
    } on FormatException {
      day = null;
    }
    if (day != null) return day;
    throw TaqvimException("Cannot read $label '$text' — use 2026-09-21.");
  }

  /// Converts a local wall-clock time to a UTC instant (Dart's `DateTime.toUtc`).
  static DateTime toLocalInstant(DateTime local) => DateTime(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
  ).toUtc();

  /// Formats an instant in the Jalali (Persian) calendar: "Shahrivar 29, 1405".
  static String jalaliDate(DateTime instant) {
    final local = instant.toLocal();
    final jalali = Jalali.fromGregorian(local.year, local.month, local.day);
    final name = TaqvimDefaults.jalaliMonths[jalali.month - 1];
    return '$name ${jalali.day}, ${jalali.year}';
  }

  /// Formats an occurrence for lists: "Mon 2026-09-21 14:00–15:00".
  ///
  /// Under `fa` the same line is written the way a Persian reader plans: the Jalali date, the
  /// Persian weekday name and Persian digits — "دوشنبه ۳۱ شهریور ۱۴۰۵ ۱۴:۰۰–۱۵:۰۰".
  /// The all-day marker follows the same rule ("(تمام روز)").
  static String whenLine(Occurrence occurrence, {String? locale}) {
    final start = occurrence.start.toLocal();
    final end = occurrence.end.toLocal();
    final persian = FaFormat.isPersian(locale);
    // `en` keeps the culture-invariant storage form the .NET printed; only `fa` moves to the
    // Jalali date, so the parity suites and the locale-invariant logs stay byte-stable.
    final day = persian
        ? FaFormat.date(DateOnly.fromDateTime(start), locale)
        : _date(start);
    final weekday = persian
        ? weekdayNamesFa[start.weekday - 1]
        : _weekday(start);

    if (occurrence.event.isAllDay) {
      final marker = persian ? '(تمام روز)' : '(all day)';
      return FaFormat.at(locale, '$weekday $day $marker');
    }

    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final clock = sameDay
        ? '${_clock(start)}–${_clock(end)}'
        : '${_clock(start)}–${_weekday(end)} ${_clock(end)}';
    return FaFormat.at(locale, '$weekday $day $clock');
  }

  /// Builds the reminder list: deduplicates, sorts, clamps to the rails.
  static List<int> cleanReminders(
    String? csv,
    int maxReminders,
    int maxMinutes,
  ) {
    if (csv == null || csv.trim().isEmpty) return const [];

    final kept = <int>{};
    for (final raw in csv.split(RegExp('[,; ]'))) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final minutes = int.tryParse(trimmed);
      if (minutes != null && minutes >= 0 && minutes <= maxMinutes) {
        kept.add(minutes);
      }
      if (kept.length >= maxReminders) break;
    }

    final sorted = kept.toList()..sort();
    return sorted;
  }

  /// Serializes reminders for storage.
  static String remindersToCsv(List<int> reminders) => reminders.join(',');

  /// Parses stored reminders.
  static List<int> remindersFromCsv(String csv) {
    if (csv.isEmpty) return const [];
    final kept = <int>[];
    for (final raw in csv.split(',')) {
      final minutes = int.tryParse(raw);
      if (minutes != null) kept.add(minutes);
    }
    return kept;
  }

  /// Escapes text for an ICS property value.
  static String icsEscape(String text) {
    final builder = StringBuffer();
    for (final rune in text.runes) {
      switch (rune) {
        case 0x5C: // backslash
          builder.write(r'\\');
        case 0x3B: // ;
          builder.write(r'\;');
        case 0x2C: // ,
          builder.write(r'\,');
        case 0x0A: // newline
          builder.write(r'\n');
        case 0x0D: // carriage return is dropped
          break;
        default:
          builder.writeCharCode(rune);
      }
    }
    return builder.toString();
  }

  /// Unescapes an ICS property value.
  static String icsUnescape(String text) => text
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\');

  /// Parses `h:mm` / `hh:mm` only (mirrors `TimeSpan.TryParseExact` with those two shapes).
  static ClockTime? _tryClock(String text) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return ClockTime(hour, minute);
  }

  static String _date(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';

  static String _clock(DateTime local) =>
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';

  static String _weekday(DateTime local) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[local.weekday - 1];
  }
}
