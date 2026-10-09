/// divan — see doc/divan.md and AGENTS.md
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/date_only.dart';
import 'divan_defaults.dart';
import 'divan_options.dart';
import 'divan_store.dart';
import 'models.dart';

class DivanService {
  DivanService({
    required DivanStore store,
    required DateTime Function() clock,
    DivanOptions options = const DivanOptions(),
  }) : _store = store,
       _clock = clock,
       _options = options {
    _options.validate();
    store.undoDepth = _options.undoDepth;
  }

  final DivanStore _store;
  final DateTime Function() _clock;
  final DivanOptions _options;

  /// The validated options in effect.
  DivanOptions get options => _options;

  /// The store this service writes to (the sync adapter captures from it directly).
  DivanStore get store => _store;

  /// Today according to the injected clock (UTC, like the .NET `DateOnly.FromDateTime`).
  DateOnly get today => DateOnly.fromDateTime(_clock().toUtc());

  // ── Notebooks ──

  /// Creates a notebook (unique name, case-insensitive).
  Future<Notebook> createNotebook(String name) async {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }

    final clean = DivanText.clip(name, DivanDefaults.maxNotebookNameLength);
    if (await _store.findNotebookByName(clean) != null) {
      throw DivanException("A notebook named '$clean' already exists.");
    }

    if ((await _store.listNotebooks()).length >= DivanDefaults.maxNotebooks) {
      throw DivanException(
        'At most ${DivanDefaults.maxNotebooks} notebooks are allowed.',
      );
    }

    final now = _clock().toUtc();
    await _pushSnapshot();
    return _store.addNotebook(
      Notebook(id: 0, name: clean, createdAt: now, updatedAt: now),
    );
  }

  /// Resolves a notebook by id or name, creating the default one when the pad is empty
  /// and no name was given.
  Future<Notebook> resolveNotebook(String? text) async {
    if (text != null && text.trim().isNotEmpty) {
      final clean = DivanText.clip(text, DivanDefaults.maxNotebookNameLength);
      final byName = await _store.findNotebookByName(clean);
      if (byName != null) return byName;

      final id = int.tryParse(clean);
      if (id != null) {
        final byId = await _store.findNotebook(id);
        if (byId != null) return byId;
      }

      throw DivanException(
        "No notebook named '$clean'. Create one: JameJam divan notebook add $clean",
      );
    }

    final notebooks = await _store.listNotebooks();
    if (notebooks.isNotEmpty) return notebooks.first;

    final fallback = await _store.findNotebookByName(
      DivanDefaults.defaultNotebook,
    );
    if (fallback != null) return fallback;

    return createNotebook(DivanDefaults.defaultNotebook);
  }

  /// Renames a notebook.
  Future<Notebook> renameNotebook(String text, String newName) async {
    if (newName.trim().isEmpty) {
      throw ArgumentError.value(newName, 'newName', 'must not be blank');
    }

    final notebook = await resolveNotebook(text);
    await _pushSnapshot();

    final clean = DivanText.clip(newName, DivanDefaults.maxNotebookNameLength);
    final clash = await _store.findNotebookByName(clean);
    if (clash != null && clash.id != notebook.id) {
      throw DivanException("A notebook named '$clean' already exists.");
    }

    final renamed = notebook.copyWith(name: clean, updatedAt: _clock().toUtc());
    await _store.updateNotebook(renamed);
    return renamed;
  }

  /// Archives or unarchives a notebook.
  Future<Notebook> archiveNotebook(String text, bool archived) async {
    final notebook = await resolveNotebook(text);
    await _pushSnapshot();
    final updated = notebook.copyWith(
      isArchived: archived,
      updatedAt: _clock().toUtc(),
    );
    await _store.updateNotebook(updated);
    return updated;
  }

  /// Removes a notebook; unless [force], a notebook that still holds notes is refused.
  ///
  /// Returns how many notes went with it.
  Future<int> removeNotebook(String text, {bool force = false}) async {
    final notebook = await resolveNotebook(text);
    final notes = (await _store.listNotes())
        .where((note) => note.notebookId == notebook.id)
        .toList();

    if (notes.isNotEmpty && !force) {
      throw DivanException(
        "Notebook '${notebook.name}' holds ${notes.length} note(s) — move them or pass --force.",
      );
    }

    await _pushSnapshot();
    final now = _clock().toUtc();
    for (final note in notes) {
      await _store.removeNote(note.id, now);
    }

    await _store.removeNotebook(notebook.id);
    return notes.length;
  }

  // ── Notes ──

  /// Creates a note with an undo snapshot.
  Future<Note> addNote(
    String title,
    String body, {
    String? notebookText,
    String tags = '',
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be blank');
    }

    if ((await _store.listNotes()).length >= DivanDefaults.maxNotes) {
      throw DivanException(
        'At most ${DivanDefaults.maxNotes} notes are allowed.',
      );
    }

    await _pushSnapshot();
    final now = _clock().toUtc();
    final notebook = await resolveNotebook(notebookText);

    return _store.addNote(
      Note(
        notebookId: notebook.id,
        title: DivanText.clip(title, DivanDefaults.maxTitleLength),
        body: DivanText.cleanBody(body),
        tags: DivanText.cleanTags(tags),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Appends markdown text to a note's body.
  Future<Note> append(int id, String text) async {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be blank');
    }

    final note = await _requireNote(id);
    await _pushSnapshot();
    final addition = DivanText.cleanBody(text);
    final updated = note.copyWith(
      body: note.body.isEmpty
          ? addition
          : note.body.endsWith('\n')
          ? note.body + addition
          : '${note.body}\n$addition',
      updatedAt: _clock().toUtc(),
    );
    await _store.updateNote(updated);
    return updated;
  }

  /// Overwrites a note's title, body, tags, or pin (null keeps the current value).
  Future<Note> editNote(
    int id, {
    String? title,
    String? body,
    String? tags,
    bool? pinned,
  }) async {
    final note = await _requireNote(id);
    await _pushSnapshot();
    final updated = note.copyWith(
      title: title == null
          ? null
          : DivanText.clip(title, DivanDefaults.maxTitleLength),
      body: body == null ? null : DivanText.cleanBody(body),
      tags: tags == null ? null : DivanText.cleanTags(tags),
      pinned: pinned,
      updatedAt: _clock().toUtc(),
    );
    await _store.updateNote(updated);
    return updated;
  }

  /// Moves a note to another notebook.
  Future<Note> move(int id, String notebookText) async {
    final note = await _requireNote(id);
    final notebook = await resolveNotebook(notebookText);
    await _pushSnapshot();
    final updated = note.copyWith(
      notebookId: notebook.id,
      updatedAt: _clock().toUtc(),
    );
    await _store.updateNote(updated);
    return updated;
  }

  /// Sets or clears a note's pin.
  Future<Note> pin(int id, bool pinned) async {
    final note = await _requireNote(id);
    await _pushSnapshot();
    final updated = note.copyWith(pinned: pinned, updatedAt: _clock().toUtc());
    await _store.updateNote(updated);
    return updated;
  }

  /// Archives or unarchives a note.
  Future<Note> archive(int id, bool archived) async {
    final note = await _requireNote(id);
    await _pushSnapshot();
    final updated = note.copyWith(
      archived: archived,
      updatedAt: _clock().toUtc(),
    );
    await _store.updateNote(updated);
    return updated;
  }

  /// Pushes a whole-pad undo snapshot — sync calls this once before applying a merge.
  Future<void> pushUndoSnapshot() => _pushSnapshot();

  /// Deletes a note (undo brings it back) and returns it.
  Future<Note> delete(int id) async {
    final note = await _requireNote(id);
    await _pushSnapshot();
    await _store.removeNote(id, _clock().toUtc());
    return note;
  }

  /// Gets one note.
  Future<Note?> getNote(int id) => _store.findNote(id);

  /// Lists notes (pinned first, then most recently updated) under the filter.
  ///
  /// A query routes through the store's search first, so both implementations keep their
  /// own ranking (FTS5 `rank`, or the memory store's title-weighted score).
  Future<List<Note>> list([DivanFilter filter = const DivanFilter()]) async {
    final query = filter.query?.trim();
    final candidates = query != null && query.isNotEmpty
        ? await _rankedSearch(query)
        : await _store.listNotes();

    final notes =
        candidates
            .where(
              (note) => filter.archivedOnly ? note.archived : !note.archived,
            )
            .where(
              (note) =>
                  filter.notebookId == null ||
                  note.notebookId == filter.notebookId,
            )
            .where(
              (note) =>
                  filter.tag == null ||
                  note.tagList.any(
                    (tag) => tag.toLowerCase() == filter.tag!.toLowerCase(),
                  ),
            )
            .where((note) => !filter.pinnedOnly || note.pinned)
            .where(
              (note) =>
                  !filter.checklistsOnly ||
                  DivanText.checklist(note.body).isNotEmpty,
            )
            .toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) {
              return a.pinned ? -1 : 1;
            }
            return b.updatedAt.compareTo(a.updatedAt);
          });

    return notes;
  }

  /// Notes that link to the given note via `[[Title]]`.
  Future<List<Note>> backlinks(int id) async {
    final target = await _requireNote(id);
    final notes = await _store.listNotes();
    return notes
        .where((note) => note.id != id)
        .where(
          (note) => DivanText.extractLinks(
            note.body,
          ).any((link) => link.toLowerCase() == target.title.toLowerCase()),
        )
        .toList();
  }

  /// All open `- [ ]` items across active notes (optionally within a notebook).
  Future<List<OpenTodo>> openTodos({int? notebookId}) async {
    final todos = <OpenTodo>[];
    for (final note in await list(DivanFilter(notebookId: notebookId))) {
      for (final item in DivanText.checklist(note.body)) {
        if (!item.done) todos.add(OpenTodo(note: note, item: item));
      }
    }

    return todos;
  }

  /// Today's journal note: creates it (with a date heading) in the Journal notebook on
  /// the first call of the day, returns the same note afterwards.
  Future<Note> daily() async {
    final journal =
        await _store.findNotebookByName(DivanDefaults.journalNotebook) ??
        await _createJournal();
    final title = today.toIso();
    final existing = (await _store.listNotes()).where(
      (note) =>
          note.notebookId == journal.id &&
          note.title.toLowerCase() == title.toLowerCase(),
    );

    if (existing.isNotEmpty) return existing.first;

    final heading = _journalHeading(_clock().toUtc());
    return addNote(
      title,
      '# $heading\n\n- [ ] ',
      notebookText: journal.id.toString(),
    );
  }

  /// Derived metrics for one note (words, reading time, checklist, links).
  NoteMetrics metrics(Note note) {
    final words = DivanText.wordCount(note.body);
    final checklist = DivanText.checklist(note.body);
    return NoteMetrics(
      words: words,
      characters: note.body.length,
      readingSeconds: (words * 60 / _options.readingWordsPerMinute).ceil(),
      checklistTotal: checklist.length,
      checklistDone: checklist.where((item) => item.done).length,
      links: DivanText.extractLinks(note.body),
    );
  }

  /// Lists all notebooks in id order.
  Future<List<Notebook>> listNotebooks() => _store.listNotebooks();

  /// Distinct tags across active notes (case-insensitive, in first-seen order).
  Future<List<String>> allTags() async {
    final notes = await _store.listNotes();
    final seen = <String>{};
    final tags = <String>[];
    for (final note in notes) {
      if (note.archived) continue;
      for (final tag in note.tagList) {
        final key = tag.trim();
        if (key.isEmpty) continue;
        if (seen.add(key.toLowerCase())) tags.add(key);
      }
    }

    return tags;
  }

  /// Aggregate statistics over the pad.
  Future<DivanStats> stats() async {
    final notebooks = await _store.listNotebooks();
    final notes = await _store.listNotes();
    final active = notes.where((note) => !note.archived).toList();

    return DivanStats(
      notebooks: notebooks.length,
      notes: active.length,
      archivedNotes: notes.length - active.length,
      taggedNotes: active.where((note) => note.tags.isNotEmpty).length,
      words: active.fold(
        0,
        (sum, note) => sum + DivanText.wordCount(note.body),
      ),
      openChecklistItems: (await openTodos()).length,
      links: active.fold(
        0,
        (sum, note) => sum + DivanText.extractLinks(note.body).length,
      ),
    );
  }

  // ── Undo ──

  /// Reverts the last change (notebook + note state together). False when there is none.
  Future<bool> undo() async {
    final payload = await _store.popUndo();
    if (payload == null) return false;

    Map<String, dynamic> snapshot;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) throw const FormatException('not an object');
      snapshot = decoded.cast<String, dynamic>();
    } on FormatException {
      throw const DivanException('The undo snapshot is unreadable.');
    }

    final notebooks = (snapshot['notebooks'] as List? ?? const [])
        .map(
          (entry) => _notebookFromDto((entry as Map).cast<String, dynamic>()),
        )
        .toList();
    final notes = (snapshot['notes'] as List? ?? const [])
        .map((entry) => _noteFromDto((entry as Map).cast<String, dynamic>()))
        .toList();

    await _store.replaceNotebooks(notebooks);
    await _store.replaceNotes(notes);
    return true;
  }

  // ── Export / import (a folder of markdown files with front matter) ──

  /// Writes every note as a markdown file (front matter + body) into a folder.
  Future<int> export(String folder) async {
    if (folder.trim().isEmpty) {
      throw ArgumentError.value(folder, 'folder', 'must not be blank');
    }

    Directory(folder).createSync(recursive: true);
    final notes = await _store.listNotes();
    final notebooks = {
      for (final notebook in await _store.listNotebooks())
        notebook.id: notebook.name,
    };

    for (final note in notes) {
      final fileName = '${_fileNameSafe(note.title)}-${note.id}.md';
      File(p.join(folder, fileName)).writeAsStringSync(
        serializeNote(
          note,
          notebooks[note.notebookId] ?? DivanDefaults.defaultNotebook,
        ),
      );
    }

    return notes.length;
  }

  /// Imports every `*.md` file from a folder, creating notebooks as needed.
  Future<int> import(String folder) async {
    if (folder.trim().isEmpty) {
      throw ArgumentError.value(folder, 'folder', 'must not be blank');
    }

    if (!Directory(folder).existsSync()) {
      throw DivanException('No such folder: $folder');
    }

    var files =
        Directory(folder)
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.md'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    if (files.isEmpty) {
      throw const DivanException('No .md files found in that folder.');
    }

    if (files.length > DivanDefaults.maxImportFiles) {
      files = files.take(DivanDefaults.maxImportFiles).toList();
    }

    await _pushSnapshot();
    var imported = 0;
    for (final file in files) {
      final parsed = parseNoteFile(file.readAsStringSync());
      if (parsed == null) continue;

      final notebook =
          await _store.findNotebookByName(parsed.notebook) ??
          await createNotebook(parsed.notebook);
      final now = _clock().toUtc();
      await _store.addNote(
        Note(
          notebookId: notebook.id,
          title: parsed.title,
          body: parsed.body,
          tags: parsed.tags,
          pinned: parsed.pinned,
          createdAt: now,
          updatedAt: now,
        ),
      );
      imported++;
    }

    return imported;
  }

  /// Serializes one note the way [export] writes it (front matter + body).
  static String serializeNote(Note note, String notebookName) {
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('title: ${note.title.replaceAll(RegExp(r'\r\n|\r|\n'), ' ')}')
      ..writeln('notebook: $notebookName')
      ..writeln('tags: ${note.tags}')
      ..writeln('pinned: ${note.pinned}')
      ..writeln('created: ${note.createdAt.toUtc().toIso8601String()}')
      ..writeln('updated: ${note.updatedAt.toUtc().toIso8601String()}')
      ..writeln('---')
      ..writeln(note.body);
    return buffer.toString();
  }

  /// Parses one exported file. Returns null when it has no front matter or no title —
  /// exactly the files the CLI import skips.
  static ({
    String title,
    String notebook,
    String tags,
    bool pinned,
    String body,
  })?
  parseNoteFile(String content) {
    if (!content.startsWith('---')) return null;

    final end = content.indexOf('\n---');
    if (end < 0) return null;

    final frontMatter = content.substring(3, end);
    final body = content.substring(end + 4).replaceFirst(RegExp(r'^\n+'), '');

    var title = '';
    var notebook = DivanDefaults.defaultNotebook;
    var tags = '';
    var pinned = false;

    for (final line in frontMatter.split('\n')) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;

      final key = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      switch (key) {
        case 'title':
          if (value.isNotEmpty) title = value;
        case 'notebook':
          if (value.isNotEmpty) notebook = value;
        case 'tags':
          tags = value;
        case 'pinned':
          pinned = value.toLowerCase() == 'true';
      }
    }

    if (title.isEmpty) return null;
    return (
      title: title,
      notebook: notebook,
      tags: tags,
      pinned: pinned,
      body: body,
    );
  }

  // ── Internals ──

  Future<Notebook> _createJournal() async {
    final existing = await _store.findNotebookByName(
      DivanDefaults.journalNotebook,
    );
    if (existing != null) return existing;

    await _pushSnapshot();
    return _store.addNotebook(
      Notebook(
        id: 0,
        name: DivanDefaults.journalNotebook,
        createdAt: _clock().toUtc(),
      ),
    );
  }

  Future<List<Note>> _rankedSearch(String query) async {
    final ids = await _store.searchIds(query, _options.searchLimit);
    final wanted = ids.toSet();
    final notes = await _store.listNotes();
    return notes.where((note) => wanted.contains(note.id)).toList();
  }

  Future<Note> _requireNote(int id) async {
    final note = await _store.findNote(id);
    if (note == null) {
      throw DivanException('No note #$id.');
    }
    return note;
  }

  Future<void> _pushSnapshot() async {
    final notebooks = await _store.listNotebooks();
    final notes = await _store.listNotes();

    final payload = jsonEncode({
      'notebooks': [
        for (final notebook in notebooks)
          {
            'id': notebook.id,
            'name': notebook.name,
            'createdAt': notebook.createdAt.toUtc().toIso8601String(),
            'isArchived': notebook.isArchived,
            if (notebook.updatedAt != null)
              'updatedAt': notebook.updatedAt!.toUtc().toIso8601String(),
          },
      ],
      'notes': [
        for (final note in notes)
          {
            'id': note.id,
            'notebookId': note.notebookId,
            'title': note.title,
            'body': note.body,
            'tags': note.tags,
            'pinned': note.pinned,
            'archived': note.archived,
            'createdAt': note.createdAt.toUtc().toIso8601String(),
            'updatedAt': note.updatedAt.toUtc().toIso8601String(),
            'syncId': note.syncId,
          },
      ],
    });

    await _store.pushUndo(payload);
  }

  /// The journal heading — a weekday name plus the date.
  ///
  /// Written in English on purpose: it is *data* (it lands in the note body and is
  /// exported), so it must not follow the UI locale.
  static String _journalHeading(DateTime utc) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final date = DateOnly.fromDateTime(utc);
    return '${weekdays[utc.weekday - 1]}, ${date.toIso()}';
  }

  static String _fileNameSafe(String title) {
    var safe = title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-').trim();
    if (safe.isEmpty) return 'note';
    if (safe.length > 40) safe = safe.substring(0, 40).trim();
    return safe.isEmpty ? 'note' : safe;
  }

  static Notebook _notebookFromDto(Map<String, dynamic> dto) => Notebook(
    id: (dto['id'] as num).toInt(),
    name: dto['name'] as String,
    createdAt: DateTime.parse(dto['createdAt'] as String).toUtc(),
    isArchived: dto['isArchived'] as bool? ?? false,
    updatedAt: dto['updatedAt'] == null
        ? null
        : DateTime.parse(dto['updatedAt'] as String).toUtc(),
  );

  static Note _noteFromDto(Map<String, dynamic> dto) => Note(
    id: (dto['id'] as num).toInt(),
    notebookId: (dto['notebookId'] as num).toInt(),
    title: dto['title'] as String,
    body: dto['body'] as String,
    tags: (dto['tags'] as String?) ?? '',
    pinned: dto['pinned'] as bool? ?? false,
    archived: dto['archived'] as bool? ?? false,
    createdAt: DateTime.parse(dto['createdAt'] as String).toUtc(),
    updatedAt: DateTime.parse(dto['updatedAt'] as String).toUtc(),
    syncId: (dto['syncId'] as String?) ?? '',
  );
}
