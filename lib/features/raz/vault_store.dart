/// raz — see doc/raz.md and AGENTS.md
import 'dart:typed_data';

import 'models.dart';
import 'raz_defaults.dart';

abstract interface class VaultStore {
  /// True when the vault has been initialized (meta rows exist).
  Future<bool> isInitialized();

  /// Sets the vault meta rows (salt, iterations, key check) — init only.
  Future<void> setMeta(Uint8List salt, int iterations, Uint8List keyCheck);

  /// Reads the stored salt, or null when uninitialized.
  Future<Uint8List?> getSalt();

  /// Reads the stored iteration count, or 0 when uninitialized.
  Future<int> getIterations();

  /// Reads the encrypted key-check payload, or null when uninitialized.
  Future<Uint8List?> getKeyCheck();

  /// Inserts an entry and returns it with its assigned id.
  Future<RazEntry> addEntry(RazEntry entry);

  /// Overwrites an existing entry (same id).
  Future<void> updateEntry(RazEntry entry);

  /// Removes an entry. Returns true when it existed.
  Future<bool> removeEntry(int id);

  /// Gets an entry by id, or null.
  Future<RazEntry?> findEntry(int id);

  /// Lists all entries ordered by id.
  Future<List<RazEntry>> listEntries();

  /// Replaces every entry with the given ones (undo restore); ids are preserved.
  Future<void> replaceEntries(List<RazEntry> entries);

  /// How many entries are stored.
  Future<int> count();

  /// Pushes an undo snapshot (an encrypted payload produced by the service).
  Future<void> pushUndo(Uint8List payload);

  /// Pops the most recent undo snapshot, or null when the stack is empty.
  Future<Uint8List?> popUndo();

  /// How many undo snapshots are currently stacked.
  Future<int> undoCount();

  /// Maximum number of undo snapshots kept. Pushing beyond the depth drops the oldest
  /// snapshot; defaults to [RazDefaults.undoDepth]. Values below zero are rejected.
  int get undoDepth;

  set undoDepth(int value);
}

class MemoryVaultStore implements VaultStore {
  final List<RazEntry> _entries = [];
  final List<Uint8List> _undo = [];
  Uint8List? _salt;
  int _iterations = 0;
  Uint8List? _keyCheck;
  int _nextId = 1;
  int _undoDepthValue = RazDefaults.undoDepth;

  @override
  int get undoDepth => _undoDepthValue;

  @override
  set undoDepth(int value) {
    if (value < 0) {
      throw RangeError.value(
        value,
        'undoDepth',
        'UndoDepth cannot be negative.',
      );
    }

    _undoDepthValue = value;
  }

  @override
  Future<bool> isInitialized() async => _salt != null;

  @override
  Future<void> setMeta(
    Uint8List salt,
    int iterations,
    Uint8List keyCheck,
  ) async {
    _salt = Uint8List.fromList(salt);
    _iterations = iterations;
    _keyCheck = Uint8List.fromList(keyCheck);
  }

  @override
  Future<Uint8List?> getSalt() async =>
      _salt == null ? null : Uint8List.fromList(_salt!);

  @override
  Future<int> getIterations() async => _iterations;

  @override
  Future<Uint8List?> getKeyCheck() async =>
      _keyCheck == null ? null : Uint8List.fromList(_keyCheck!);

  @override
  Future<RazEntry> addEntry(RazEntry entry) async {
    final withId = entry.copyWith(id: _nextId++);
    _entries.add(withId);
    return withId;
  }

  @override
  Future<void> updateEntry(RazEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) {
      throw RazException('No entry #${entry.id}.');
    }

    _entries[index] = entry;
  }

  @override
  Future<bool> removeEntry(int id) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    return _entries.length != before;
  }

  @override
  Future<RazEntry?> findEntry(int id) async {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }

    return null;
  }

  @override
  Future<List<RazEntry>> listEntries() async {
    final sorted = [..._entries]..sort((a, b) => a.id.compareTo(b.id));
    return sorted;
  }

  @override
  Future<void> replaceEntries(List<RazEntry> entries) async {
    final sorted = [...entries]..sort((a, b) => a.id.compareTo(b.id));
    _entries
      ..clear()
      ..addAll(sorted);
    _nextId = _entries.isEmpty
        ? 1
        : _entries.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  @override
  Future<int> count() async => _entries.length;

  @override
  Future<void> pushUndo(Uint8List payload) async {
    _undo.add(Uint8List.fromList(payload));
    while (_undo.length > _undoDepthValue) {
      _undo.removeAt(0);
    }
  }

  @override
  Future<Uint8List?> popUndo() async {
    if (_undo.isEmpty) return null;
    return _undo.removeLast();
  }

  @override
  Future<int> undoCount() async => _undo.length;
}
