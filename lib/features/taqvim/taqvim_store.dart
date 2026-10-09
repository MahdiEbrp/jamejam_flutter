/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import 'dart:convert';

import '../../core/date_only.dart';
import '../../core/uids.dart';
import 'models.dart';
import 'taqvim_defaults.dart';

abstract interface class TaqvimStore {
  /// Inserts an event and returns it with its assigned id and sync identity.
  Future<TaqvimEvent> addEvent(TaqvimEvent event);

  /// Overwrites an existing event (same id). Throws [TaqvimException] for a missing row.
  Future<void> updateEvent(TaqvimEvent event);

  /// Removes an event, recording a tombstone (keyed by sync id) so other devices learn of
  /// the deletion. Returns true when it existed.
  Future<bool> removeEvent(int id, DateTime deletedAt);

  /// Gets an event by id, or null.
  Future<TaqvimEvent?> findEvent(int id);

  /// Lists all events ordered by start, then id.
  Future<List<TaqvimEvent>> listEvents();

  /// Full-text search over title, notes and location; returns event ids best-first, at most
  /// [limit]. Every term must match (AND semantics).
  Future<List<int>> searchIds(String query, int limit);

  /// Replaces every event with the given ones (undo restore); ids are preserved.
  Future<void> replaceEvents(List<TaqvimEvent> events);

  /// Pushes an undo snapshot (a JSON payload produced by the service).
  Future<void> pushUndo(String payload);

  /// Pops the most recent undo snapshot, or null when the stack is empty.
  Future<String?> popUndo();

  /// How many undo snapshots are currently stacked.
  Future<int> get undoCount;

  /// Maximum undo snapshots kept; pushing beyond the depth drops the oldest.
  ///
  /// Defaults to [TaqvimDefaults.undoDepth]; values below zero are rejected.
  int get undoDepth;

  set undoDepth(int value);

  /// Lists live tombstones — deletions whose event does not exist locally.
  Future<List<TaqvimTombstone>> getTombstones();

  /// Records (or re-times) a tombstone so every device agrees on when a deletion happened.
  Future<void> upsertTombstone(TaqvimTombstone tombstone);
}

class MemoryTaqvimStore implements TaqvimStore {
  final List<TaqvimEvent> _events = [];
  final List<String> _undo = [];
  final Map<String, DateTime> _tombstones = {};

  int _undoDepthValue = TaqvimDefaults.undoDepth;

  @override
  int get undoDepth => _undoDepthValue;

  @override
  set undoDepth(int value) {
    if (value < 0) {
      throw const TaqvimException('UndoDepth must not be negative.');
    }
    _undoDepthValue = value;
  }

  /// One past the highest id in use — what the SQLite autoincrement does after a restore.
  int get _nextEventId {
    var highest = 0;
    for (final event in _events) {
      if (event.id > highest) highest = event.id;
    }
    return highest + 1;
  }

  @override
  Future<TaqvimEvent> addEvent(TaqvimEvent event) async {
    final stored = event.copyWith(
      id: _nextEventId,
      syncId: event.syncId.isEmpty ? Uids.newUid() : event.syncId,
    );
    _events.add(stored);
    return stored;
  }

  @override
  Future<void> updateEvent(TaqvimEvent event) async {
    final index = _events.indexWhere((row) => row.id == event.id);
    if (index < 0) {
      throw TaqvimException('No event #${event.id}.');
    }
    _events[index] = event;
  }

  @override
  Future<bool> removeEvent(int id, DateTime deletedAt) async {
    final event = _events.where((row) => row.id == id).firstOrNull;
    if (event == null) return false;

    if (event.syncId.isNotEmpty) {
      _tombstones[event.syncId] = deletedAt;
    }
    _events.removeWhere((row) => row.id == id);
    return true;
  }

  @override
  Future<TaqvimEvent?> findEvent(int id) async =>
      _events.where((row) => row.id == id).firstOrNull;

  @override
  Future<List<TaqvimEvent>> listEvents() async {
    final sorted = [..._events]
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });
    return sorted;
  }

  @override
  Future<List<int>> searchIds(String query, int limit) async {
    if (query.trim().isEmpty) {
      throw const TaqvimException('A search query must not be empty.');
    }

    final terms = query
        .split(' ')
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList();
    final scored = <({int id, int score})>[];
    for (final event in _events) {
      var score = 0;
      var all = true;
      for (final term in terms) {
        final needle = term.toLowerCase();
        final inTitle = event.title.toLowerCase().contains(needle);
        final inBody =
            event.notes.toLowerCase().contains(needle) ||
            event.location.toLowerCase().contains(needle);
        if (!inTitle && !inBody) {
          all = false;
          break;
        }
        score += inTitle ? 2 : 1;
      }
      if (all) scored.add((id: event.id, score: score));
    }

    // Score first, then the newest edit — the .NET ordered exactly this way.
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final aAt = _events.firstWhere((row) => row.id == a.id).updatedAt;
      final bAt = _events.firstWhere((row) => row.id == b.id).updatedAt;
      return bAt.compareTo(aAt);
    });

    return [for (final row in scored.take(limit)) row.id];
  }

  @override
  Future<void> replaceEvents(List<TaqvimEvent> events) async {
    _events
      ..clear()
      ..addAll(events)
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });
    for (final event in _events) {
      if (event.syncId.isNotEmpty) {
        _tombstones.remove(
          event.syncId,
        ); // restored events retract their tombstones
      }
    }
  }

  @override
  Future<void> pushUndo(String payload) async {
    if (payload.trim().isEmpty) {
      throw const TaqvimException('An undo snapshot must not be empty.');
    }
    _undo.add(payload);
    final depth = undoDepth < 0 ? 0 : undoDepth;
    while (_undo.length > depth) {
      _undo.removeAt(0);
    }
  }

  @override
  Future<String?> popUndo() async {
    if (_undo.isEmpty) return null;
    return _undo.removeLast();
  }

  @override
  Future<int> get undoCount async => _undo.length;

  @override
  Future<List<TaqvimTombstone>> getTombstones() async {
    final live = <TaqvimTombstone>[];
    for (final entry in _tombstones.entries) {
      if (_events.any((row) => row.syncId == entry.key)) continue;
      live.add(TaqvimTombstone(syncId: entry.key, deletedAt: entry.value));
    }
    live.sort((a, b) => a.syncId.compareTo(b.syncId));
    return live;
  }

  @override
  Future<void> upsertTombstone(TaqvimTombstone tombstone) async {
    if (tombstone.syncId.isEmpty) return;
    _tombstones[tombstone.syncId] = tombstone.deletedAt;
  }
}

class TaqvimEventDto {
  const TaqvimEventDto({
    required this.id,
    required this.calendar,
    required this.title,
    required this.location,
    required this.notes,
    required this.tags,
    required this.start,
    required this.end,
    required this.isAllDay,
    required this.rule,
    required this.reminders,
    required this.createdAt,
    required this.updatedAt,
    required this.syncId,
  });

  final int id;
  final String calendar;
  final String title;
  final String location;
  final String notes;
  final String tags;
  final String start;
  final String end;
  final bool isAllDay;
  final Recurrence? rule;
  final List<int> reminders;
  final String createdAt;
  final String updatedAt;
  final String syncId;

  /// Converts an event to its snapshot DTO (instants as round-trip UTC strings).
  static TaqvimEventDto from(TaqvimEvent ev) => TaqvimEventDto(
    id: ev.id,
    calendar: ev.calendar,
    title: ev.title,
    location: ev.location,
    notes: ev.notes,
    tags: ev.tags,
    start: TaqvimJson.stamp(ev.start),
    end: TaqvimJson.stamp(ev.end),
    isAllDay: ev.isAllDay,
    rule: ev.rule,
    reminders: ev.reminders,
    createdAt: TaqvimJson.stamp(ev.createdAt),
    updatedAt: TaqvimJson.stamp(ev.updatedAt),
    syncId: ev.syncId,
  );

  /// Converts a snapshot DTO back into an event.
  TaqvimEvent toEvent() => TaqvimEvent(
    id: id,
    calendar: calendar,
    title: title,
    location: location,
    notes: notes,
    tags: tags,
    start: DateTime.parse(start).toUtc(),
    end: DateTime.parse(end).toUtc(),
    isAllDay: isAllDay,
    rule: rule,
    reminders: reminders,
    createdAt: DateTime.parse(createdAt).toUtc(),
    updatedAt: DateTime.parse(updatedAt).toUtc(),
    syncId: syncId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'calendar': calendar,
    'title': title,
    'location': location,
    'notes': notes,
    'tags': tags,
    'start': start,
    'end': end,
    'isAllDay': isAllDay,
    if (rule != null) 'rule': TaqvimJson.ruleToJson(rule!),
    'reminders': reminders,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'syncId': syncId,
  };

  static TaqvimEventDto fromJson(Map<String, Object?> json) => TaqvimEventDto(
    id: (json['id'] as num?)?.toInt() ?? 0,
    calendar: (json['calendar'] as String?) ?? '',
    title: (json['title'] as String?) ?? '',
    location: (json['location'] as String?) ?? '',
    notes: (json['notes'] as String?) ?? '',
    tags: (json['tags'] as String?) ?? '',
    start: (json['start'] as String?) ?? '',
    end: (json['end'] as String?) ?? '',
    isAllDay: json['isAllDay'] as bool? ?? false,
    rule: TaqvimJson.ruleFromJson(json['rule']),
    reminders: [
      for (final value in (json['reminders'] as List? ?? const []))
        (value as num).toInt(),
    ],
    createdAt: (json['createdAt'] as String?) ?? '',
    updatedAt: (json['updatedAt'] as String?) ?? '',
    syncId: (json['syncId'] as String?) ?? '',
  );
}

abstract final class TaqvimJson {
  /// Round-trip UTC stamp (`2026-09-21T14:30:00.000Z`).
  static String stamp(DateTime instant) => instant.toUtc().toIso8601String();

  /// Serializes a rule the way the .NET stored it (kind as its number, notes omitted).
  static Map<String, Object?> ruleToJson(Recurrence rule) => {
    'kind': rule.kind.code,
    'interval': rule.interval,
    if (rule.onWeekdays.isNotEmpty) 'onWeekdays': rule.onWeekdays,
    if (rule.count != null) 'count': rule.count,
    if (rule.until != null) 'until': rule.until!.toIso(),
  };

  /// Parses a stored rule, tolerating a missing or unknown shape (null = one-off).
  static Recurrence? ruleFromJson(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<String, Object?>();
    final kindValue = json['kind'];
    final kind = kindValue is num
        ? RecurrenceKind.fromCode(kindValue.toInt())
        : RecurrenceKind.once;
    if (kind == RecurrenceKind.once) return null;

    final untilText = json['until'] as String?;
    return Recurrence(
      kind,
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      onWeekdays: [
        for (final day in (json['onWeekdays'] as List? ?? const []))
          (day as num).toInt(),
      ],
      count: (json['count'] as num?)?.toInt(),
      until: untilText == null ? null : _parseDateOnly(untilText),
    );
  }

  /// The whole calendar as one snapshot document — what undo stores and sync exchanges.
  static String snapshotOf(List<TaqvimEvent> events) => jsonEncode({
    'events': [for (final ev in events) TaqvimEventDto.from(ev).toJson()],
  });

  /// Reads a snapshot document. Garbage is a [TaqvimException], never a silent empty list.
  ///
  /// A literal `null` document decodes to null — the .NET reader's `Deserialize` does the
  /// same, and undo treats it as "nothing to restore" rather than corruption.
  static List<TaqvimEvent>? eventsOf(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded == null) return null;
      if (decoded is! Map) throw const FormatException('not an object');
      final events = (decoded['events'] as List? ?? const []);
      return [
        for (final entry in events)
          TaqvimEventDto.fromJson(
            (entry as Map).cast<String, Object?>(),
          ).toEvent(),
      ];
    } on FormatException {
      throw const TaqvimException('The undo snapshot is unreadable.');
    } on TypeError {
      throw const TaqvimException('The undo snapshot is unreadable.');
    }
  }

  static DateOnly? _parseDateOnly(String text) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (match == null) return null;
    return DateOnly(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}
