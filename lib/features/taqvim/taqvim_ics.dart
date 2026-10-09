/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import 'models.dart';
import 'recurrence.dart';
import 'taqvim_defaults.dart';

class IcsEvent {
  const IcsEvent({
    required this.title,
    required this.start,
    required this.end,
    this.location = '',
    this.notes = '',
    this.tags = '',
    this.isAllDay = false,
    this.rule,
    this.reminders = const [],
  });

  /// Summary.
  final String title;

  /// Location (empty when absent).
  final String location;

  /// Description (empty when absent).
  final String notes;

  /// Categories joined with commas (empty when absent).
  final String tags;

  /// Start instant (all-day: midnight UTC of the day).
  final DateTime start;

  /// End instant, exclusive (all-day: midnight UTC of the next day).
  final DateTime end;

  /// All-day flag.
  final bool isAllDay;

  /// Parsed RRULE, or null (unknown rules import as one-offs).
  final Recurrence? rule;

  /// VALARM offsets in minutes-before.
  final List<int> reminders;
}

abstract final class Ics {
  static const String _crlf = '\r\n';

  /// Parses the VEVENTs of an .ics document. Never throws on content — bad events are skipped.
  static List<IcsEvent> parse(String content) {
    // Unfold: RFC 5545 folds long lines with CRLF + space/tab.
    final lines = <String>[];
    for (final raw in content.replaceAll('\r\n', '\n').split('\n')) {
      if (raw.isNotEmpty &&
          (raw[0] == ' ' || raw[0] == '\t') &&
          lines.isNotEmpty) {
        lines[lines.length - 1] = lines.last + raw.substring(1);
      } else {
        lines.add(raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw);
      }
    }

    final events = <IcsEvent>[];
    Map<String, String>? current;
    var reminders = <int>[];
    for (final line in lines) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;

      final name = line
          .substring(0, colon)
          .split(';')
          .first
          .trim()
          .toUpperCase();
      final value = line.substring(colon + 1).trim();
      if (name == 'BEGIN' && value.toLowerCase() == 'vevent') {
        current = {};
        reminders = [];
        continue;
      }
      if (name == 'END' && value.toLowerCase() == 'vevent') {
        if (current != null) {
          final parsed = _fromBlock(current, reminders);
          if (parsed != null) events.add(parsed);
        }
        current = null;
        continue;
      }
      if (current == null) continue;

      if (name == 'TRIGGER') {
        final minutes = _parseTrigger(value);
        if (minutes != null &&
            reminders.length < TaqvimDefaults.maxRemindersPerEvent) {
          reminders.add(minutes);
        }
        continue;
      }
      current[name] = value;
    }

    return events;
  }

  /// Renders events as an iCalendar document.
  static String export(List<TaqvimEvent> events) {
    final builder = StringBuffer()
      ..write('BEGIN:VCALENDAR$_crlf')
      ..write('VERSION:2.0$_crlf')
      ..write('PRODID:-//JameJam//Taqvim//EN$_crlf')
      ..write('CALSCALE:GREGORIAN$_crlf');
    for (final ev in events) {
      builder
        ..write('BEGIN:VEVENT$_crlf')
        ..write(
          'UID:${ev.syncId.isEmpty ? _newSyncId() : ev.syncId}@jamejam$_crlf',
        )
        ..write('DTSTAMP:${_utc(_stampFor(ev))}$_crlf')
        ..write('SUMMARY:${TaqvimText.icsEscape(ev.title)}$_crlf');
      if (ev.location.isNotEmpty) {
        builder.write('LOCATION:${TaqvimText.icsEscape(ev.location)}$_crlf');
      }
      if (ev.notes.isNotEmpty) {
        builder.write('DESCRIPTION:${TaqvimText.icsEscape(ev.notes)}$_crlf');
      }
      if (ev.tags.isNotEmpty) {
        builder.write(
          'CATEGORIES:${TaqvimText.icsEscape(ev.tags.replaceAll(',', ';'))}$_crlf',
        );
      }
      if (ev.isAllDay) {
        builder
          ..write('DTSTART;VALUE=DATE:${_date(ev.start)}$_crlf')
          ..write('DTEND;VALUE=DATE:${_date(ev.end)}$_crlf');
      } else {
        builder
          ..write('DTSTART:${_utc(ev.start)}$_crlf')
          ..write('DTEND:${_utc(ev.end)}$_crlf');
      }

      final rrule = Recurrences.toRrule(ev.rule);
      if (rrule != null) builder.write('RRULE:$rrule$_crlf');

      for (final minutes in ev.reminders) {
        builder
          ..write('BEGIN:VALARM$_crlf')
          ..write('ACTION:DISPLAY$_crlf')
          ..write('TRIGGER:-PT${minutes}M$_crlf')
          ..write('END:VALARM$_crlf');
      }

      builder.write('END:VEVENT$_crlf');
    }

    builder.write('END:VCALENDAR$_crlf');
    return builder.toString();
  }

  // ── Internals ──

  static DateTime _stampFor(TaqvimEvent ev) =>
      ev.updatedAt.millisecondsSinceEpoch == 0 ? ev.start : ev.updatedAt;

  static IcsEvent? _fromBlock(Map<String, String> block, List<int> reminders) {
    final summary = block['SUMMARY'];
    if (summary == null || TaqvimText.icsUnescape(summary).trim().isEmpty) {
      return null; // an event without a title is not worth importing
    }

    var allDay = false;
    DateTime start;
    DateTime end;
    final startText = block['DTSTART'];
    if (startText != null) {
      final parsedStart = _parseDateProperty(startText);
      if (parsedStart == null) return null;
      allDay = parsedStart.isDate;
      start = parsedStart.instant;

      final endText = block['DTEND'];
      final parsedEnd = endText == null ? null : _parseDateProperty(endText);
      final durationText = block['DURATION'];
      final duration = durationText == null
          ? null
          : _parseDuration(durationText);
      if (parsedEnd != null) {
        end = parsedEnd.instant;
      } else if (duration != null) {
        end = allDay
            ? start.add(
                Duration(days: duration.inDays < 1 ? 1 : duration.inDays),
              )
            : start.add(duration);
      } else {
        end = allDay
            ? start.add(const Duration(days: 1))
            : start.add(
                const Duration(minutes: TaqvimDefaults.defaultEventMinutes),
              );
      }
    } else {
      return null;
    }

    final categories = block['CATEGORIES'];
    final tags = categories == null
        ? ''
        : TaqvimText.icsUnescape(categories).replaceAll(';', ',');
    final description = block['DESCRIPTION'];
    final notes = description == null
        ? ''
        : TaqvimText.icsUnescape(description);
    final where = block['LOCATION'];
    final location = where == null ? '' : TaqvimText.icsUnescape(where);
    final rruleText = block['RRULE'];
    final rule = rruleText == null ? null : Recurrences.fromRrule(rruleText);

    // Keep windows sane: inverted or empty windows become the default duration.
    if (!end.isAfter(start)) {
      end = allDay
          ? start.add(const Duration(days: 1))
          : start.add(
              const Duration(minutes: TaqvimDefaults.defaultEventMinutes),
            );
    }

    return IcsEvent(
      title: TaqvimText.icsUnescape(summary),
      location: location,
      notes: notes,
      tags: tags,
      start: start,
      end: end,
      isAllDay: allDay,
      rule: rule,
      reminders: [...reminders],
    );
  }

  static ({DateTime instant, bool isDate})? _parseDateProperty(String value) {
    final clean = value.trim();
    if (clean.endsWith('Z')) {
      final utc = _parseExact(clean.substring(0, clean.length - 1), utc: true);
      if (utc != null) return (instant: utc, isDate: false);
    }

    if (clean.length == 8) {
      final date = _parseExact(clean, utc: false);
      if (date != null) {
        return (
          instant: DateTime.utc(date.year, date.month, date.day),
          isDate: true,
        );
      }
    }

    final local = _parseExact(clean, utc: false);
    if (local != null) return (instant: local, isDate: false);

    // TZID parameters arrive via the name part we dropped; a last-ditch general parse.
    final loose = DateTime.tryParse(clean);
    return loose == null ? null : (instant: loose.toUtc(), isDate: false);
  }

  /// Parses `yyyyMMdd'T'HHmmss` (and a bare `yyyyMMdd`), local unless [utc] is set.
  static DateTime? _parseExact(String text, {required bool utc}) {
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?$',
    ).firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = match.group(4) == null ? 0 : int.parse(match.group(4)!);
    final minute = match.group(5) == null ? 0 : int.parse(match.group(5)!);
    final second = match.group(6) == null ? 0 : int.parse(match.group(6)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    return utc
        ? DateTime.utc(year, month, day, hour, minute, second)
        : DateTime(year, month, day, hour, minute, second).toUtc();
  }

  /// Forms like P1D, PT90M, P2DT3H.
  static Duration? _parseDuration(String value) {
    final text = value.trim().toUpperCase();
    if (text.length < 3 || text[0] != 'P') {
      return null;
    }

    var days = 0;
    var hours = 0;
    var minutes = 0;
    var number = StringBuffer();
    var inTime = false;
    for (final ch in text.substring(1).split('')) {
      if (RegExp('[0-9]').hasMatch(ch)) {
        number.write(ch);
        continue;
      }
      final amount = int.tryParse(number.toString()) ?? 0;
      number = StringBuffer();
      switch (ch) {
        case 'D':
          days = amount;
        case 'T':
          inTime = true;
        case 'H':
          if (inTime) hours = amount;
        case 'M':
          if (inTime) minutes = amount;
      }
    }

    if (days == 0 && hours == 0 && minutes == 0) {
      return null;
    }
    return Duration(days: days, hours: hours, minutes: minutes);
  }

  static int? _parseTrigger(String value) {
    // Only negative durations are meaningful for "minutes before": -PT15M, -PT1H, -P1D.
    final text = value.trim().toUpperCase();
    if (!text.startsWith('-')) {
      return null; // alarms that fire after the start are not reminders-before
    }

    final duration = _parseDuration(text.substring(1));
    if (duration == null) return null;
    final minutes = duration.inMinutes;
    return minutes >= 0 && minutes <= TaqvimDefaults.maxReminderMinutes
        ? minutes
        : null;
  }

  static String _utc(DateTime instant) {
    final utc = instant.toUtc();
    return '${_date(utc)}T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}Z';
  }

  static String _date(DateTime instant) {
    final utc = instant.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static String _newSyncId() {
    // Version-7 shaped identity, minted only for an export of an unassigned event.
    final now = DateTime.now().millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    final random = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(16, '0');
    return '00000000-0000-7000-8000-${(now + random).substring(0, 12)}';
  }
}
