/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import 'package:flutter/foundation.dart';

import '../../core/date_only.dart';
import '../settings/setting_keys.dart';
import '../settings/settings_controller.dart';
import '../soroush/ai_funnel.dart';
import 'models.dart';
import 'schedule_assistant.dart';
import 'taqvim_capture.dart';
import 'taqvim_defaults.dart';
import 'taqvim_options.dart';
import 'taqvim_service.dart';

enum TaqvimScope {
  /// Today's occurrences (`taqvim today`).
  today,

  /// Tomorrow's occurrences (`taqvim tomorrow`).
  tomorrow,

  /// The Monday-anchored week around the anchor day (`taqvim week`).
  week,

  /// The whole month (`taqvim month`).
  month,

  /// The upcoming horizon (`taqvim list --scope upcoming`).
  upcoming;

  /// The stable key used by widget keys and the tests.
  String get key => switch (this) {
    TaqvimScope.today => 'today',
    TaqvimScope.tomorrow => 'tomorrow',
    TaqvimScope.week => 'week',
    TaqvimScope.month => 'month',
    TaqvimScope.upcoming => 'upcoming',
  };
}

enum TaqvimAiVerb {
  /// Summarise the day (`ai brief`).
  brief,

  /// Suggest a plan for the week (`ai plan`).
  plan,

  /// Answer a question over the agenda (`ai ask`).
  ask,

  /// Turn a sentence into a command (`ai capture`).
  capture;

  /// The stable key used by widget keys and the tests.
  String get key => name;
}

class TaqvimController extends ChangeNotifier {
  TaqvimController({
    required TaqvimService service,
    SettingsController? settings,
    AiFunnel? funnel,
    ScheduleAssistant? assistant,
    Future<List<String>> Function()? dueTasks,
    DateTime Function()? clock,
  }) : _service = service,
       _settings = settings,
       _funnel = funnel,
       _assistant = assistant ?? ScheduleAssistant(service.options),
       _dueTasks = dueTasks,
       _clock = clock ?? DateTime.now;

  final TaqvimService _service;
  final SettingsController? _settings;
  final AiFunnel? _funnel;
  final ScheduleAssistant _assistant;

  /// Open tasks from Haft Khan, appended to the plan prompt — `--due` in the CLI.
  final Future<List<String>> Function()? _dueTasks;
  final DateTime Function() _clock;

  List<TaqvimEvent> _events = const [];
  List<Occurrence> _agenda = const [];
  List<Conflict> _conflicts = const [];
  List<FreeSlot> _freeSlots = const [];
  List<TaqvimEvent> _searchResults = const [];
  TaqvimStats? _stats;
  TaqvimEvent? _selected;
  TaqvimScope _scope = TaqvimScope.today;
  DateOnly? _anchor;
  String _query = '';
  String? _calendarFilter;
  String? _tagFilter;
  String? _error;
  String? _message;
  bool _busy = false;
  bool _undoAvailable = false;
  bool _disposed = false;
  String? _aiAnswer;
  String? _aiSuggestion;
  TaqvimAiVerb? _aiVerb;
  bool _aiBusy = false;

  /// Every stored event, ordered by start.
  List<TaqvimEvent> get events => _events;

  /// The occurrences of the current [scope], after the optional filters.
  List<Occurrence> get agenda => _agenda;

  /// The unfiltered occurrences of the current scope window.
  List<Occurrence> get scopeOccurrences => _scopeOccurrences;
  List<Occurrence> _scopeOccurrences = const [];

  /// Overlapping occurrences inside the current scope window.
  List<Conflict> get conflicts => _conflicts;

  /// The last free-slot computation.
  List<FreeSlot> get freeSlots => _freeSlots;

  /// The last search result (masters matching [query]).
  List<TaqvimEvent> get searchResults => _searchResults;

  /// Aggregate counters, or null before the first [load].
  TaqvimStats? get stats => _stats;

  /// The event being shown or edited, or null.
  TaqvimEvent? get selected => _selected;

  /// The scope the agenda shows.
  TaqvimScope get scope => _scope;

  /// The day the scope is anchored to (defaults to today).
  DateOnly get anchor => _anchor ?? today;

  /// Today, in UTC — the instant every scope is measured against.
  DateOnly get today {
    final now = _clock().toUtc();
    return DateOnly(now.year, now.month, now.day);
  }

  /// The last search query.
  String get query => _query;

  /// The calendar filter applied to the agenda, or null.
  String? get calendarFilter => _calendarFilter;

  /// The tag filter applied to the agenda, or null.
  String? get tagFilter => _tagFilter;

  /// The last failure, or null.
  String? get error => _error;

  /// The last success note, or null.
  String? get message => _message;

  /// True while a mutation is in flight.
  bool get busy => _busy;

  /// True when the service has an undo snapshot stacked.
  bool get undoAvailable => _undoAvailable;

  /// The last AI reply, or null.
  String? get aiAnswer => _aiAnswer;

  /// The command line the model suggested for `ai capture`, or null.
  String? get aiSuggestion => _aiSuggestion;

  /// Which AI verb produced [aiAnswer].
  TaqvimAiVerb? get aiVerb => _aiVerb;

  /// True while an AI call is in flight.
  bool get aiBusy => _aiBusy;

  /// The service's own rails — the page shows the same limits in its hints.
  TaqvimOptions get options => _service.options;

  /// The service in use (the page hands it to the ICS and sync paths).
  TaqvimService get service => _service;

  /// True when an AI provider is wired (the CLI's `_aiCompletion`).
  bool get aiAvailable => _funnel != null;

  /// The saved sync URL, when a settings store is wired.
  Future<String?> syncUrl() async =>
      (await _settings?.read(SettingKeys.taqvimSyncUrl))?.trim();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── Loading ──

  /// Reloads the calendar, the agenda of the current scope and the counters.
  Future<void> load() async {
    _events = await _service.all();
    await _refreshAgenda();
    _stats = await _service.stats();
    _undoAvailable = await _storeHasUndo();
    final selected = _selected;
    _selected = selected == null ? null : await _service.get(selected.id);
    _safeNotify();
  }

  /// Points the agenda at a scope (and optionally a different anchor day).
  Future<void> setScope(TaqvimScope scope, {DateOnly? anchor}) async {
    _scope = scope;
    if (anchor != null) _anchor = anchor;
    await _refreshAgenda();
    _safeNotify();
  }

  /// Moves the anchor by whole days (the CLI's `today` / `tomorrow` shortcuts).
  Future<void> shiftDays(int days) =>
      setScope(_scope, anchor: _addDays(anchor, days));

  /// Filters the agenda by calendar and/or tag (the CLI's `--calendar` / `--tag`).
  Future<void> setFilters({String? calendar, String? tag}) async {
    _calendarFilter = _cleanFilter(calendar);
    _tagFilter = _cleanFilter(tag);
    _applyFilters();
    _safeNotify();
  }

  /// Selects an event by id (null clears the selection).
  Future<void> select(int? id) async {
    _selected = id == null ? null : await _service.get(id);
    _safeNotify();
  }

  /// Runs a full-text search; an empty query clears the results.
  Future<void> search(String query) async {
    _query = query;
    if (query.trim().isEmpty) {
      _searchResults = const [];
      _error = null;
      _message = null;
      _safeNotify();
      return;
    }
    await _run(() async {
      _searchResults = await _service.search(query);
      return _searchResults.isEmpty
          ? 'Nothing matched "$query".'
          : '${_searchResults.length} event(s) matched "$query".';
    });
  }

  // ── Mutations ──

  /// Creates an event from the editor. Returns the new event, or null on failure.
  Future<TaqvimEvent?> addEvent({
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
    TaqvimEvent? created;
    await _run(() async {
      created = await _service.addEvent(
        title: title,
        start: start,
        end: end,
        allDay: allDay,
        calendar: calendar,
        location: location,
        notes: notes,
        tags: tags,
        rule: rule,
        reminders: reminders,
      );
      return 'Added "${created!.title}".';
    });
    if (created != null) await _afterMutation(selectId: created!.id);
    return created;
  }

  /// Applies the editor's changes to an event.
  Future<TaqvimEvent?> editEvent(
    int id, {
    String? title,
    String? location,
    String? notes,
    String? tags,
    String? calendar,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    Recurrence? rule,
    bool clearRule = false,
    List<int>? reminders,
    bool clearReminders = false,
  }) async {
    TaqvimEvent? updated;
    await _run(() async {
      updated = await _service.editEvent(
        id,
        title: title,
        location: location,
        notes: notes,
        tags: tags,
        calendar: calendar,
        start: start,
        end: end,
        allDay: allDay,
        rule: rule,
        clearRule: clearRule,
        reminders: reminders,
        clearReminders: clearReminders,
      );
      return 'Saved "${updated!.title}".';
    });
    if (updated != null) await _afterMutation(selectId: id);
    return updated;
  }

  /// Moves an event to a new start, keeping its duration (`taqvim reschedule`).
  Future<TaqvimEvent?> reschedule(
    int id,
    DateTime start, {
    DateTime? end,
  }) async {
    TaqvimEvent? moved;
    await _run(() async {
      moved = await _service.reschedule(id, start, newEnd: end);
      return 'Moved "${moved!.title}".';
    });
    if (moved != null) await _afterMutation(selectId: id);
    return moved;
  }

  /// Sets (or clears) the repeat rule (`taqvim repeat`).
  Future<TaqvimEvent?> setRule(int id, Recurrence? rule) async {
    TaqvimEvent? updated;
    await _run(() async {
      updated = await _service.setRule(id, rule);
      return rule == null
          ? 'The event no longer repeats.'
          : 'It repeats ${rule.describe()}.';
    });
    if (updated != null) await _afterMutation(selectId: id);
    return updated;
  }

  /// Sets (or clears) the reminders (`taqvim remind`).
  Future<TaqvimEvent?> setReminders(int id, List<int> reminders) async {
    TaqvimEvent? updated;
    await _run(() async {
      updated = await _service.setReminders(id, reminders);
      return updated!.reminders.isEmpty
          ? 'Reminders cleared.'
          : 'Reminding ${TaqvimText.remindersToCsv(updated!.reminders)} '
                'minutes before.';
    });
    if (updated != null) await _afterMutation(selectId: id);
    return updated;
  }

  /// Deletes an event (`taqvim delete`). The undo button brings it back.
  Future<bool> delete(int id) async {
    var removed = false;
    await _run(() async {
      final ev = await _service.delete(id);
      removed = true;
      return 'Deleted "${ev.title}" — undo restores it.';
    });
    if (removed) {
      _selected = null;
      await _afterMutation();
    }
    return removed;
  }

  /// Reverts the most recent mutation (`taqvim undo`).
  Future<bool> undo() async {
    var reverted = false;
    await _run(() async {
      reverted = await _service.undo();
      return reverted ? 'Undone.' : 'Nothing left to undo.';
    });
    await _afterMutation();
    return reverted;
  }

  /// Imports an .ics document (`taqvim import`).
  Future<List<TaqvimEvent>> importIcs(String content) async {
    var imported = const <TaqvimEvent>[];
    await _run(() async {
      imported = await _service.importIcs(content);
      return 'Imported ${imported.length} event(s).';
    });
    await _afterMutation();
    return imported;
  }

  /// Exports the whole calendar as one .ics document (`taqvim export`).
  Future<String> exportIcs() => _service.exportIcs();

  /// Copies the selected event's fields into a fresh draft (`taqvim add --from`-style clone).
  TaqvimEvent? duplicateDraft() {
    final selected = _selected;
    if (selected == null) return null;
    return selected.copyWith(
      id: 0,
      syncId: '',
      title: '${selected.title} (copy)',
    );
  }

  /// Parses a natural-language sentence into an unsaved event (`taqvim capture`).
  ///
  /// Returns null when the sentence carries no date/time signal — nothing is invented.
  CaptureResult? capture(String sentence) =>
      TaqvimCapture.tryParse(sentence, _clock().toUtc());

  // ── Windows ──

  /// Computes the free windows of [day] (`taqvim free`).
  Future<List<FreeSlot>> computeFreeSlots(
    DateOnly day,
    ClockTime from,
    ClockTime to,
    int minMinutes,
  ) async {
    var slots = const <FreeSlot>[];
    await _run(() async {
      slots = await _service.freeSlots(day, from, to, minMinutes);
      _freeSlots = slots;
      return slots.isEmpty
          ? 'No gap of $minMinutes minutes in that window.'
          : '${slots.length} free window(s).';
    });
    return slots;
  }

  /// Clears the last free-slot computation.
  void clearFreeSlots() {
    _freeSlots = const [];
    _safeNotify();
  }

  // ── AI (`taqvim ai …`) ──

  /// Summarises the anchor day (`ai brief`).
  Future<void> aiBrief() async {
    final day = await _service.day(anchor);
    await _ask(
      TaqvimAiVerb.brief,
      () => _assistant.buildBriefPrompt(day, _clock().toUtc()),
    );
  }

  /// Suggests a plan for the anchor week, with its free windows and the open tasks
  /// (`ai plan`).
  Future<void> aiPlan() async {
    final day = anchor;
    final week = await _service.week(day);
    final free = <String>[];
    for (var offset = 0; offset < 7; offset++) {
      final target = _addDays(day, offset);
      final slots = await _service.freeSlots(
        target,
        TaqvimText.parseClock(TaqvimDefaults.workingDayStart, 'work day start'),
        TaqvimText.parseClock(TaqvimDefaults.workingDayEnd, 'work day end'),
        TaqvimDefaults.defaultFreeSlotMinutes,
      );
      for (final slot in slots) {
        free.add(
          '${_shortDay(target)} ${_hhmm(slot.start)}-${_hhmm(slot.end)} '
          '(${slot.end.difference(slot.start).inMinutes} min free)',
        );
      }
    }

    final due = await _dueTasks?.call() ?? const <String>[];
    final open = [
      for (final task in due.take(TaqvimDefaults.maxDueTasksOnAgenda))
        'open task: ${TaqvimText.clip(task, 120)}',
    ];

    await _ask(
      TaqvimAiVerb.plan,
      () => _assistant.buildPlanPrompt(week, [...free, ...open]),
    );
  }

  /// Answers a question over the upcoming week (`ai ask`).
  Future<void> aiAsk(String question) async {
    final now = _clock().toUtc();
    final context = await _service.occurrences(
      now,
      now.add(const Duration(days: 7)),
    );
    await _ask(
      TaqvimAiVerb.ask,
      () => _assistant.buildAskPrompt(question, context),
    );
  }

  /// Turns a sentence into a command line (`ai capture`). The reply is scanned for the
  /// suggested `taqvim add …` line, which the page offers to copy — exactly what the CLI
  /// printed after "Suggestion (copy, check, then run)".
  Future<void> aiCapture(String sentence) async {
    await _ask(
      TaqvimAiVerb.capture,
      () => ScheduleAssistant.buildCapturePrompt(sentence, _clock().toUtc()),
    );
    final reply = _aiAnswer;
    _aiSuggestion = reply == null
        ? null
        : ScheduleAssistant.parseCapture(reply);
    _safeNotify();
  }

  /// Clears the AI pane.
  void clearAiAnswer() {
    _aiAnswer = null;
    _aiSuggestion = null;
    _aiVerb = null;
    _safeNotify();
  }

  // ── Internals ──

  Future<void> _ask(TaqvimAiVerb verb, String Function() build) async {
    final funnel = _funnel;
    if (funnel == null) {
      _error = 'AI is not available in this context.';
      _safeNotify();
      return;
    }

    _aiVerb = verb;
    _aiSuggestion = null;
    _aiBusy = true;
    _error = null;
    _safeNotify();
    try {
      _aiAnswer = await funnel.completeText(build());
    } on Object catch (failure) {
      _error = '$failure';
    } finally {
      _aiBusy = false;
      _safeNotify();
    }
  }

  Future<void> _refreshAgenda() async {
    final day = anchor;
    _scopeOccurrences = switch (_scope) {
      TaqvimScope.today => await _service.day(day),
      TaqvimScope.tomorrow => await _service.day(_addDays(day, 1)),
      TaqvimScope.week => await _service.week(day),
      TaqvimScope.month => await _service.month(day.year, day.month),
      TaqvimScope.upcoming => await _service.occurrences(
        _clock().toUtc(),
        _clock().toUtc().add(Duration(days: options.maxAgendaDays)),
      ),
    };
    _applyFilters();
    _conflicts = await _service.conflicts(_windowStart(day), _windowEnd(day));
  }

  void _applyFilters() {
    final calendar = _calendarFilter?.toLowerCase();
    final tag = _tagFilter?.toLowerCase();
    _agenda = [
      for (final occurrence in _scopeOccurrences)
        if ((calendar == null ||
                occurrence.event.calendar.toLowerCase() == calendar) &&
            (tag == null ||
                TaqvimText.tagsOf(
                  occurrence.event,
                ).any((value) => value.toLowerCase() == tag)))
          occurrence,
    ];
  }

  /// The window the current scope covers, used for the conflict sweep.
  DateTime _windowStart(DateOnly day) => switch (_scope) {
    TaqvimScope.tomorrow => _addDays(day, 1).toUtcDateTime(),
    TaqvimScope.week => _addDays(day, -(day.weekday - 1)).toUtcDateTime(),
    TaqvimScope.month => DateTime.utc(day.year, day.month),
    TaqvimScope.upcoming => _clock().toUtc(),
    TaqvimScope.today => day.toUtcDateTime(),
  };

  DateTime _windowEnd(DateOnly day) => switch (_scope) {
    TaqvimScope.tomorrow => _addDays(day, 2).toUtcDateTime(),
    TaqvimScope.week => _addDays(day, -(day.weekday - 1) + 7).toUtcDateTime(),
    TaqvimScope.month => DateTime.utc(day.year, day.month + 1),
    TaqvimScope.upcoming => _clock().toUtc().add(
      Duration(days: options.maxAgendaDays),
    ),
    TaqvimScope.today => _addDays(day, 1).toUtcDateTime(),
  };

  Future<void> _afterMutation({int? selectId}) async {
    _events = await _service.all();
    await _refreshAgenda();
    _stats = await _service.stats();
    _undoAvailable = await _storeHasUndo();
    if (selectId != null) _selected = await _service.get(selectId);
    _safeNotify();
  }

  Future<bool> _storeHasUndo() async => await _service.store.undoCount > 0;

  /// Runs a mutation, turning any failure into a message instead of a crash.
  Future<void> _run(Future<String> Function() action) async {
    _busy = true;
    _error = null;
    _message = null;
    _safeNotify();
    try {
      _message = await action();
    } on TaqvimException catch (failure) {
      _error = failure.message;
    } on FormatException catch (failure) {
      _error = failure.message;
    } finally {
      _busy = false;
      _safeNotify();
    }
  }

  static String? _cleanFilter(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _hhmm(DateTime instant) {
    final local = instant.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _shortDay(DateOnly day) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];

  static DateOnly _addDays(DateOnly day, int days) {
    final shifted = day.toUtcDateTime().add(Duration(days: days));
    return DateOnly(shifted.year, shifted.month, shifted.day);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }
}
