/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import '../../core/date_only.dart';
import 'models.dart';
import 'recurrence.dart';
import 'taqvim_defaults.dart';
import 'taqvim_ics.dart';
import 'taqvim_options.dart';
import 'taqvim_store.dart';

class TaqvimService {
  TaqvimService({
    required TaqvimStore store,
    required DateTime Function() clock,
    TaqvimOptions? options,
  }) : _store = store,
       _clock = clock,
       options = TaqvimOptions.createValidated(options) {
    // The undo depth is an option, but the trimming lives in the store — wire them once.
    _store.undoDepth = this.options.undoDepth;
  }

  final TaqvimStore _store;
  final DateTime Function() _clock;

  /// The validated options this service runs under.
  final TaqvimOptions options;

  /// The store in use (SQLite in the app, memory in tests).
  TaqvimStore get store => _store;

  /// The current instant, in UTC — the clock every rail and agenda is measured against.
  DateTime get today => _clock().toUtc();

  // ── CRUD ──

  /// Creates an event. Reminders are cleaned; the rule is carried as given.
  Future<TaqvimEvent> addEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? calendar,
    String? location,
    String notes = '',
    String tags = '',
    Recurrence? rule,
    List<int>? reminders,
  }) async {
    if (title.trim().isEmpty) {
      throw const TaqvimException('An event needs a title.');
    }
    if ((await _store.listEvents()).length >= options.maxEvents) {
      throw TaqvimException('At most ${options.maxEvents} events are allowed.');
    }

    _validateWindow(start, end, allDay);

    await _pushSnapshot();
    final now = today;
    return _store.addEvent(
      TaqvimEvent(
        id: 0,
        calendar: calendar != null && calendar.isNotEmpty
            ? TaqvimText.clip(calendar, TaqvimDefaults.maxLocationLength)
            : TaqvimDefaults.defaultCalendar,
        title: TaqvimText.clip(title, options.maxTitleLength),
        location: location == null
            ? ''
            : TaqvimText.clip(location, TaqvimDefaults.maxLocationLength),
        notes: TaqvimText.clip(notes, options.maxNotesLength),
        tags: TaqvimText.cleanTags(
          tags,
          TaqvimDefaults.maxTagsPerEvent,
          TaqvimDefaults.maxTagLength,
          TaqvimDefaults.maxTagsLength,
        ),
        start: start.toUtc(),
        end: end.toUtc(),
        isAllDay: allDay,
        rule: _validateRule(rule),
        reminders: _cleanReminders(reminders),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Edits the immutable parts of an event; null keeps the current value.
  ///
  /// Times move via [reschedule] (or the start/end pair here, which also validates).
  Future<TaqvimEvent> editEvent(
    int id, {
    String? title,
    String? location,
    String? notes,
    String? tags,
    String? calendar,
    DateTime? start,
    DateTime? end,
    Recurrence? rule,
    bool clearRule = false,
    List<int>? reminders,
    bool clearReminders = false,
    bool? allDay,
  }) async {
    final ev = await _require(id);
    await _pushSnapshot();
    final nextStart = (start ?? ev.start).toUtc();
    final nextEnd = end == null
        ? (start == null ? ev.end : nextStart.add(ev.end.difference(ev.start)))
        : end.toUtc();
    final nextAllDay = allDay ?? ev.isAllDay;
    _validateWindow(nextStart, nextEnd, nextAllDay);
    final nextReminders = clearReminders
        ? const <int>[]
        : _cleanReminders(reminders ?? ev.reminders);
    final namedCalendar = calendar == null
        ? null
        : TaqvimText.clip(calendar, TaqvimDefaults.maxLocationLength);

    final updated = ev.copyWith(
      title: title == null
          ? ev.title
          : TaqvimText.clip(title, options.maxTitleLength),
      location: location == null
          ? ev.location
          : TaqvimText.clip(location, TaqvimDefaults.maxLocationLength),
      notes: notes == null
          ? ev.notes
          : TaqvimText.clip(notes, options.maxNotesLength),
      tags: tags == null
          ? ev.tags
          : TaqvimText.cleanTags(
              tags,
              TaqvimDefaults.maxTagsPerEvent,
              TaqvimDefaults.maxTagLength,
              TaqvimDefaults.maxTagsLength,
            ),
      calendar: calendar == null
          ? ev.calendar
          : (namedCalendar!.isEmpty ? ev.calendar : namedCalendar),
      start: nextStart,
      end: nextEnd,
      isAllDay: nextAllDay,
      rule: clearRule ? null : (rule == null ? ev.rule : _validateRule(rule)),
      clearRule: clearRule,
      reminders: nextReminders,
      updatedAt: today,
    );
    await _store.updateEvent(updated);
    return updated;
  }

  /// Moves an event to a new start (keeping its duration).
  Future<TaqvimEvent> reschedule(
    int id,
    DateTime newStart, {
    DateTime? newEnd,
  }) async {
    final ev = await _require(id);
    final duration = ev.end.difference(ev.start);
    final end = newEnd ?? newStart.add(duration);
    return editEvent(id, start: newStart, end: end);
  }

  /// Sets (or clears, with null) the repeat rule of an event.
  Future<TaqvimEvent> setRule(int id, Recurrence? rule) async {
    final ev = await _require(id);
    await _pushSnapshot();
    final updated = ev.copyWith(
      rule: rule == null ? null : _validateRule(rule),
      clearRule: rule == null,
      updatedAt: today,
    );
    await _store.updateEvent(updated);
    return updated;
  }

  /// Sets (or clears, with an empty list) the reminders of an event.
  Future<TaqvimEvent> setReminders(int id, List<int> reminders) async {
    final ev = await _require(id);
    await _pushSnapshot();
    final updated = ev.copyWith(
      reminders: _cleanReminders(reminders),
      updatedAt: today,
    );
    await _store.updateEvent(updated);
    return updated;
  }

  /// Deletes an event (a tombstone records the deletion; undo brings it back).
  Future<TaqvimEvent> delete(int id) async {
    final ev = await _require(id);
    await _pushSnapshot();
    await _store.removeEvent(id, today);
    return ev;
  }

  /// Gets one event, or null.
  Future<TaqvimEvent?> get(int id) => _store.findEvent(id);

  /// Lists the stored masters (not occurrences).
  Future<List<TaqvimEvent>> all() => _store.listEvents();

  // ── Agenda & windows ──

  /// Expands every event into occurrences that overlap the window (bounded by the day rail).
  Future<List<Occurrence>> occurrences(
    DateTime windowStart,
    DateTime windowEnd,
  ) async {
    var start = windowStart.toUtc();
    var end = windowEnd.toUtc();
    if (end.isBefore(start)) {
      final swap = start;
      start = end;
      end = swap;
    }

    if (end.difference(start).inDays > options.maxAgendaDays) {
      end = start.add(Duration(days: options.maxAgendaDays));
    }

    final occurrences = <Occurrence>[];
    for (final ev in await _store.listEvents()) {
      occurrences.addAll(Recurrences.occurrences(ev, start, end));
    }

    occurrences.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return a.event.title.toLowerCase().compareTo(b.event.title.toLowerCase());
    });
    return occurrences;
  }

  /// Agenda for one calendar day (local time).
  Future<List<Occurrence>> day(DateOnly day) async {
    final start = TaqvimText.toLocalInstant(
      DateTime(day.year, day.month, day.day),
    );
    return occurrences(start, start.add(const Duration(days: 1)));
  }

  /// Agenda for the local week (Monday-anchored) containing the given day.
  Future<List<Occurrence>> week(DateOnly day) async {
    final weekday = DateTime(day.year, day.month, day.day).weekday;
    final monday = DateOnly(
      day.year,
      day.month,
      day.day,
    ).addDays(-(weekday - 1));
    final start = TaqvimText.toLocalInstant(
      DateTime(monday.year, monday.month, monday.day),
    );
    return occurrences(start, start.add(const Duration(days: 7)));
  }

  /// Agenda for one local month.
  Future<List<Occurrence>> month(int year, int monthNumber) async {
    if (monthNumber < 1 || monthNumber > 12) {
      throw const TaqvimException('Month must be between 1 and 12.');
    }

    final start = TaqvimText.toLocalInstant(DateTime(year, monthNumber));
    final next = monthNumber == 12
        ? DateTime(year + 1)
        : DateTime(year, monthNumber + 1);
    return occurrences(start, TaqvimText.toLocalInstant(next));
  }

  /// The next events from now, at most [take] (clamped to 1…100).
  Future<List<Occurrence>> upcoming(
    int take, {
    String? calendar,
    String? tag,
  }) async {
    final clamped = take < 1 ? 1 : (take > 100 ? 100 : take);
    final now = today;
    final all = await occurrences(
      now,
      now.add(Duration(days: options.maxAgendaDays)),
    );
    final filtered = all.where((occurrence) {
      if (calendar != null &&
          occurrence.event.calendar.toLowerCase() != calendar.toLowerCase()) {
        return false;
      }
      if (tag != null &&
          !TaqvimText.tagsOf(
            occurrence.event,
          ).any((value) => value.toLowerCase() == tag.toLowerCase())) {
        return false;
      }
      return true;
    });
    return filtered.take(clamped).toList();
  }

  /// Events (masters) matching a full-text query.
  Future<List<TaqvimEvent>> search(String query) async {
    if (query.trim().isEmpty) {
      throw const TaqvimException('A search query must not be empty.');
    }
    final ids = (await _store.searchIds(query, options.searchLimit)).toSet();
    return [
      for (final event in await _store.listEvents())
        if (ids.contains(event.id)) event,
    ];
  }

  /// Finds conflicts — overlapping occurrences of different events — inside the window.
  Future<List<Conflict>> conflicts(
    DateTime windowStart,
    DateTime windowEnd,
  ) async {
    final busy =
        (await occurrences(
            windowStart,
            windowEnd,
          )).where((occurrence) => !occurrence.event.isAllDay).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final found = <Conflict>[];
    for (var i = 1; i < busy.length; i++) {
      final previous = busy[i - 1];
      final current = busy[i];
      if (current.start.isBefore(previous.end) &&
          previous.event.id != current.event.id) {
        found.add(Conflict(first: previous, second: current));
      }
    }
    return found;
  }

  /// Finds free slots of at least [minMinutes] inside the window
  /// (between 00:00 and 24:00 local on the given day).
  Future<List<FreeSlot>> freeSlots(
    DateOnly day,
    ClockTime from,
    ClockTime to,
    int minMinutes,
  ) async {
    if (minMinutes < 1 || minMinutes > TaqvimDefaults.maxFreeSlotMinutes) {
      throw TaqvimException(
        'Minimum slot length must be between 1 and '
        '${TaqvimDefaults.maxFreeSlotMinutes} minutes.',
      );
    }
    if (to.compareTo(from) <= 0) {
      throw const TaqvimException(
        'The free-window end must be after its start.',
      );
    }

    final windowStart = TaqvimText.toLocalInstant(
      DateTime(day.year, day.month, day.day),
    );
    final windowEnd = windowStart.add(const Duration(days: 1));
    final clipStart = windowStart.add(Duration(minutes: from.minutesOfDay));
    final clipEnd = windowStart.add(Duration(minutes: to.minutesOfDay));

    final busy = <({DateTime start, DateTime end})>[];
    for (final occurrence in await occurrences(windowStart, windowEnd)) {
      if (!occurrence.end.isAfter(clipStart) ||
          !occurrence.start.isBefore(clipEnd)) {
        continue;
      }
      busy.add((
        start: occurrence.start.isAfter(clipStart)
            ? occurrence.start
            : clipStart,
        end: occurrence.end.isBefore(clipEnd) ? occurrence.end : clipEnd,
      ));
    }
    busy.sort((a, b) => a.start.compareTo(b.start));

    final slots = <FreeSlot>[];
    var cursor = clipStart;
    for (final stretch in busy) {
      if (stretch.start.isAfter(cursor) &&
          stretch.start.difference(cursor).inMinutes >= minMinutes) {
        slots.add(FreeSlot(start: cursor, end: stretch.start));
      }
      if (stretch.end.isAfter(cursor)) {
        cursor = stretch.end;
      }
    }
    if (clipEnd.isAfter(cursor) &&
        clipEnd.difference(cursor).inMinutes >= minMinutes) {
      slots.add(FreeSlot(start: cursor, end: clipEnd));
    }
    return slots;
  }

  /// Aggregate numbers for the stats view.
  Future<TaqvimStats> stats() async {
    final events = await _store.listEvents();
    final now = today;
    final soon = await occurrences(now, now.add(const Duration(days: 7)));
    return TaqvimStats(
      events: events.length,
      recurring: events
          .where(
            (ev) => ev.rule != null && ev.rule!.kind != RecurrenceKind.once,
          )
          .length,
      allDay: events.where((ev) => ev.isAllDay).length,
      tagged: events.where((ev) => ev.tags.isNotEmpty).length,
      reminders: events.fold(0, (sum, ev) => sum + ev.reminders.length),
      nextSevenDays: soon.length,
      busyMinutesNextSevenDays: soon.fold(
        0,
        (sum, occurrence) => sum + occurrence.duration.inMinutes,
      ),
    );
  }

  // ── ICS ──

  /// Imports the events of an .ics document: at most [TaqvimDefaults.maxIcsEvents], each
  /// clipped to the rails, and one snapshot for the whole import.
  Future<List<TaqvimEvent>> importIcs(String content) async {
    if (content.codeUnits.length > TaqvimDefaults.maxIcsBytes) {
      throw TaqvimException(
        'The .ics file must be at most '
        '${TaqvimDefaults.maxIcsBytes ~/ (1024 * 1024)} MiB.',
      );
    }

    final parsed = Ics.parse(content);
    if (parsed.isEmpty) return const [];
    if (parsed.length > TaqvimDefaults.maxIcsEvents) {
      throw TaqvimException(
        'At most ${TaqvimDefaults.maxIcsEvents} events may be imported at once.',
      );
    }

    await _pushSnapshot();
    final imported = <TaqvimEvent>[];
    for (final event in parsed) {
      imported.add(
        await addEvent(
          title: event.title,
          start: event.start,
          end: event.end,
          allDay: event.isAllDay,
          location: event.location,
          notes: event.notes,
          tags: event.tags,
          rule: event.rule,
          reminders: event.reminders,
        ),
      );
    }
    return imported;
  }

  /// Renders every stored event as an .ics document.
  Future<String> exportIcs() async => Ics.export(await _store.listEvents());

  // ── Undo & snapshots ──

  /// Reverts the most recent mutation. Returns false when the stack is empty.
  Future<bool> undo() async {
    final payload = await _store.popUndo();
    if (payload == null) return false;
    final snapshot = TaqvimJson.eventsOf(payload);
    if (snapshot == null) return false;
    await _store.replaceEvents(snapshot);
    return true;
  }

  /// Pushes a whole-calendar undo snapshot — sync calls this once before applying a merge.
  Future<void> pushUndoSnapshot() => _pushSnapshot();

  Future<void> _pushSnapshot() async {
    await _store.pushUndo(TaqvimJson.snapshotOf(await _store.listEvents()));
  }

  // ── Internals ──

  Future<TaqvimEvent> _require(int id) async {
    final event = await _store.findEvent(id);
    if (event == null) {
      throw TaqvimException('No event #$id.');
    }
    return event;
  }

  void _validateWindow(DateTime start, DateTime end, bool allDay) {
    final from = start.toUtc();
    final to = end.toUtc();
    if (allDay) {
      if (!DateTime.utc(
        from.year,
        from.month,
        from.day,
      ).isBefore(DateTime.utc(to.year, to.month, to.day))) {
        throw const TaqvimException(
          'An all-day event must end on a later day than it starts.',
        );
      }
      return;
    }

    if (!to.isAfter(from)) {
      throw const TaqvimException('The end must be after the start.');
    }
    if (to.difference(from).inDays > options.maxAgendaDays) {
      throw TaqvimException(
        'An event may span at most ${options.maxAgendaDays} days.',
      );
    }

    final now = today;
    if (from.isAfter(_addYears(now, options.maxScheduleHorizonYears))) {
      throw TaqvimException(
        'Events may be scheduled at most '
        '${options.maxScheduleHorizonYears} years ahead.',
      );
    }
    if (to.isBefore(_addYears(now, -options.maxScheduleHorizonYears))) {
      throw TaqvimException(
        'Events may not be scheduled more than '
        '${options.maxScheduleHorizonYears} years in the past.',
      );
    }
  }

  /// `DateTime.plusYears` equivalent with the .NET's Feb-29 clamp (`AddYears`).
  static DateTime _addYears(DateTime instant, int years) {
    final targetYear = instant.year + years;
    final day =
        instant.month == 2 && instant.day == 29 && !_isLeapYear(targetYear)
        ? 28
        : instant.day;
    return DateTime.utc(
      targetYear,
      instant.month,
      day,
      instant.hour,
      instant.minute,
      instant.second,
      instant.millisecond,
    );
  }

  static bool _isLeapYear(int year) =>
      DateTime.utc(year, 2, 29).month == 2 &&
      DateTime.utc(year, 3, 1).subtract(const Duration(days: 1)).day == 29;

  static Recurrence? _validateRule(Recurrence? rule) {
    if (rule == null || rule.kind == RecurrenceKind.once) return rule;
    if (rule.interval < 1 ||
        rule.interval > TaqvimDefaults.maxRecurrenceInterval) {
      throw TaqvimException(
        'Recurrence interval must be between 1 and '
        '${TaqvimDefaults.maxRecurrenceInterval}.',
      );
    }
    if (rule.count != null &&
        (rule.count! < 1 || rule.count! > TaqvimDefaults.maxRecurrenceCount)) {
      throw TaqvimException(
        'Recurrence count must be between 1 and '
        '${TaqvimDefaults.maxRecurrenceCount}.',
      );
    }
    if (rule.weekdays.length > 6 && rule.kind == RecurrenceKind.weekly) {
      throw const TaqvimException(
        'A weekly rule needs at most six distinct weekdays '
        '(all seven means daily).',
      );
    }
    return rule;
  }

  List<int> _cleanReminders(List<int>? reminders) {
    if (reminders == null || reminders.isEmpty) return const [];
    final kept = <int>{};
    for (final minutes in reminders) {
      if (minutes < 0 || minutes > TaqvimDefaults.maxReminderMinutes) {
        throw TaqvimException(
          'Reminders must be between 0 and '
          '${TaqvimDefaults.maxReminderMinutes} minutes before the event.',
        );
      }
      kept.add(minutes);
      if (kept.length > options.maxRemindersPerEvent) {
        throw TaqvimException(
          'At most ${options.maxRemindersPerEvent} reminders per event.',
        );
      }
    }
    final sorted = kept.toList()..sort();
    return sorted;
  }
}
