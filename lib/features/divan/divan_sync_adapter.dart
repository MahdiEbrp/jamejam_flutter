/// divan — see doc/divan.md and AGENTS.md
import 'dart:convert';

import '../sync/sync_client.dart';
import '../sync/sync_envelope.dart';
import '../sync/sync_models.dart';
import 'divan_defaults.dart';
import 'divan_service.dart';
import 'divan_store.dart';
import 'models.dart';

abstract interface class SyncAdapter {
  /// The service tag this adapter exchanges (must match the envelope's service field).
  String get service;

  /// Serializes the current local state into payload JSON.
  Future<String> capture();

  /// Merges two payload documents into one.
  ///
  /// Must be deterministic and commutative: `merge(a, b)` and `merge(b, a)` yield the same
  /// bytes on any device, so both sides converge without ever talking to each other.
  Future<String> merge(
    String localJson,
    String remoteJson,
    String localDeviceId,
    String remoteDeviceId,
  );

  /// Applies a merged payload locally. Returns how many records changed.
  Future<int> apply(String mergedJson);
}

class SyncRun {
  const SyncRun({
    required this.mode,
    required this.applied,
    required this.pushed,
    required this.firstSync,
  });

  /// The mode that ran.
  final SyncMode mode;

  /// Records changed locally by the merge (0 when local was already current).
  final int applied;

  /// True when the remote document was (re)written.
  final bool pushed;

  /// True when the remote was empty and this run seeded it.
  final bool firstSync;

  /// Human-friendly summary (culture-invariant).
  String describe() {
    if (mode == SyncMode.push) {
      return 'Pushed the local state — remote replaced.';
    }
    if (mode == SyncMode.pull) {
      return 'Pulled: $applied record(s) changed locally.';
    }
    if (firstSync) {
      return "First sync — the remote was empty and now holds this device's state.";
    }
    return 'Merged: $applied record(s) changed locally.';
  }

  @override
  String toString() => describe();
}

abstract final class SyncEngine {
  /// Runs one sync exchange.
  ///
  /// [SyncMode.merge] is the default; [SyncMode.pull] never writes the remote;
  /// [SyncMode.push] replaces it and needs [force] when the remote differs.
  static Future<SyncRun> run(
    SyncClient client,
    SyncAdapter adapter, {
    required String deviceId,
    required String deviceName,
    SyncMode mode = SyncMode.merge,
    bool force = false,
    DateTime? now,
  }) async {
    if (adapter.service.trim().isEmpty) {
      throw const SyncException('Sync requires a service tag.');
    }
    if (deviceId.trim().isEmpty) {
      throw const SyncException('Sync requires a device id.');
    }

    final stamp = now?.toUtc() ?? DateTime.now().toUtc();
    final local = await adapter.capture();
    final remoteJson = await client.get();

    if (remoteJson == null) {
      if (mode == SyncMode.pull) {
        return SyncRun(mode: mode, applied: 0, pushed: false, firstSync: false);
      }

      await _put(client, adapter, local, deviceId, deviceName, stamp);
      return SyncRun(mode: mode, applied: 0, pushed: true, firstSync: true);
    }

    final remote = SyncSafety.open(remoteJson);
    if (remote.service.toLowerCase() != adapter.service.toLowerCase()) {
      throw SyncException(
        "That URL holds '${remote.service}' data from device "
        '${remote.deviceName.isEmpty ? remote.deviceId : remote.deviceName}; '
        "'${adapter.service}' cannot merge with it. Choose another URL.",
      );
    }

    if (mode == SyncMode.push) {
      if (remote.payload != local && !force) {
        throw SyncException(
          'The remote holds changes (last sealed by device '
          '${remote.deviceName.isEmpty ? remote.deviceId : remote.deviceName}). '
          'Pushing replaces them — confirm to overwrite.',
        );
      }

      await _put(client, adapter, local, deviceId, deviceName, stamp);
      return SyncRun(mode: mode, applied: 0, pushed: true, firstSync: false);
    }

    // Nothing to do when the remote is byte-identical to local — the common case once both
    // devices have converged; avoids a merge pass and a write entirely.
    if (remote.payload == local) {
      return SyncRun(mode: mode, applied: 0, pushed: false, firstSync: false);
    }

    final merged = await adapter.merge(
      local,
      remote.payload,
      deviceId,
      remote.deviceId,
    );

    final applied = merged == local ? 0 : await adapter.apply(merged);
    if (mode == SyncMode.pull) {
      return SyncRun(
        mode: mode,
        applied: applied,
        pushed: false,
        firstSync: false,
      );
    }

    final pushed = merged != remote.payload;
    if (pushed) {
      await _put(client, adapter, merged, deviceId, deviceName, stamp);
    }

    return SyncRun(
      mode: mode,
      applied: applied,
      pushed: pushed,
      firstSync: false,
    );
  }

  static Future<void> _put(
    SyncClient client,
    SyncAdapter adapter,
    String payload,
    String deviceId,
    String deviceName,
    DateTime stamp,
  ) async {
    final envelope = SyncSafety.seal(
      service: adapter.service,
      payload: payload,
      deviceId: deviceId,
      deviceName: deviceName,
      now: stamp,
    );
    await client.put(envelope.toJson());
  }
}

class DivanSyncAdapter implements SyncAdapter {
  DivanSyncAdapter({
    required DivanService service,
    required DivanStore store,
    required DateTime Function() clock,
  }) : _service = service,
       _store = store,
       _clock = clock;

  final DivanService _service;
  final DivanStore _store;
  final DateTime Function() _clock;

  @override
  String get service => 'divan';

  @override
  Future<String> capture() async {
    final notebooks = await _store.listNotebooks();
    final names = {
      for (final notebook in notebooks) notebook.id: notebook.name,
    };

    final notes = await _store.listNotes();
    final tombstones = await _store.getTombstones();

    // Canonical order: by sync identity (notes/tombstones) and name (notebooks) — never by
    // local row id, which is device-local. Two converged pads serialize byte-identically
    // even though their local ids diverge.
    final sortedNotebooks = notebooks.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final sortedNotes = notes.toList()
      ..sort((a, b) => a.syncId.compareTo(b.syncId));
    final sortedTombstones = tombstones.toList()
      ..sort((a, b) => a.syncId.compareTo(b.syncId));

    return jsonEncode({
      'notebooks': [
        for (final notebook in sortedNotebooks)
          {
            'name': notebook.name,
            'archived': notebook.isArchived,
            'updatedAt': (notebook.updatedAt ?? notebook.createdAt)
                .toUtc()
                .toIso8601String(),
          },
      ],
      'notes': [
        for (final note in sortedNotes)
          {
            'syncId': note.syncId,
            'notebook': names[note.notebookId] ?? '',
            'title': note.title,
            'body': note.body,
            'tags': note.tags,
            'pinned': note.pinned,
            'archived': note.archived,
            'createdAt': note.createdAt.toUtc().toIso8601String(),
            'updatedAt': note.updatedAt.toUtc().toIso8601String(),
          },
      ],
      'tombstones': [
        for (final tombstone in sortedTombstones)
          {
            'syncId': tombstone.syncId,
            'deletedAt': tombstone.deletedAt.toUtc().toIso8601String(),
          },
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

    // Notebooks: union by case-insensitive name; the archive flag goes to the record that
    // changed last, ties stay unarchived so data is never hidden.
    final notebooks = <String, _NotebookDto>{};
    for (final notebook in [...local.notebooks, ...remote.notebooks]) {
      final key = notebook.name.trim().toLowerCase();
      final existing = notebooks[key];
      notebooks[key] = existing == null
          ? notebook
          : _pickNotebook(existing, notebook);
    }

    // Notes: union by sync id; last-write-wins, tombstone beats an equally old note.
    final notes = <String, _NoteDto>{};
    for (final note in [...local.notes, ...remote.notes]) {
      final existing = notes[note.syncId];
      notes[note.syncId] = existing == null ? note : _pickNote(existing, note);
    }

    // Tombstones: keep every live one, then reconcile each against a live note of the same
    // sync id — the newer operation wins (equal times: the deletion stands).
    final tombstones = <String, _TombstoneDto>{};
    for (final tombstone in [...local.tombstones, ...remote.tombstones]) {
      if (tombstone.syncId.isEmpty) continue;
      final existing = tombstones[tombstone.syncId];
      if (existing == null ||
          _isLater(tombstone.deletedAt, existing.deletedAt)) {
        tombstones[tombstone.syncId] = tombstone;
      }
    }

    for (final tombstone in tombstones.values.toList()) {
      final live = notes[tombstone.syncId];
      if (live == null) continue;

      final deletedAt = tombstone.deletedAt ?? _epoch;
      if (deletedAt.compareTo(live.updatedAt ?? _epoch) >= 0) {
        notes.remove(tombstone.syncId); // the deletion is newer — it stands
      } else {
        tombstones.remove(tombstone.syncId); // the edit is newer — resurrect
      }
    }

    return jsonEncode({
      'notebooks': [for (final notebook in notebooks.values) notebook.toJson()],
      'notes': [for (final note in notes.values) note.toJson()],
      'tombstones': [
        for (final tombstone in tombstones.values) tombstone.toJson(),
      ],
    });
  }

  @override
  Future<int> apply(String mergedJson) async {
    final merged = _parse(mergedJson);
    await _service.pushUndoSnapshot(); // one `undo` reverts the whole apply

    var changed = 0;
    final now = _clock().toUtc();

    // 1) Notebooks by name — existing ones keep their ids.
    final notebookIds = <String, int>{};
    for (final notebook in merged.notebooks) {
      final name = DivanText.clip(
        notebook.name.trim(),
        DivanDefaults.maxNotebookNameLength,
      );
      if (name.isEmpty) continue;

      final key = name.toLowerCase();
      final existing = await _store.findNotebookByName(name);
      if (existing != null) {
        notebookIds[key] = existing.id;
        // Align everything the payload carries — the archive flag AND the timestamp —
        // otherwise two devices never converge on the notebook's last-write time.
        if (existing.isArchived != notebook.archived ||
            existing.updatedAt != notebook.updatedAt) {
          await _store.updateNotebook(
            existing.copyWith(
              isArchived: notebook.archived,
              updatedAt: notebook.updatedAt,
            ),
          );
          changed++;
        }
      } else {
        final created = await _store.addNotebook(
          Notebook(
            id: 0,
            name: name,
            createdAt: notebook.updatedAt == null ? now : notebook.updatedAt!,
            isArchived: notebook.archived,
            updatedAt: notebook.updatedAt,
          ),
        );
        notebookIds[key] = created.id;
        changed++;
      }
    }

    final fallbackNotebook = notebookIds.values.isEmpty
        ? 0
        : notebookIds.values.reduce((a, b) => a < b ? a : b);

    final localBySyncId = <String, Note>{};
    for (final note in await _store.listNotes()) {
      if (note.syncId.isNotEmpty) localBySyncId[note.syncId] = note;
    }

    // 2) Notes by sync id — local rows keep their ids; foreign rows are inserted.
    for (final note in merged.notes) {
      if (note.syncId.isEmpty) {
        continue; // cannot be merged safely — ignore, do not fork
      }

      if (fallbackNotebook == 0 &&
          !notebookIds.containsKey(_key(note.notebook))) {
        continue; // no notebook to attach to — leave for the next sync
      }

      final notebookId = _resolveNotebookId(
        note.notebook,
        notebookIds,
        fallbackNotebook,
      );
      final existing = localBySyncId.remove(note.syncId);
      if (existing != null) {
        final updated = existing.copyWith(
          notebookId: notebookId,
          title: note.title,
          body: note.body,
          tags: note.tags,
          pinned: note.pinned,
          archived: note.archived,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
        );
        if (updated != existing) {
          await _store.updateNote(updated);
          changed++;
        }
      } else {
        await _store.addNote(
          Note(
            notebookId: notebookId,
            title: note.title,
            body: note.body,
            tags: note.tags,
            pinned: note.pinned,
            archived: note.archived,
            createdAt: note.createdAt ?? now,
            updatedAt: note.updatedAt ?? now,
            syncId: note.syncId,
          ),
        );
        changed++;
      }
    }

    // 3) Local notes the merge dropped are tombstoned remotely — delete them here too.
    final live = merged.tombstones.map((tombstone) => tombstone.syncId).toSet();
    for (final orphan in localBySyncId.values) {
      if (!live.contains(orphan.syncId)) continue;
      final tombstone = merged.tombstones.firstWhere(
        (entry) => entry.syncId == orphan.syncId,
      );
      await _store.removeNote(orphan.id, tombstone.deletedAt ?? now);
      changed++;
    }

    // 4) Align tombstone timestamps with the payload — when both devices deleted the same
    // note each recorded its own time; the merged time is canonical for everyone.
    final known = {
      for (final tombstone in await _store.getTombstones())
        tombstone.syncId: tombstone.deletedAt,
    };
    for (final tombstone in merged.tombstones) {
      final current = known[tombstone.syncId];
      if (current == null || current != tombstone.deletedAt) {
        await _store.upsertTombstone(
          DivanTombstone(
            syncId: tombstone.syncId,
            deletedAt: tombstone.deletedAt ?? now,
          ),
        );
      }
    }

    return changed;
  }

  /// An unparseable timestamp sorts to the epoch — it never wins a tie.
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  /// True when [left] is strictly later than [right]; nulls sort to the epoch.
  static bool _isLater(DateTime? left, DateTime? right) =>
      (left ?? _epoch).isAfter(right ?? _epoch);

  static String _key(String name) => name.trim().toLowerCase();

  static int _resolveNotebookId(
    String name,
    Map<String, int> ids,
    int fallback,
  ) => ids[_key(name)] ?? fallback;

  /// Parses a wire payload. Garbage is a protocol failure, not an empty pad.
  static _Payload _parse(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded == null) return _Payload.empty();
      if (decoded is! Map) throw const FormatException('not an object');
      return _Payload.fromJson(decoded.cast<String, dynamic>());
    } on FormatException catch (error) {
      throw SyncException(
        'The synced Divan payload is not valid.',
        statusCode: null,
      ).withCause(error.toString());
    }
  }

  static _NotebookDto _pickNotebook(_NotebookDto a, _NotebookDto b) {
    final aTime = a.updatedAt;
    final bTime = b.updatedAt;
    if (aTime != bTime) {
      if (aTime == null) return b;
      if (bTime == null) return a;
      return aTime.isAfter(bTime) ? a : b;
    }

    return a.copyWith(
      archived: a.archived && b.archived,
    ); // exact tie: never hide data
  }

  static _NoteDto _pickNote(_NoteDto a, _NoteDto b) {
    final aTime = a.updatedAt;
    final bTime = b.updatedAt;
    if (aTime != bTime) {
      if (aTime == null) return b;
      if (bTime == null) return a;
      return aTime.isAfter(bTime) ? a : b;
    }

    // Exact time tie: a deletion beats an equally old edit; two live versions resolve by a
    // checksum of their JSON — deterministic on every device, no ping-pong.
    if (!a.archived && !b.archived) {
      return jsonEncode(a.toJson()).compareTo(jsonEncode(b.toJson())) >= 0
          ? a
          : b;
    }

    return a.archived ? a : b;
  }
}

extension on SyncException {
  /// Attaches the parse cause to the message (the .NET exception carried an inner one).
  SyncException withCause(String cause) =>
      SyncException('$message ($cause)', statusCode: statusCode);
}

class _Payload {
  const _Payload({
    required this.notebooks,
    required this.notes,
    required this.tombstones,
  });

  factory _Payload.empty() =>
      const _Payload(notebooks: [], notes: [], tombstones: []);

  factory _Payload.fromJson(Map<String, dynamic> json) => _Payload(
    notebooks: [
      for (final entry in (json['notebooks'] as List? ?? const []))
        _NotebookDto.fromJson((entry as Map).cast<String, dynamic>()),
    ],
    notes: [
      for (final entry in (json['notes'] as List? ?? const []))
        _NoteDto.fromJson((entry as Map).cast<String, dynamic>()),
    ],
    tombstones: [
      for (final entry in (json['tombstones'] as List? ?? const []))
        _TombstoneDto.fromJson((entry as Map).cast<String, dynamic>()),
    ],
  );

  final List<_NotebookDto> notebooks;
  final List<_NoteDto> notes;
  final List<_TombstoneDto> tombstones;
}

class _NotebookDto {
  const _NotebookDto({
    required this.name,
    required this.archived,
    required this.updatedAt,
  });

  factory _NotebookDto.fromJson(Map<String, dynamic> json) => _NotebookDto(
    name: (json['name'] as String?) ?? '',
    archived: json['archived'] as bool? ?? false,
    updatedAt: _time(json['updatedAt']),
  );

  final String name;
  final bool archived;
  final DateTime? updatedAt;

  _NotebookDto copyWith({bool? archived}) => _NotebookDto(
    name: name,
    archived: archived ?? this.archived,
    updatedAt: updatedAt,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'archived': archived,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}

class _NoteDto {
  const _NoteDto({
    required this.syncId,
    required this.notebook,
    required this.title,
    required this.body,
    required this.tags,
    required this.pinned,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _NoteDto.fromJson(Map<String, dynamic> json) => _NoteDto(
    syncId: (json['syncId'] as String?) ?? '',
    notebook: (json['notebook'] as String?) ?? '',
    title: (json['title'] as String?) ?? '',
    body: (json['body'] as String?) ?? '',
    tags: (json['tags'] as String?) ?? '',
    pinned: json['pinned'] as bool? ?? false,
    archived: json['archived'] as bool? ?? false,
    createdAt: _time(json['createdAt']),
    updatedAt: _time(json['updatedAt']),
  );

  final String syncId;
  final String notebook;
  final String title;
  final String body;
  final String tags;
  final bool pinned;
  final bool archived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => {
    'syncId': syncId,
    'notebook': notebook,
    'title': title,
    'body': body,
    'tags': tags,
    'pinned': pinned,
    'archived': archived,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}

class _TombstoneDto {
  const _TombstoneDto({required this.syncId, required this.deletedAt});

  factory _TombstoneDto.fromJson(Map<String, dynamic> json) => _TombstoneDto(
    syncId: (json['syncId'] as String?) ?? '',
    deletedAt: _time(json['deletedAt']),
  );

  final String syncId;
  final DateTime? deletedAt;

  Map<String, Object?> toJson() => {
    'syncId': syncId,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
}

DateTime? _time(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
