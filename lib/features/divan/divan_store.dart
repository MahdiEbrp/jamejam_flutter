/// divan — see doc/divan.md and AGENTS.md
import '../../core/uids.dart';
import 'divan_defaults.dart';
import 'models.dart';

abstract interface class DivanStore {
  /// Inserts a notebook and returns it with its assigned id.
  Future<Notebook> addNotebook(Notebook notebook);

  /// Overwrites an existing notebook (same id).
  Future<void> updateNotebook(Notebook notebook);

  /// Removes a notebook (and, via the service, its notes). Returns true when it existed.
  Future<bool> removeNotebook(int id);

  /// Gets a notebook by id, or null.
  Future<Notebook?> findNotebook(int id);

  /// Gets a notebook by name (case-insensitive), or null.
  Future<Notebook?> findNotebookByName(String name);

  /// Lists all notebooks ordered by id.
  Future<List<Notebook>> listNotebooks();

  /// Inserts a note and returns it with its assigned id and sync identity.
  Future<Note> addNote(Note note);

  /// Overwrites an existing note (same id) and refreshes search indexes.
  Future<void> updateNote(Note note);

  /// Removes a note and records a tombstone (keyed by the note's sync id) so other
  /// devices learn about the deletion. Returns true when it existed.
  Future<bool> removeNote(int id, DateTime deletedAt);

  /// Lists live tombstones — deletions whose note does not exist locally.
  Future<List<DivanTombstone>> getTombstones();

  /// Records (or re-times) a tombstone so every device agrees on when a deletion happened.
  Future<void> upsertTombstone(DivanTombstone tombstone);

  /// Gets a note by id, or null.
  Future<Note?> findNote(int id);

  /// Lists all notes ordered by id.
  Future<List<Note>> listNotes();

  /// Full-text search over title and body; returns note ids best-first, at most [limit].
  ///
  /// Every term must match (AND semantics).
  Future<List<int>> searchIds(String query, int limit);

  /// Replaces every note with the given ones (undo restore); ids are preserved.
  Future<void> replaceNotes(List<Note> notes);

  /// Replaces every notebook with the given ones (undo restore); ids are preserved.
  Future<void> replaceNotebooks(List<Notebook> notebooks);

  /// Pushes an undo snapshot (a JSON payload produced by the service).
  Future<void> pushUndo(String payload);

  /// Pops the most recent undo snapshot, or null when the stack is empty.
  Future<String?> popUndo();

  /// How many undo snapshots are currently stacked.
  Future<int> get undoCount;

  /// Maximum number of undo snapshots kept. Pushing beyond the depth drops the oldest;
  /// values below zero are rejected.
  set undoDepth(int value);

  /// Closes the underlying store (a no-op for the memory implementation).
  Future<void> close();
}

class MemoryDivanStore implements DivanStore {
  final List<Notebook> _notebooks = [];
  final List<Note> _notes = [];
  final List<String> _undo = [];
  final Map<String, DateTime> _tombstones = {};
  int _nextNotebookId = 1;
  int _nextNoteId = 1;
  int _undoDepthValue = DivanDefaults.undoDepth;

  /// A fresh sync identity — the portrait of `Guid.CreateVersion7()`.
  ///
  /// [Uids.newUid] is the shared generator (it stamps the v7 version and variant bits);
  /// a caller can also inject one to make a test deterministic.
  String Function() newSyncId = Uids.newUid;

  @override
  Future<Notebook> addNotebook(Notebook notebook) async {
    final withId = notebook.copyWith(id: _nextNotebookId++);
    _notebooks.add(withId);
    return withId;
  }

  @override
  Future<void> updateNotebook(Notebook notebook) async {
    final index = _notebooks.indexWhere((n) => n.id == notebook.id);
    if (index < 0) {
      throw DivanException('No notebook #${notebook.id}.');
    }
    _notebooks[index] = notebook;
  }

  @override
  Future<bool> removeNotebook(int id) async {
    final existed = _notebooks.any((n) => n.id == id);
    _notebooks.removeWhere((n) => n.id == id);
    return existed;
  }

  @override
  Future<void> close() async {
    // Nothing to release: the memory store owns nothing but its lists.
  }

  @override
  Future<Notebook?> findNotebook(int id) async =>
      _notebooks.where((n) => n.id == id).firstOrNull;

  @override
  Future<Notebook?> findNotebookByName(String name) async => _notebooks
      .where((n) => n.name.toLowerCase() == name.toLowerCase())
      .firstOrNull;

  @override
  Future<List<Notebook>> listNotebooks() async =>
      _notebooks.toList()..sort((a, b) => a.id.compareTo(b.id));

  @override
  Future<Note> addNote(Note note) async {
    final withId = note.copyWith(
      id: _nextNoteId++,
      syncId: note.syncId.isEmpty ? newSyncId() : note.syncId,
    );
    _notes.add(withId);
    return withId;
  }

  @override
  Future<void> updateNote(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index < 0) {
      throw DivanException('No note #${note.id}.');
    }
    _notes[index] = note;
  }

  @override
  Future<bool> removeNote(int id, DateTime deletedAt) async {
    final note = _notes.where((n) => n.id == id).firstOrNull;
    if (note == null) return false;

    if (note.syncId.isNotEmpty) {
      _tombstones[note.syncId] =
          deletedAt; // live deletions are visible to others
    }

    _notes.removeWhere((n) => n.id == id);
    return true;
  }

  @override
  Future<void> upsertTombstone(DivanTombstone tombstone) async {
    if (tombstone.syncId.isEmpty) return;
    _tombstones[tombstone.syncId] = tombstone.deletedAt;
  }

  @override
  Future<List<DivanTombstone>> getTombstones() async {
    final live =
        _tombstones.entries
            .where((entry) => _notes.every((n) => n.syncId != entry.key))
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    return [
      for (final entry in live)
        DivanTombstone(syncId: entry.key, deletedAt: entry.value),
    ];
  }

  @override
  Future<Note?> findNote(int id) async =>
      _notes.where((n) => n.id == id).firstOrNull;

  @override
  Future<List<Note>> listNotes() async =>
      _notes.toList()..sort((a, b) => a.id.compareTo(b.id));

  @override
  Future<List<int>> searchIds(String query, int limit) async {
    final terms = query
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    final scored = <({int id, int score, DateTime updatedAt})>[];
    for (final note in _notes) {
      var score = 0;
      var all = true;
      for (final term in terms) {
        final inTitle = note.title.toLowerCase().contains(term.toLowerCase());
        final inBody = note.body.toLowerCase().contains(term.toLowerCase());
        if (!inTitle && !inBody) {
          all = false;
          break;
        }

        score += inTitle ? 2 : 1;
      }

      if (all) {
        scored.add((id: note.id, score: score, updatedAt: note.updatedAt));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : b.updatedAt.compareTo(a.updatedAt);
    });

    return scored.take(limit).map((entry) => entry.id).toList();
  }

  @override
  Future<void> replaceNotes(List<Note> notes) async {
    _notes
      ..clear()
      ..addAll(notes.toList()..sort((a, b) => a.id.compareTo(b.id)));
    _nextNoteId = _notes.isEmpty ? 1 : _notes.last.id + 1;

    for (final note in _notes) {
      if (note.syncId.isNotEmpty) {
        _tombstones.remove(
          note.syncId,
        ); // restored notes retract their tombstones
      }
    }
  }

  @override
  Future<void> replaceNotebooks(List<Notebook> notebooks) async {
    _notebooks
      ..clear()
      ..addAll(notebooks.toList()..sort((a, b) => a.id.compareTo(b.id)));
    _nextNotebookId = _notebooks.isEmpty ? 1 : _notebooks.last.id + 1;
  }

  @override
  Future<void> pushUndo(String payload) async {
    if (payload.isEmpty) {
      throw ArgumentError.value(payload, 'payload', 'must not be empty');
    }

    _undo.add(payload);
    while (_undo.length > _undoDepthValue) {
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
  set undoDepth(int value) {
    if (value < 0) {
      throw RangeError.value(value, 'undoDepth', 'must not be negative');
    }
    _undoDepthValue = value;
  }

  int get undoDepthValue => _undoDepthValue;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
