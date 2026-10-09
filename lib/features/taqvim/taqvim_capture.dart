/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import 'models.dart';
import 'taqvim_defaults.dart';

class CaptureResult {
  const CaptureResult({
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
    required this.tags,
    this.location,
  });

  /// The cleaned title (time/date/tag/location words removed).
  final String title;

  /// Start instant (local zone resolved).
  final DateTime start;

  /// End instant.
  final DateTime end;

  /// True when the sentence carried a date but no clock time.
  final bool isAllDay;

  /// Tags captured from `#hash` tokens.
  final String tags;

  /// Location captured from `at/in <Place>` or `@place`.
  final String? location;
}

abstract final class TaqvimCapture {
  /// Tries to parse a sentence. Returns null when there is no date/time signal at all.
  static CaptureResult? tryParse(String sentence, DateTime now) {
    if (sentence.trim().isEmpty) return null;

    final nowLocal = now.toLocal();
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    var text = sentence.trim();

    // 1) Tags: #word tokens anywhere.
    final tags = <String>[];
    text = text.replaceAllMapped(RegExp(r'#(\w[\w-]*)'), (match) {
      final tag = match.group(1)!;
      if (tag.isNotEmpty && tags.length < TaqvimDefaults.maxTagsPerEvent) {
        tags.add(tag);
        return ' ';
      }
      return match.group(0)!;
    });

    // 2) Duration: "for 90m", "for 2 hours", "for 45 min".
    Duration? duration;
    final durationMatch = RegExp(
      r'\bfor\s+(\d{1,4})\s*(m|min|mins|minute|minutes|h|hr|hrs|hour|hours|d|day|days)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (durationMatch != null) {
      duration = _parseDurationText(
        durationMatch.group(1)!,
        durationMatch.group(2)!.toLowerCase(),
      );
      if (duration != null) {
        text = _cut(text, durationMatch.start, durationMatch.end);
      }
    }

    // 3) Date: ISO "2026-09-22", then "today"/"tomorrow", then weekday (with optional "next").
    DateTime? day;
    final isoMatch = RegExp(r'\b(\d{4}-\d{2}-\d{2})\b').firstMatch(text);
    if (isoMatch != null) {
      final parsed = DateTime.tryParse(isoMatch.group(1)!);
      if (parsed != null) {
        day = DateTime(parsed.year, parsed.month, parsed.day);
        text = _cut(text, isoMatch.start, isoMatch.end);
      }
    } else {
      final simpleMatch = RegExp(
        r'\b(today|tomorrow)\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (simpleMatch != null) {
        day = simpleMatch.group(1)!.toLowerCase() == 'today'
            ? today
            : today.add(const Duration(days: 1));
        text = _cut(text, simpleMatch.start, simpleMatch.end);
      } else {
        final weekdayMatch = RegExp(
          r'\b(?:(next)\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b',
          caseSensitive: false,
        ).firstMatch(text);
        final weekday = weekdayMatch == null
            ? null
            : _parseWeekdayWord(weekdayMatch.group(2)!.toLowerCase());
        if (weekdayMatch != null && weekday != null) {
          final offset = (weekday - nowLocal.weekday + 7) % 7;
          day = weekdayMatch.group(1) != null
              ? today.add(
                  Duration(days: offset + 7),
                ) // "next Friday" = the following week
              : today.add(Duration(days: offset));
          text = _cut(text, weekdayMatch.start, weekdayMatch.end);
        }
      }
    }

    // 3b) "Mar 5" / "on March 5" — month name plus day number (rolls to next year when past).
    if (day == null) {
      final monthDay = RegExp(
        r'\b(?:on\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\.?\s+(\d{1,2})\b',
        caseSensitive: false,
      ).firstMatch(text);
      final month = monthDay == null
          ? null
          : _monthNameIndex(monthDay.group(1)!);
      final dayNumber = monthDay == null
          ? null
          : int.tryParse(monthDay.group(2)!);
      if (monthDay != null &&
          month != null &&
          dayNumber != null &&
          dayNumber >= 1 &&
          dayNumber <= 31) {
        final lastDay = DateTime.utc(nowLocal.year, month + 1, 0).day;
        var candidate = DateTime(
          nowLocal.year,
          month,
          dayNumber <= lastDay ? dayNumber : lastDay,
        );
        if (candidate.isBefore(today)) {
          candidate = DateTime(
            candidate.year + 1,
            candidate.month,
            candidate.day,
          );
        }
        day = candidate;
        text = _cut(text, monthDay.start, monthDay.end);
      }
    }

    // 4) Time: "at 3", "at 15:30", "at 1pm", "10:05 am", bare "15:30", "noon", "midnight".
    ClockTime? clock;
    final timeMatch = RegExp(
      r'\b(?:at\s+(\d{1,2})(?::(\d{2}))?(?:\s*(am|pm))?\b(?![\d:])|\b(\d{1,2}):(\d{2})\b|\b(\d{1,2})(?:\s*)(am|pm)\b|\b(noon|midnight)\b)',
      caseSensitive: false,
    ).firstMatch(text);
    if (timeMatch != null) {
      final zoneWord = timeMatch.group(8);
      if (zoneWord != null) {
        clock = zoneWord.toLowerCase() == 'noon'
            ? const ClockTime(12, 0)
            : const ClockTime(0, 0);
        text = _cut(text, timeMatch.start, timeMatch.end);
      } else {
        final hourText =
            timeMatch.group(1) ??
            timeMatch.group(6) ??
            timeMatch.group(4) ??
            '';
        final minuteText = timeMatch.group(2) ?? timeMatch.group(5) ?? '0';
        final meridian = (timeMatch.group(3) ?? timeMatch.group(7) ?? '')
            .trim()
            .toLowerCase();
        clock = _parseClockText(hourText, minuteText, meridian);
        if (clock != null) {
          text = _cut(text, timeMatch.start, timeMatch.end);
        }
      }
    }

    if (day == null && clock == null) {
      return null; // no calendar signal — the caller keeps the sentence as plain text
    }

    final allDay = clock == null;
    day ??= today;

    // 5) Location: "at/in <Place-ish>" left after time extraction, or "@place".
    String? location;
    final locationMatch = RegExp(
      r"\b(?:at|in)\s+([A-Z][\w'.]*(?:\s+(?:of|the|de|da|al)?\s*[A-Z][\w'.?]*)*)|@([\w][\w-]*)",
    ).firstMatch(text);
    if (locationMatch != null) {
      final candidate = (locationMatch.group(1) ?? locationMatch.group(2) ?? '')
          .trim();
      final trimmed = _trimPunctuation(candidate);
      if (trimmed.length >= 2 && RegExp('[A-Za-z]').hasMatch(trimmed)) {
        location = trimmed;
        text = _cut(text, locationMatch.start, locationMatch.end);
      }
    }

    // 6) Title: collapse the leftovers, then peel dangling connectives ("football on").
    var title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    title = _trimPunctuation(title);
    title = title
        .replaceAll(
          RegExp(r'\s*\b(on|at|in|for|next|by|to)\b\s*$', caseSensitive: false),
          '',
        )
        .trim();
    title = _trimPunctuation(title);
    if (title.isEmpty) {
      title = allDay ? _isoDay(day) : 'Event';
    }

    final start = TaqvimText.toLocalInstant(
      DateTime(
        day.year,
        day.month,
        day.day,
        clock?.hour ?? 0,
        clock?.minute ?? 0,
      ),
    );
    final end = allDay
        ? start.add(const Duration(days: 1))
        : start.add(
            duration ??
                const Duration(minutes: TaqvimDefaults.defaultEventMinutes),
          );
    return CaptureResult(
      title: TaqvimText.clip(title, 200),
      start: start,
      end: end,
      isAllDay: allDay,
      tags: tags.isEmpty ? '' : tags.join(','),
      location: location,
    );
  }

  // ── Internals ──

  /// Removes a matched span and tidies the join.
  static String _cut(String text, int start, int end) {
    final before = text.substring(0, start).trimRight();
    final after = text.substring(end).trimLeft();
    if (before.isEmpty) return after;
    if (after.isEmpty) return before;
    return '$before $after';
  }

  static Duration? _parseDurationText(String amount, String unit) {
    final value = int.tryParse(amount);
    if (value == null || value <= 0) return null;
    switch (unit) {
      case 'm':
      case 'min':
      case 'mins':
      case 'minute':
      case 'minutes':
        return Duration(minutes: value);
      case 'h':
      case 'hr':
      case 'hrs':
      case 'hour':
      case 'hours':
        return Duration(hours: value);
      case 'd':
      case 'day':
      case 'days':
        return Duration(days: value);
      default:
        return null;
    }
  }

  /// Reads a clock time. Without a meridian, a bare small hour reads as afternoon
  /// ("lunch at 1" → 13:00) while 8–12 stay morning ("at 9" → 09:00) and 13+ are literal.
  static ClockTime? _parseClockText(
    String hourText,
    String minuteText,
    String meridian,
  ) {
    var hour = int.tryParse(hourText);
    final minute = int.tryParse(minuteText);
    if (hour == null || minute == null) return null;
    if (minute < 0 || minute > 59) return null;

    switch (meridian) {
      case 'pm':
      case 'p':
        if (hour >= 1 && hour <= 11) hour += 12;
      case 'am':
      case 'a':
        if (hour == 12) hour = 0;
      case '':
        if (hour >= 1 && hour <= 7 && hourText.length == 1) {
          hour += 12; // "at 1"–"at 7" read as afternoon; "at 9" as morning
        }
    }

    if (hour < 0 || hour > 23) return null;
    return ClockTime(hour, minute);
  }

  /// Parses a weekday word into Dart's `DateTime.weekday` (1 = Monday … 7 = Sunday).
  static int? _parseWeekdayWord(String word) => switch (word) {
    'sun' || 'sunday' => DateTime.sunday,
    'mon' || 'monday' => DateTime.monday,
    'tue' || 'tues' || 'tuesday' => DateTime.tuesday,
    'wed' || 'wednesday' => DateTime.wednesday,
    'thu' || 'thur' || 'thurs' || 'thursday' => DateTime.thursday,
    'fri' || 'friday' => DateTime.friday,
    'sat' || 'saturday' => DateTime.saturday,
    _ => null,
  };

  static int? _monthNameIndex(String word) {
    final lower = word.toLowerCase();
    for (var i = 0; i < TaqvimDefaults.monthNames.length; i++) {
      final full = TaqvimDefaults.monthNames[i].toLowerCase();
      if (lower == full || (full.startsWith(lower) && lower.length >= 3)) {
        return i + 1;
      }
    }
    return null;
  }

  static String _trimPunctuation(String text) {
    var start = 0;
    var end = text.length;
    while (start < end && ' -,:.!?'.contains(text[start])) {
      start++;
    }
    while (end > start && ' -,:.!?'.contains(text[end - 1])) {
      end--;
    }
    return text.substring(start, end);
  }

  static String _isoDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
