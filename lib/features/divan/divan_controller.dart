/// divan — see doc/divan.md and AGENTS.md
library;

import 'package:flutter/foundation.dart';

import '../../core/uids.dart';
import '../settings/setting_keys.dart';
import '../settings/settings_controller.dart';
import '../soroush/ai_funnel.dart';
import '../sync/sync_client.dart';
import '../sync/sync_models.dart';
import '../sync/sync_options.dart';
import 'divan_defaults.dart';
import 'divan_service.dart';
import 'divan_sync_adapter.dart';
import 'models.dart';
import 'pad_assistant.dart';

class DivanController extends ChangeNotifier {
  /// Wires the service, the optional settings store (default notebook, sync URL), the AI
  /// funnel, and the optional sync transport factory.
  DivanController({
    required DivanService service,
    SettingsController? settings,
    AiFunnel? funnel,
    PadAssistant? assistant,
    SyncAdapter? syncAdapter,
    SyncClient Function(String url, {String? token})? syncClientFactory,
    String Function(String key)? environment,
    DateTime Function()? clock,
  }) : _service = service,
       _settings = settings,
       _funnel = funnel,
       _assistant = assistant ?? PadAssistant(service.options),
       _syncAdapter =
           syncAdapter ??
           DivanSyncAdapter(
             service: service,
             store: service.store,
             clock: clock ?? DateTime.now,
           ),
       _syncClientFactory = syncClientFactory,
       _environment = environment ?? ((_) => '');

  final DivanService _service;
  final SettingsController? _settings;
  final AiFunnel? _funnel;
  final PadAssistant _assistant;
  final SyncAdapter _syncAdapter;
  final SyncClient Function(String url, {String? token})? _syncClientFactory;
  final String Function(String key) _environment;

  List<Notebook> _notebooks = const [];
  List<Note> _notes = const [];
  List<String> _tags = const [];
  List<OpenTodo> _todos = const [];
  DivanStats? _stats;
  Note? _selected;
  NoteMetrics? _metrics;
  List<Note> _backlinks = const [];

  int? _notebookFilter;
  String? _tagFilter;
  String _query = '';
  bool _pinnedOnly = false;
  bool _archivedOnly = false;
  bool _checklistsOnly = false;

  String? _error;
  String? _message;
  bool _busy = false;
  bool _aiBusy = false;
  String? _aiAnswer;
  String _aiKind = '';
  String? _aiQuestion;
  List<String> _aiTags = const [];
  bool _undoAvailable = false;
  SyncRun? _lastSync;
  bool _disposed = false;

  // ── Reads ──

  /// The pad's notebooks, archived ones included.
  List<Notebook> get notebooks => _notebooks;

  /// Notes matching the current filters (pinned first, then most recently updated).
  List<Note> get notes => _notes;

  /// Every tag in use, excluding archived notes.
  List<String> get tags => _tags;

  /// Open checklist items across active notes.
  List<OpenTodo> get todos => _todos;

  /// The last computed aggregate, or null before the first refresh.
  DivanStats? get stats => _stats;

  /// The note shown in the editor, or null when nothing is selected.
  Note? get selected => _selected;

  /// Word/reading/checklist/link counts for the selected note.
  NoteMetrics? get metrics => _metrics;

  /// Notes whose bodies contain `[[selected title]]`.
  List<Note> get backlinks => _backlinks;

  /// The service in use (the page reads its options and the today date).
  DivanService get service => _service;

  /// The active notebook filter (`null` = every notebook).
  int? get notebookFilter => _notebookFilter;

  /// The active tag filter (`null` = every tag).
  String? get tagFilter => _tagFilter;

  /// The search text (empty = no query).
  String get query => _query;

  /// True when the listing is pinned-only.
  bool get pinnedOnly => _pinnedOnly;

  /// True when the listing shows archived notes instead of active ones.
  bool get archivedOnly => _archivedOnly;

  /// True when the listing only shows notes with checklist items.
  bool get checklistsOnly => _checklistsOnly;

  /// True while an async action is running.
  bool get busy => _busy;

  /// True while an AI call is in flight.
  bool get aiBusy => _aiBusy;

  /// The last error message, or null. Already human-readable and secret-free.
  String? get error => _error;

  /// The last success message (saved, undone, imported, synced), or null.
  String? get message => _message;

  /// The last AI answer, or null.
  String? get aiAnswer => _aiAnswer;

  /// Which AI action produced [aiAnswer]: `summary`, `title`, `tags`, or `ask`.
  String get aiKind => _aiKind;

  /// The question the last `ask` used.
  String? get aiQuestion => _aiQuestion;

  /// Tag names the last `tags` action proposed.
  List<String> get aiTags => _aiTags;

  /// True while the pad has a snapshot to restore.
  bool get undoAvailable => _undoAvailable;

  /// The last sync exchange, or null.
  SyncRun? get lastSync => _lastSync;

  /// Notebooks that are still active (the common picker list).
  List<Notebook> get activeNotebooks =>
      _notebooks.where((notebook) => !notebook.isArchived).toList();

  /// The notebook behind [notebookId], or null when it is gone.
  Notebook? notebookById(int? notebookId) {
    if (notebookId == null) return null;
    for (final notebook in _notebooks) {
      if (notebook.id == notebookId) return notebook;
    }
    return null;
  }

  /// The notebook name shown next to a note in the listing.
  String notebookNameOf(Note note) =>
      notebookById(note.notebookId)?.name ?? 'Notebook ${note.notebookId}';

  /// True when any filter is narrowing the listing.
  bool get hasFilters =>
      _notebookFilter != null ||
      _tagFilter != null ||
      _query.isNotEmpty ||
      _pinnedOnly ||
      _archivedOnly ||
      _checklistsOnly;

  // ── Lifecycle ──

  /// Loads the pad for the first time (idempotent; safe to call from `initState`).
  Future<void> initialize() async {
    if (_notebooks.isNotEmpty || _notes.isNotEmpty) return;
    await refresh();
  }

  /// Re-reads the listing, notebooks, tags, todos, stats, and undo depth.
  Future<void> refresh() async {
    await _guard(() async {
      _notebooks = await _service.listNotebooks();
      _tags = await _service.allTags();
      _notes = await _service.list(_filter());
      _todos = await _service.openTodos(notebookId: null);
      _stats = await _service.stats();
      _undoAvailable = await _service.store.undoCount > 0;
      await _reloadSelection();
    });
  }

  /// Selects the note with [id] (`null` clears the editor).
  Future<void> select(int? id) async {
    if (id == null) {
      _selected = null;
      _metrics = null;
      _backlinks = const [];
      _notify();
      return;
    }
    final note = await _service.getNote(id);
    if (note == null) return;
    _selected = note;
    await _reloadDerived();
    _notify();
  }

  // ── Filters ──

  /// Filters the listing to one notebook (`null` clears it).
  Future<void> setNotebookFilter(int? notebookId) async {
    _notebookFilter = notebookId;
    await refresh();
  }

  /// Filters the listing to one tag (`null` clears it).
  Future<void> setTagFilter(String? tag) async {
    _tagFilter = (tag == null || tag.trim().isEmpty) ? null : tag.trim();
    await refresh();
  }

  /// Sets the live search text.
  Future<void> setQuery(String value) async {
    _query = value;
    await refresh();
  }

  /// Toggles the pinned-only filter.
  Future<void> setPinnedOnly(bool value) async {
    _pinnedOnly = value;
    await refresh();
  }

  /// Toggles between active and archived listings.
  Future<void> setArchivedOnly(bool value) async {
    _archivedOnly = value;
    await refresh();
  }

  /// Toggles the has-checklist filter.
  Future<void> setChecklistsOnly(bool value) async {
    _checklistsOnly = value;
    await refresh();
  }

  /// Clears every filter.
  Future<void> clearFilters() async {
    _notebookFilter = null;
    _tagFilter = null;
    _query = '';
    _pinnedOnly = false;
    _archivedOnly = false;
    _checklistsOnly = false;
    await refresh();
  }

  // ── Notebooks ──

  /// Creates a notebook and re-lists.
  Future<Notebook?> createNotebook(String name) async {
    Notebook? created;
    await _guard(() async {
      created = await _service.createNotebook(name);
      _notebooks = await _service.listNotebooks();
      _message = "Notebook '${created!.name}' created.";
    });
    return created;
  }

  /// Renames a notebook.
  Future<void> renameNotebook(int id, String name) async {
    await _guard(() async {
      await _service.renameNotebook('$id', name);
      await refresh();
      _message = 'Notebook renamed.';
    });
  }

  /// Archives or restores a notebook.
  Future<void> setNotebookArchived(int id, bool archived) async {
    await _guard(() async {
      await _service.archiveNotebook('$id', archived);
      await refresh();
      _message = archived ? 'Notebook archived.' : 'Notebook restored.';
    });
  }

  /// Deletes a notebook (and its notes); a non-empty notebook needs [force].
  Future<void> deleteNotebook(int id, {bool force = false}) async {
    await _guard(() async {
      final removed = await _service.removeNotebook('$id', force: force);
      await refresh();
      _message = removed == 0
          ? 'Notebook deleted.'
          : 'Notebook deleted with $removed note(s).';
    });
  }

  // ── Notes ──

  /// The notebook a new note lands in: the picker's notebook, else `divan.notebook`,
  /// else the store's own default rule (`resolveNotebook(null)`).
  Future<int> defaultNotebookId() async {
    if (_notebookFilter != null) return _notebookFilter!;
    final configured = await _settings?.read(SettingKeys.divanNotebook);
    final notebook = await _service.resolveNotebook(
      configured == null || configured.trim().isEmpty ? null : configured,
    );
    return notebook.id;
  }

  /// Creates a note and selects it.
  Future<Note?> addNote({
    String title = '',
    String body = '',
    String tags = '',
    int? notebookId,
  }) async {
    Note? created;
    await _guard(() async {
      final target = notebookById(notebookId ?? await defaultNotebookId());
      created = await _service.addNote(
        title.trim().isEmpty ? 'Untitled' : title,
        body,
        notebookText: target?.name,
        tags: tags,
      );
      await refresh();
      await select(created!.id);
      _message = 'Note added.';
    });
    return created;
  }

  /// Saves the editor's changes to note [id].
  Future<void> saveNote(
    int id, {
    String? title,
    String? body,
    String? tags,
  }) async {
    await _guard(() async {
      final note = await _service.editNote(
        id,
        title: title,
        body: body,
        tags: tags,
      );
      await refresh();
      await select(note.id);
      _message = 'Note saved.';
    });
  }

  /// Appends text to a note (blank-line free, matching the CLI's `append`).
  Future<void> appendToNote(int id, String text) async {
    await _guard(() async {
      final note = await _service.append(id, text);
      await refresh();
      await select(note.id);
      _message = 'Text appended.';
    });
  }

  /// Moves a note into another notebook.
  Future<void> moveNote(int id, int notebookId) async {
    await _guard(() async {
      await _service.move(id, '$notebookId');
      await refresh();
      await select(id);
      _message = 'Note moved.';
    });
  }

  /// Pins or unpins a note.
  Future<void> setPinned(int id, bool pinned) async {
    await _guard(() async {
      await _service.pin(id, pinned);
      await refresh();
      await select(id);
      _message = pinned ? 'Note pinned.' : 'Note unpinned.';
    });
  }

  /// Archives or restores a note.
  Future<void> setArchived(int id, bool archived) async {
    await _guard(() async {
      await _service.archive(id, archived);
      await refresh();
      await select(id);
      _message = archived ? 'Note archived.' : 'Note restored.';
    });
  }

  /// Deletes a note (a snapshot is kept for undo).
  Future<void> deleteNote(int id) async {
    await _guard(() async {
      await _service.delete(id);
      if (_selected?.id == id) {
        _selected = null;
        _metrics = null;
        _backlinks = const [];
      }
      await refresh();
      _message = 'Note deleted.';
    });
  }

  /// Flips one checklist box in a note's body, preserving the rest of the line.
  ///
  /// The .NET surface had no toggle verb — the CLI rewrote the body — so this is the same
  /// edit expressed once, here, instead of in every caller.
  Future<void> toggleChecklistItem(int noteId, int lineNumber) async {
    final note = await _service.getNote(noteId);
    if (note == null) return;
    final lines = note.body.split('\n');
    if (lineNumber < 1 || lineNumber > lines.length) return;

    final line = lines[lineNumber - 1];
    final match = RegExp(r'^(\s*[-*]\s*)\[([ xX])\](.*)$').firstMatch(line);
    if (match == null) return;

    final box = match.group(2)!.toLowerCase() == 'x' ? ' ' : 'x';
    lines[lineNumber - 1] = '${match.group(1)}[$box]${match.group(3)}';
    await saveNote(noteId, body: lines.join('\n'));
  }

  /// Opens (creating if needed) today's journal note and selects it.
  Future<void> openJournal() async {
    await _guard(() async {
      final note = await _service.daily();
      await refresh();
      await select(note.id);
      _message = 'Journal opened.';
    });
  }

  /// Adds an open checklist item to today's journal (the todos pane's quick add).
  Future<void> addTodo(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _guard(() async {
      final journal = await _service.daily();
      await _service.append(journal.id, '- [ ] $trimmed');
      await refresh();
      await select(journal.id);
      _message = 'Todo added to the journal.';
    });
  }

  /// Restores the last snapshot.
  Future<bool> undo() async {
    var restored = false;
    await _guard(() async {
      restored = await _service.undo();
      await refresh();
      _message = restored ? 'Last change undone.' : 'Nothing to undo.';
    });
    return restored;
  }

  /// Writes every active note into [folder] as markdown.
  Future<int> export(String folder) async {
    var written = 0;
    await _guard(() async {
      written = await _service.export(folder);
      _message = 'Exported $written note(s).';
    });
    return written;
  }

  /// Imports every `.md` file in [folder] as a new note.
  Future<int> import(String folder) async {
    var imported = 0;
    await _guard(() async {
      imported = await _service.import(folder);
      await refresh();
      _message = 'Imported $imported note(s).';
    });
    return imported;
  }

  // ── AI ──

  /// Sends the selected note and asks for a three-bullet summary.
  Future<void> summarize() => _ask('summary');

  /// Asks for a title for the selected note.
  Future<void> proposeTitle() => _ask('title');

  /// Asks for tags for the selected note.
  Future<void> proposeTags() => _ask('tags');

  /// Asks a question across the pad.
  Future<void> ask(String question) => _ask('ask', question: question);

  /// Clears the AI panel.
  void clearAi() {
    _aiAnswer = null;
    _aiKind = '';
    _aiQuestion = null;
    _aiTags = const [];
    _notify();
  }

  Future<void> _ask(String kind, {String question = ''}) async {
    final funnel = _funnel;
    if (funnel == null) {
      _error = 'No AI provider is configured.';
      _notify();
      return;
    }

    // A note-scoped ask needs a selected note; the pad-wide ask does not.
    final note = _selected;
    if (kind != 'ask' && note == null) {
      _error = 'Select a note first.';
      _notify();
      return;
    }

    _aiBusy = true;
    _error = null;
    _aiKind = kind;
    _aiAnswer = null;
    _aiTags = const [];
    _notify();
    try {
      late final String prompt;
      switch (kind) {
        case 'summary':
          prompt = _assistant.buildSummarizePrompt(note!);
        case 'title':
          prompt = _assistant.buildTitlePrompt(note!);
        case 'tags':
          _aiTags = const [];
          prompt = _assistant.buildTagsPrompt(note!, await _service.allTags());
        case 'ask':
          _aiQuestion = question.trim();
          // The CLI took the first `maxAiContextNotes` listed notes with a 200-char snippet.
          final context = (await _service.list())
              .take(DivanDefaults.maxAiContextNotes)
              .map(
                (note) =>
                    (note: note, snippet: DivanText.snippet(note.body, 200)),
              )
              .toList(growable: false);
          prompt = PadAssistant.buildAskPrompt(question, context);
        default:
          throw ArgumentError.value(kind, 'kind');
      }

      _aiAnswer = (await funnel.completeText(prompt)).trim();
      if (kind == 'tags') {
        _aiTags = PadAssistant.parseTags(_aiAnswer!);
      }
    } on DivanException catch (failure) {
      _error = failure.message;
    } catch (failure) {
      _error = '$failure';
    } finally {
      _aiBusy = false;
      _notify();
    }
  }

  // ── Sync ──

  /// Runs one sync exchange against `divan.syncUrl`.
  ///
  /// The transport is built from the settings URL (HTTPS only, or loopback) and the
  /// `JAMEJAM_SYNC_TOKEN` environment token — the same rails the CLI enforced.
  Future<SyncRun?> syncNow({SyncMode mode = SyncMode.merge}) async {
    SyncRun? run;
    await _guard(() async {
      final url =
          (await _settings?.read(SettingKeys.divanSyncUrl))?.trim() ?? '';
      if (url.isEmpty) {
        throw const DivanException(
          'Remote sync is not configured — set divan.syncUrl first.',
        );
      }

      final factory = _syncClientFactory;
      if (factory == null) {
        throw const DivanException('Sync is not available in this context.');
      }

      final deviceId = await _deviceSetting(
        SettingKeys.syncDeviceId,
        () => Uids.newUid(),
      );
      final deviceName = await _deviceSetting(
        SettingKeys.syncDeviceName,
        () => 'JameJam',
      );

      final client = factory(url, token: _bearerToken());
      run = await SyncEngine.run(
        client,
        _syncAdapter,
        deviceId: deviceId,
        deviceName: deviceName,
        mode: mode,
      );
      _lastSync = run;
      await refresh();
      _message = run!.describe();
    });
    return run;
  }

  /// Reads a device setting, storing a generated default on first use.
  Future<String> _deviceSetting(String key, String Function() fallback) async {
    final settings = _settings;
    if (settings == null) return fallback();
    final existing = (await settings.read(key))?.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final value = fallback();
    await settings.set(key, value);
    return value;
  }

  String? _bearerToken() {
    final token = _environment('JAMEJAM_SYNC_TOKEN').trim();
    return token.isEmpty ? null : token;
  }

  /// The options a caller-built transport should use for [url].
  SyncOptions syncOptionsFor(String url) =>
      SyncOptions(endpoint: url, bearerToken: _bearerToken());

  // ── Internals ──

  DivanFilter _filter() => DivanFilter(
    notebookId: _notebookFilter,
    tag: _tagFilter,
    query: _query.trim().isEmpty ? null : _query.trim(),
    pinnedOnly: _pinnedOnly,
    archivedOnly: _archivedOnly,
    checklistsOnly: _checklistsOnly,
  );

  Future<void> _reloadSelection() async {
    final current = _selected;
    if (current == null) return;
    final fresh = await _service.getNote(current.id);
    _selected = fresh;
    if (fresh == null) {
      _metrics = null;
      _backlinks = const [];
      return;
    }
    await _reloadDerived();
  }

  Future<void> _reloadDerived() async {
    final note = _selected;
    if (note == null) return;
    _metrics = _service.metrics(note);
    _backlinks = await _service.backlinks(note.id);
  }

  Future<void> _guard(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
    } on DivanException catch (failure) {
      _error = failure.message;
    } catch (failure) {
      _error = '$failure';
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
