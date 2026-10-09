/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import 'dart:convert';

import '../divan/divan_sync_adapter.dart' show SyncAdapter;
import '../sync/sync_models.dart';
import 'models.dart';
import 'taqvim_service.dart';
import 'taqvim_store.dart';

class TaqvimSyncAdapter implements SyncAdapter {
  TaqvimSyncAdapter({
    required TaqvimService service,
    required TaqvimStore store,
  }) : _service = service,
       _store = store;

  final TaqvimService _service;
  final TaqvimStore _store;

  @override
  String get service => 'taqvim';

  @override
  Future<String> capture() async {
    // Canonical order: by sync identity — never by local row id — so two converged calendars
    // serialize byte-identically even though their local ids diverge.
    final events = await _store.listEvents();
    final tombstones = await _store.getTombstones();

    final sortedEvents = [...events]
      ..sort((a, b) => a.syncId.compareTo(b.syncId));
    final sortedTombstones = [...tombstones]
      ..sort((a, b) => a.syncId.compareTo(b.syncId));

    return jsonEncode({
      'events': [for (final ev in sortedEvents) _eventToWire(ev)],
      'tombstones': [
        for (final tombstone in sortedTombstones) tombstone.toWire(),
      ],
    });
  }

  @override
  Future<String> merge(
    String localJson,
    String remoteJson,
    String localDeviceId,
    String remoteDeviceId,
  ) async {
    final local = _parse(localJson);
    final remote = _parse(remoteJson);

    // Events: union by sync id; last-write-wins, tombstone beats an equally old event.
    final events = <String, TaqvimEvent>{}; // keyed by sync id
    for (final event in [...local.events, ...remote.events]) {
      if (event.syncId.isEmpty) {
        continue; // cannot merge safely — ignore rather than fork
      }
      final existing = events[event.syncId];
      events[event.syncId] = existing == null
          ? event
          : _pickEvent(existing, event);
    }

    // Tombstones: keep every live one, then reconcile against a live event of the same id.
    final tombstones = <String, TaqvimTombstone>{};
    for (final tombstone in [...local.tombstones, ...remote.tombstones]) {
      if (tombstone.syncId.isEmpty) {
        continue;
      }
      final existing = tombstones[tombstone.syncId];
      tombstones[tombstone.syncId] =
          existing == null || tombstone.deletedAt.isAfter(existing.deletedAt)
          ? tombstone
          : existing;
    }

    for (final tombstone in tombstones.values.toList()) {
      final live = events[tombstone.syncId];
      if (live == null) continue;
      if (!tombstone.deletedAt.isBefore(live.updatedAt)) {
        events.remove(tombstone.syncId); // the deletion is newer — it stands
      } else {
        tombstones.remove(tombstone.syncId); // the edit is newer — resurrect
      }
    }

    return jsonEncode({
      'events': [for (final event in events.values) _eventToWire(event)],
      'tombstones': [
        for (final tombstone in tombstones.values) tombstone.toWire(),
      ],
    });
  }

  @override
  Future<int> apply(String mergedJson) async {
    final merged = _parse(mergedJson);
    await _service.pushUndoSnapshot(); // one undo reverts the whole apply

    var changed = 0;
    final localBySyncId = <String, TaqvimEvent>{
      for (final event in await _store.listEvents())
        if (event.syncId.isNotEmpty) event.syncId: event,
    };

    for (final dto in merged.events) {
      final existing = localBySyncId[dto.syncId];
      if (existing != null) {
        final updated = existing.copyWith(
          calendar: dto.calendar,
          title: dto.title,
          location: dto.location,
          notes: dto.notes,
          tags: dto.tags,
          start: dto.start,
          end: dto.end,
          isAllDay: dto.isAllDay,
          rule: dto.rule,
          clearRule: dto.rule == null,
          reminders: dto.reminders,
          createdAt: dto.createdAt,
          updatedAt: dto.updatedAt,
        );
        if (updated != existing) {
          await _store.updateEvent(updated);
          changed++;
        }
        localBySyncId.remove(dto.syncId);
      } else {
        await _store.addEvent(
          TaqvimEvent(
            id: 0,
            calendar: dto.calendar,
            title: dto.title,
            location: dto.location,
            notes: dto.notes,
            tags: dto.tags,
            start: dto.start,
            end: dto.end,
            isAllDay: dto.isAllDay,
            rule: dto.rule,
            reminders: dto.reminders,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            syncId: dto.syncId,
          ),
        );
        changed++;
      }
    }

    // Local events the merge dropped are tombstoned remotely — delete them here too.
    final deleted = {
      for (final tombstone in merged.tombstones) tombstone.syncId,
    };
    for (final orphan in localBySyncId.values.toList()) {
      if (!deleted.contains(orphan.syncId)) continue;
      final tombstone = merged.tombstones.firstWhere(
        (row) => row.syncId == orphan.syncId,
      );
      await _store.removeEvent(orphan.id, tombstone.deletedAt);
      changed++;
    }

    // Align tombstone timestamps with the payload — when both devices deleted the same event,
    // each recorded its own time; the merged time is canonical for everyone.
    final known = {
      for (final tombstone in await _store.getTombstones())
        tombstone.syncId: tombstone.deletedAt,
    };
    for (final tombstone in merged.tombstones) {
      final current = known[tombstone.syncId];
      if (current == null || current != tombstone.deletedAt) {
        await _store.upsertTombstone(
          TaqvimTombstone(
            syncId: tombstone.syncId,
            deletedAt: tombstone.deletedAt,
          ),
        );
        changed++;
      }
    }

    return changed;
  }

  // ── Internals ──

  /// Parses a wire payload. Garbage is a protocol failure, not an empty calendar.
  _SyncPayload _parse(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded == null) return _SyncPayload.empty();
      if (decoded is! Map) throw const FormatException('not an object');
      final map = decoded.cast<String, Object?>();
      return _SyncPayload(
        events: [
          for (final entry in (map['events'] as List? ?? const []))
            _eventFromWire((entry as Map).cast<String, Object?>()),
        ],
        tombstones: [
          for (final entry in (map['tombstones'] as List? ?? const []))
            _tombstoneFromWire((entry as Map).cast<String, Object?>()),
        ],
      );
    } on FormatException {
      throw const SyncException('The synced Taqvim payload is not valid.');
    } on TypeError {
      throw const SyncException('The synced Taqvim payload is not valid.');
    }
  }

  static Map<String, Object?> _eventToWire(TaqvimEvent ev) => {
    'syncId': ev.syncId,
    'calendar': ev.calendar,
    'title': ev.title,
    'location': ev.location,
    'notes': ev.notes,
    'tags': ev.tags,
    'start': ev.start.toUtc().toIso8601String(),
    'end': ev.end.toUtc().toIso8601String(),
    'isAllDay': ev.isAllDay,
    if (ev.rule != null) 'rule': TaqvimJson.ruleToJson(ev.rule!),
    'reminders': ev.reminders,
    'createdAt': ev.createdAt.toUtc().toIso8601String(),
    'updatedAt': ev.updatedAt.toUtc().toIso8601String(),
  };

  static TaqvimEvent _eventFromWire(Map<String, Object?> json) => TaqvimEvent(
    id: 0,
    calendar: (json['calendar'] as String?) ?? '',
    title: (json['title'] as String?) ?? '',
    location: (json['location'] as String?) ?? '',
    notes: (json['notes'] as String?) ?? '',
    tags: (json['tags'] as String?) ?? '',
    start:
        _time(json['start']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    end:
        _time(json['end']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    isAllDay: json['isAllDay'] as bool? ?? false,
    rule: TaqvimJson.ruleFromJson(json['rule']),
    reminders: [
      for (final value in (json['reminders'] as List? ?? const []))
        (value as num).toInt(),
    ],
    createdAt:
        _time(json['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt:
        _time(json['updatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    syncId: (json['syncId'] as String?) ?? '',
  );

  static TaqvimTombstone _tombstoneFromWire(Map<String, Object?> json) =>
      TaqvimTombstone(
        syncId: (json['syncId'] as String?) ?? '',
        deletedAt:
            _time(json['deletedAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  static TaqvimEvent _pickEvent(TaqvimEvent a, TaqvimEvent b) {
    if (a.updatedAt != b.updatedAt) {
      return a.updatedAt.isAfter(b.updatedAt) ? a : b;
    }

    // Exact time tie: deterministic on every device — the lexicographically greater
    // serialization wins, so no ping-pong.
    final left = jsonEncode(_eventToWire(a));
    final right = jsonEncode(_eventToWire(b));
    return left.compareTo(right) >= 0 ? a : b;
  }
}

extension on TaqvimTombstone {
  /// The wire form: sync id plus a round-trip UTC stamp.
  Map<String, Object?> toWire() => {
    'syncId': syncId,
    'deletedAt': deletedAt.toUtc().toIso8601String(),
  };
}

class _SyncPayload {
  const _SyncPayload({required this.events, required this.tombstones});

  factory _SyncPayload.empty() =>
      const _SyncPayload(events: [], tombstones: []);

  final List<TaqvimEvent> events;
  final List<TaqvimTombstone> tombstones;
}
