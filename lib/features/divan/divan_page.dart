/// divan — see doc/divan.md and AGENTS.md
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fa_format.dart';
import '../../core/jamejam_paths.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/adaptive_layout.dart';
import '../sync/sync_models.dart';
import 'divan_controller.dart';
import 'divan_preview.dart';
import 'models.dart';

const Key divanSearchFieldKey = Key('divan.search');

const Key divanAddNoteButtonKey = Key('divan.add');

const Key divanAddNotebookButtonKey = Key('divan.notebook.add');

const Key divanJournalButtonKey = Key('divan.journal');

const Key divanUndoButtonKey = Key('divan.undo');

const Key divanRefreshButtonKey = Key('divan.refresh');

const Key divanTransferButtonKey = Key('divan.transfer');

const Key divanSyncButtonKey = Key('divan.sync');

const Key divanTransferFieldKey = Key('divan.transfer.path');

const Key divanPinnedFilterKey = Key('divan.filter.pinned');

const Key divanArchivedFilterKey = Key('divan.filter.archived');

const Key divanChecklistFilterKey = Key('divan.filter.checklists');

const Key divanClearFiltersKey = Key('divan.filter.clear');

const Key divanNotebookFilterKey = Key('divan.filter.notebook');

const Key divanTagFilterKey = Key('divan.filter.tag');

const Key divanAllNotebooksKey = Key('divan.notebook.all');

const Key divanTitleFieldKey = Key('divan.editor.title');

const Key divanTagsFieldKey = Key('divan.editor.tags');

const Key divanBodyFieldKey = Key('divan.editor.body');

const Key divanSaveButtonKey = Key('divan.editor.save');

const Key divanPreviewToggleKey = Key('divan.editor.preview');

const Key divanDeleteNoteKey = Key('divan.editor.delete');

const Key divanPinButtonKey = Key('divan.editor.pin');

const Key divanArchiveButtonKey = Key('divan.editor.archive');

const Key divanMoveFieldKey = Key('divan.editor.move');

const Key divanTodoFieldKey = Key('divan.todo');

const Key divanTodoAddButtonKey = Key('divan.todo.add');

const Key divanAiSummarizeKey = Key('divan.ai.summarize');

const Key divanAiTitleKey = Key('divan.ai.title');

const Key divanAiTagsKey = Key('divan.ai.tags');

const Key divanAskFieldKey = Key('divan.ai.question');

const Key divanAskButtonKey = Key('divan.ai.ask');

const Key divanAiClearKey = Key('divan.ai.clear');

const Key divanAiApplyTitleKey = Key('divan.ai.apply.title');

const Key divanAiApplyTagsKey = Key('divan.ai.apply.tags');

Key divanNoteTileKey(int id) => Key('divan.note.$id');

Key divanNotebookTileKey(int id) => Key('divan.notebook.$id');

Key divanChecklistItemKey(int line) => Key('divan.check.$line');

Key divanNotebookMenuKey(int id) => Key('divan.notebook.menu.$id');

class DivanPage extends StatefulWidget {
  /// Creates the screen; the controller comes from the provider graph.
  const DivanPage({super.key});

  @override
  State<DivanPage> createState() => _DivanPageState();
}

class _DivanPageState extends State<DivanPage> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _body = TextEditingController();

  DivanController? _divan;
  int? _draftNoteId;
  bool _preview = false;
  String _folder = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<DivanController>();
      _divan = controller;
      controller.addListener(_syncDrafts);
      await controller.initialize();
      _syncDrafts();
    });
    unawaited(_loadDefaultFolder());
  }

  /// Copies the selected note into the editor's controllers.
  ///
  /// Driven by the controller's notifications rather than by `build`, so the text fields are
  /// filled from a stable point in the frame — and so a save (which refreshes and re-selects
  /// the same note) leaves what the user typed alone.
  void _syncDrafts() {
    final note = _divan?.selected;
    if (note == null) {
      _draftNoteId = null;
      return;
    }
    if (_draftNoteId == note.id) return;
    _draftNoteId = note.id;
    _title.text = note.title;
    _tags.text = note.tags;
    _body.text = note.body;
  }

  /// Opens the note a previewed `[[wiki-link]]` names, when one exists.
  Future<void> _openLink(String target) async {
    final needle = target.trim().toLowerCase();
    for (final note in _divan?.notes ?? const <Note>[]) {
      if (note.title.trim().toLowerCase() == needle) {
        await _divan?.select(note.id);
        return;
      }
    }
  }

  /// Saves the editor's current text to [note].
  Future<void> _save(Note note) => _flash(
    () => _divan!.saveNote(
      note.id,
      title: _title.text,
      tags: _tags.text,
      body: _body.text,
    ),
  );

  Future<void> _loadDefaultFolder() async {
    final root = await JameJamPaths.root();
    if (!mounted) return;
    setState(() => _folder = '$root${_sep(root)}divan-notes');
  }

  static String _sep(String path) => path.contains(r'\') ? r'\' : '/';

  @override
  void dispose() {
    _divan?.removeListener(_syncDrafts);
    _search.dispose();
    _title.dispose();
    _tags.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DivanController>();
    final l10n = AppLocalizations.of(context);
    final panes = <Widget>[
      _NotebooksPane(controller: controller, l10n: l10n),
      _EditorPane(
        controller: controller,
        l10n: l10n,
        title: _title,
        tags: _tags,
        body: _body,
        preview: _preview,
        onTogglePreview: () => setState(() => _preview = !_preview),
        onOpenLink: _openLink,
        onSave: _save,
      ),
      _ToolsPane(controller: controller, l10n: l10n),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        return AdaptivePageBody(
          chrome: [
            _Header(controller: controller, l10n: l10n),
            _Toolbar(
              controller: controller,
              l10n: l10n,
              search: _search,
              folder: _folder,
              onFlash: _flash,
            ),
            if (controller.error != null)
              _ErrorCard(message: controller.error!, l10n: l10n),
          ],
          body: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: panes[0]),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 5, child: panes[1]),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 3, child: panes[2]),
                  ],
                )
              : DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: l10n.divanTabNotes),
                          Tab(text: l10n.divanTabEditor),
                          Tab(text: l10n.divanTabTools),
                        ],
                      ),
                      Expanded(child: TabBarView(children: panes)),
                    ],
                  ),
                ),
        );
      },
    );
  }

  /// Runs an action and surfaces the controller's message when it succeeded.
  Future<void> _flash(Future<void> Function() action) async {
    final controller = context.read<DivanController>();
    final messenger = ScaffoldMessenger.of(context);
    await action();
    if (!mounted) return;
    final message = controller.error == null ? controller.message : null;
    if (message == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Header ──

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.l10n});

  final DivanController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = controller.stats;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.divanTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            l10n.divanSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (stats != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _StatChip(
                  icon: Icons.library_books_outlined,
                  label: l10n.divanStatNotebooks(stats.notebooks),
                ),
                _StatChip(
                  icon: Icons.sticky_note_2_outlined,
                  label: l10n.divanStatNotes(stats.notes),
                ),
                _StatChip(
                  icon: Icons.text_fields,
                  label: l10n.divanStatWords(stats.words),
                ),
                _StatChip(
                  icon: Icons.check_box_outlined,
                  label: l10n.divanStatTodos(stats.openChecklistItems),
                ),
                _StatChip(
                  icon: Icons.inventory_2_outlined,
                  label: l10n.divanStatArchived(stats.archivedNotes),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16),
    // Every label that reaches this chip is a count the pad computed (`۱۲ واژه`), never
    // something the reader typed, so the numerals follow the locale here rather than at each
    // of the ten call sites.
    label: Text(
      FaFormat.at(Localizations.localeOf(context).toLanguageTag(), label),
    ),
    visualDensity: VisualDensity.compact,
  );
}

// ── Toolbar ──

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.l10n,
    required this.search,
    required this.folder,
    required this.onFlash,
  });

  final DivanController controller;
  final AppLocalizations l10n;
  final TextEditingController search;
  final String folder;
  final Future<void> Function(Future<void> Function() action) onFlash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notebooks = controller.notebooks;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              key: divanSearchFieldKey,
              controller: search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.divanSearchHint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => unawaited(controller.setQuery(value)),
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              key: ValueKey(
                'divan.filter.notebook.${controller.notebookFilter}',
              ),
              initialValue: controller.notebookFilter,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.divanFieldNotebook,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.divanAllNotebooks),
                ),
                for (final notebook in notebooks)
                  DropdownMenuItem(
                    value: notebook.id,
                    child: Text(notebook.name),
                  ),
              ],
              onChanged: (value) =>
                  unawaited(controller.setNotebookFilter(value)),
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('divan.filter.tag.${controller.tagFilter}'),
              initialValue: controller.tagFilter,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.divanFieldTag,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.divanAllTags)),
                for (final tag in controller.tags)
                  DropdownMenuItem(value: tag, child: Text(tag)),
              ],
              onChanged: (value) => unawaited(controller.setTagFilter(value)),
            ),
          ),
          FilterChip(
            key: divanPinnedFilterKey,
            label: Text(l10n.divanFilterPinned),
            selected: controller.pinnedOnly,
            onSelected: (value) => unawaited(controller.setPinnedOnly(value)),
          ),
          FilterChip(
            key: divanArchivedFilterKey,
            label: Text(l10n.divanFilterArchived),
            selected: controller.archivedOnly,
            onSelected: (value) => unawaited(controller.setArchivedOnly(value)),
          ),
          FilterChip(
            key: divanChecklistFilterKey,
            label: Text(l10n.divanFilterChecklists),
            selected: controller.checklistsOnly,
            onSelected: (value) =>
                unawaited(controller.setChecklistsOnly(value)),
          ),
          if (controller.hasFilters)
            TextButton.icon(
              key: divanClearFiltersKey,
              onPressed: () => unawaited(controller.clearFilters()),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: Text(l10n.divanClearFilters),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: divanAddNoteButtonKey,
            onPressed: () =>
                unawaited(_newNote(context, controller, l10n, onFlash)),
            icon: const Icon(Icons.note_add_outlined),
            label: Text(l10n.divanNewNote),
          ),
          OutlinedButton.icon(
            key: divanAddNotebookButtonKey,
            onPressed: () =>
                unawaited(_newNotebook(context, controller, l10n, onFlash)),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: Text(l10n.divanNewNotebook),
          ),
          OutlinedButton.icon(
            key: divanJournalButtonKey,
            onPressed: () => onFlash(controller.openJournal),
            icon: const Icon(Icons.today_outlined),
            label: Text(l10n.divanJournal),
          ),
          IconButton(
            key: divanUndoButtonKey,
            onPressed: controller.undoAvailable
                ? () => onFlash(controller.undo)
                : null,
            tooltip: l10n.divanUndo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            key: divanRefreshButtonKey,
            onPressed: () => unawaited(controller.refresh()),
            tooltip: l10n.divanRefresh,
            icon: const Icon(Icons.refresh),
          ),
          OutlinedButton.icon(
            key: divanTransferButtonKey,
            onPressed: () => unawaited(
              _transfer(context, controller, l10n, folder, onFlash),
            ),
            icon: const Icon(Icons.drive_file_move_outline),
            label: Text(l10n.divanTransfer),
          ),
          OutlinedButton.icon(
            key: divanSyncButtonKey,
            onPressed: () =>
                unawaited(_sync(context, controller, l10n, onFlash)),
            icon: const Icon(Icons.sync),
            label: Text(l10n.divanSync),
          ),
          if (controller.busy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Notes column ──

class _NotebooksPane extends StatelessWidget {
  const _NotebooksPane({required this.controller, required this.l10n});

  final DivanController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = controller.notes;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Text(l10n.divanNotebooks, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        ListTile(
          key: divanAllNotebooksKey,
          dense: true,
          selected: controller.notebookFilter == null,
          leading: const Icon(Icons.all_inbox_outlined, size: 18),
          title: Text(l10n.divanAllNotebooks),
          trailing: Text(
            FaFormat.at(l10n.localeName, '${controller.notebooks.length}'),
          ),
          onTap: () => unawaited(controller.setNotebookFilter(null)),
        ),
        for (final notebook in controller.notebooks)
          ListTile(
            key: divanNotebookTileKey(notebook.id),
            dense: true,
            selected: controller.notebookFilter == notebook.id,
            leading: Icon(
              notebook.isArchived
                  ? Icons.inventory_2_outlined
                  : Icons.menu_book_outlined,
              size: 18,
            ),
            title: Text(notebook.name, overflow: TextOverflow.ellipsis),
            subtitle: notebook.isArchived
                ? Text(l10n.divanArchivedLabel)
                : null,
            trailing: PopupMenuButton<String>(
              key: divanNotebookMenuKey(notebook.id),
              tooltip: l10n.divanNotebookMenu,
              onSelected: (value) => unawaited(
                _notebookMenu(context, controller, l10n, notebook, value),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Text(l10n.divanRenameNotebook),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(
                    notebook.isArchived
                        ? l10n.divanRestoreNotebook
                        : l10n.divanArchiveNotebook,
                  ),
                ),
                PopupMenuItem(value: 'delete', child: Text(l10n.divanDelete)),
              ],
            ),
            onTap: () => unawaited(controller.setNotebookFilter(notebook.id)),
          ),
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(l10n.divanNotes, style: theme.textTheme.titleSmall),
            ),
            Text(
              FaFormat.at(l10n.localeName, '${notes.length}'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (notes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              l10n.divanNoNotes,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final note in notes)
          ListTile(
            key: divanNoteTileKey(note.id),
            dense: true,
            selected: controller.selected?.id == note.id,
            title: Text(
              note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                controller.notebookNameOf(note),
                if (note.tags.isNotEmpty) note.tags,
                DivanText.snippet(note.body, 60),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: Icon(
              note.pinned ? Icons.push_pin : Icons.notes_outlined,
              size: 18,
            ),
            onTap: () => unawaited(controller.select(note.id)),
          ),
      ],
    );
  }
}

// ── Editor ──

class _EditorPane extends StatelessWidget {
  const _EditorPane({
    required this.controller,
    required this.l10n,
    required this.title,
    required this.tags,
    required this.body,
    required this.preview,
    required this.onTogglePreview,
    required this.onOpenLink,
    required this.onSave,
  });

  final DivanController controller;
  final AppLocalizations l10n;
  final TextEditingController title;
  final TextEditingController tags;
  final TextEditingController body;

  /// True while the body is shown rendered instead of as source.
  final bool preview;

  /// Switches between source and preview.
  final VoidCallback onTogglePreview;

  /// Opens a wiki-link target.
  final Future<void> Function(String target) onOpenLink;

  final Future<void> Function(Note note) onSave;

  @override
  Widget build(BuildContext context) {
    final note = controller.selected;
    final theme = Theme.of(context);
    if (note == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.divanNoSelection,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final metrics = controller.metrics;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey(
                  'divan.editor.move.${note.id}.${note.notebookId}',
                ),
                initialValue: note.notebookId,
                isDense: true,
                decoration: InputDecoration(
                  labelText: l10n.divanFieldNotebook,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final notebook in controller.notebooks)
                    DropdownMenuItem(
                      value: notebook.id,
                      child: Text(notebook.name),
                    ),
                ],
                onChanged: (value) {
                  if (value == null || value == note.notebookId) return;
                  unawaited(controller.moveNote(note.id, value));
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: divanPinButtonKey,
              tooltip: note.pinned ? l10n.divanUnpin : l10n.divanPin,
              onPressed: () =>
                  unawaited(controller.setPinned(note.id, !note.pinned)),
              icon: Icon(
                note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              key: divanArchiveButtonKey,
              tooltip: note.archived ? l10n.divanRestore : l10n.divanArchive,
              onPressed: () =>
                  unawaited(controller.setArchived(note.id, !note.archived)),
              icon: Icon(
                note.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              key: divanPreviewToggleKey,
              tooltip: preview
                  ? l10n.divanEditorWrite
                  : l10n.divanEditorPreview,
              onPressed: onTogglePreview,
              isSelected: preview,
              icon: Icon(preview ? Icons.edit_note : Icons.visibility_outlined),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              key: divanDeleteNoteKey,
              tooltip: l10n.divanDelete,
              onPressed: () =>
                  unawaited(_deleteNote(context, controller, l10n)),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: divanTitleFieldKey,
          controller: title,
          decoration: InputDecoration(
            labelText: l10n.divanFieldTitle,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: divanTagsFieldKey,
          controller: tags,
          decoration: InputDecoration(
            labelText: l10n.divanFieldTags,
            helperText: l10n.divanFieldTagsHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        if (preview)
          // The preview renders the live draft, so a link or a checkbox can be tapped
          // before the note is saved.
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: DivanPreview(
                  body: body.text,
                  emptyLabel: l10n.divanPreviewEmpty,
                  resolveLink: (target) => controller.notes.any(
                    (candidate) =>
                        candidate.title.trim().toLowerCase() ==
                        target.trim().toLowerCase(),
                  ),
                  onOpenLink: (target) => unawaited(onOpenLink(target)),
                  onToggleItem: (lineNumber) => unawaited(
                    controller.toggleChecklistItem(note.id, lineNumber),
                  ),
                ),
              ),
            ),
          )
        else
          TextFormField(
            key: divanBodyFieldKey,
            controller: body,
            minLines: 8,
            maxLines: 20,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: l10n.divanFieldBody,
              helperText: l10n.divanFieldBodyHint,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.icon(
              key: divanSaveButtonKey,
              onPressed: () => unawaited(onSave(note)),
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.divanSave),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.divanUpdatedAt(_shortStamp(note.updatedAt)),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (metrics != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _StatChip(
                icon: Icons.text_fields,
                label: l10n.divanMetricWords(metrics.words),
              ),
              _StatChip(
                icon: Icons.abc,
                label: l10n.divanMetricCharacters(metrics.characters),
              ),
              _StatChip(
                icon: Icons.timer_outlined,
                label: l10n.divanMetricReading(metrics.readingSeconds),
              ),
              _StatChip(
                icon: Icons.check_box_outlined,
                label: l10n.divanMetricChecklist(
                  metrics.checklistDone,
                  metrics.checklistTotal,
                ),
              ),
              _StatChip(
                icon: Icons.link,
                label: l10n.divanMetricLinks(metrics.links.length),
              ),
            ],
          ),
        ],
        if (metrics != null && metrics.checklistTotal > 0) ...[
          const SizedBox(height: 16),
          Text(l10n.divanChecklist, style: theme.textTheme.titleSmall),
          for (final item in DivanText.checklist(note.body))
            CheckboxListTile(
              key: divanChecklistItemKey(item.lineNumber),
              dense: true,
              value: item.done,
              title: Text(item.text),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) => unawaited(
                controller.toggleChecklistItem(note.id, item.lineNumber),
              ),
            ),
        ],
        if (metrics != null && metrics.links.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.divanLinks, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final link in metrics.links)
                ActionChip(
                  label: Text(link),
                  onPressed: () => unawaited(_followLink(controller, link)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.divanBacklinks, style: theme.textTheme.titleSmall),
        if (controller.backlinks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              l10n.divanBacklinksEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final backlink in controller.backlinks)
            ListTile(
              dense: true,
              leading: const Icon(Icons.subdirectory_arrow_right, size: 18),
              title: Text(backlink.title),
              onTap: () => unawaited(controller.select(backlink.id)),
            ),
      ],
    );
  }

  /// Opens the note whose title matches a `[[wiki-link]]`, when it exists.
  static Future<void> _followLink(
    DivanController controller,
    String title,
  ) async {
    final needle = title.trim().toLowerCase();
    for (final note in controller.notes) {
      if (note.title.trim().toLowerCase() == needle) {
        await controller.select(note.id);
        return;
      }
    }
  }

  static String _shortStamp(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}';
  }
}

// ── Tools column ──

class _ToolsPane extends StatefulWidget {
  const _ToolsPane({required this.controller, required this.l10n});

  final DivanController controller;
  final AppLocalizations l10n;

  @override
  State<_ToolsPane> createState() => _ToolsPaneState();
}

class _ToolsPaneState extends State<_ToolsPane> {
  final TextEditingController _todo = TextEditingController();
  final TextEditingController _question = TextEditingController();

  @override
  void dispose() {
    _todo.dispose();
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final note = controller.selected;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.divanTodos, style: theme.textTheme.titleSmall),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: divanTodoFieldKey,
                controller: _todo,
                decoration: InputDecoration(
                  hintText: l10n.divanTodoHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (value) => unawaited(controller.addTodo(value)),
              ),
            ),
            IconButton(
              key: divanTodoAddButtonKey,
              tooltip: l10n.divanAdd,
              onPressed: () {
                unawaited(controller.addTodo(_todo.text));
                _todo.clear();
              },
              icon: const Icon(Icons.add_task),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (controller.todos.isEmpty)
          Text(
            l10n.divanTodosEmpty,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final todo in controller.todos)
            CheckboxListTile(
              dense: true,
              value: false,
              title: Text(todo.item.text),
              subtitle: Text(
                todo.note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) => unawaited(
                controller.toggleChecklistItem(
                  todo.note.id,
                  todo.item.lineNumber,
                ),
              ),
            ),
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(l10n.divanAi, style: theme.textTheme.titleSmall),
            ),
            if (controller.aiBusy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            TextButton(
              key: divanAiClearKey,
              onPressed: controller.clearAi,
              child: Text(l10n.divanAiClear),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              key: divanAiSummarizeKey,
              onPressed: note == null
                  ? null
                  : () => unawaited(controller.summarize()),
              icon: const Icon(Icons.summarize_outlined),
              label: Text(l10n.divanAiSummarize),
            ),
            OutlinedButton.icon(
              key: divanAiTitleKey,
              onPressed: note == null
                  ? null
                  : () => unawaited(controller.proposeTitle()),
              icon: const Icon(Icons.title),
              label: Text(l10n.divanAiTitle),
            ),
            OutlinedButton.icon(
              key: divanAiTagsKey,
              onPressed: note == null
                  ? null
                  : () => unawaited(controller.proposeTags()),
              icon: const Icon(Icons.sell_outlined),
              label: Text(l10n.divanAiTags),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: divanAskFieldKey,
                controller: _question,
                decoration: InputDecoration(
                  hintText: l10n.divanAskHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (value) => unawaited(controller.ask(value)),
              ),
            ),
            IconButton(
              key: divanAskButtonKey,
              tooltip: l10n.divanAiAsk,
              onPressed: () => unawaited(controller.ask(_question.text)),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
        if (controller.aiQuestion != null && controller.aiQuestion!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              controller.aiQuestion!,
              style: theme.textTheme.labelMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (controller.aiAnswer != null) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(controller.aiAnswer!),
            ),
          ),
          if (controller.aiKind == 'title' && note != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: divanAiApplyTitleKey,
                onPressed: () => unawaited(
                  controller.saveNote(
                    note.id,
                    title: controller.aiAnswer!.split('\n').first.trim(),
                  ),
                ),
                child: Text(l10n.divanAiApplyTitle),
              ),
            ),
          if (controller.aiKind == 'tags' && note != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: divanAiApplyTagsKey,
                onPressed: () => unawaited(
                  controller.saveNote(
                    note.id,
                    tags: controller.aiTags.join(','),
                  ),
                ),
                child: Text(l10n.divanAiApplyTags),
              ),
            ),
        ],
        const Divider(height: 24),
        Text(l10n.divanStats, style: theme.textTheme.titleSmall),
        if (controller.stats != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              FaFormat.at(
                l10n.localeName,
                l10n.divanStatsDetail(
                  controller.stats!.taggedNotes,
                  controller.stats!.links,
                ),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (controller.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final tag in controller.tags)
                ActionChip(
                  label: Text(tag),
                  onPressed: () => unawaited(controller.setTagFilter(tag)),
                ),
            ],
          ),
        ],
        if (controller.lastSync != null) ...[
          const SizedBox(height: 8),
          Text(
            controller.lastSync!.describe(),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

// ── Error card ──

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.l10n});

  final String message;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: () => context.read<DivanController>().refresh(),
                child: Text(l10n.divanDismiss),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dialogs ──

Future<void> _newNote(
  BuildContext context,
  DivanController controller,
  AppLocalizations l10n,
  Future<void> Function(Future<void> Function() action) onFlash,
) async {
  final result = await showDialog<_NewNoteResult>(
    context: context,
    builder: (context) => _NewNoteDialog(
      l10n: l10n,
      notebooks: controller.notebooks,
      defaultNotebookId: controller.notebookFilter,
    ),
  );
  if (result == null) return;
  await onFlash(
    () => controller.addNote(
      title: result.title,
      body: result.body,
      tags: result.tags,
      notebookId: result.notebookId,
    ),
  );
}

Future<void> _newNotebook(
  BuildContext context,
  DivanController controller,
  AppLocalizations l10n,
  Future<void> Function(Future<void> Function() action) onFlash,
) async {
  _NameDialog.cancel = l10n.divanCancel;
  _NameDialog.confirm = l10n.divanAdd;
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(
      title: l10n.divanNewNotebook,
      label: l10n.divanFieldNotebook,
    ),
  );
  if (name == null || name.trim().isEmpty) return;
  await onFlash(() => controller.createNotebook(name.trim()));
}

Future<void> _notebookMenu(
  BuildContext context,
  DivanController controller,
  AppLocalizations l10n,
  Notebook notebook,
  String action,
) async {
  switch (action) {
    case 'rename':
      _NameDialog.cancel = l10n.divanCancel;
      _NameDialog.confirm = l10n.divanSave;
      final name = await showDialog<String>(
        context: context,
        builder: (context) => _NameDialog(
          title: l10n.divanRenameNotebook,
          label: l10n.divanFieldNotebook,
          initial: notebook.name,
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      await controller.renameNotebook(notebook.id, name.trim());
    case 'archive':
      await controller.setNotebookArchived(notebook.id, !notebook.isArchived);
    case 'delete':
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.divanDeleteNotebookTitle(notebook.name)),
          content: Text(l10n.divanDeleteNotebookBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.divanCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.divanDelete),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await controller.deleteNotebook(notebook.id);
      if (controller.error != null) {
        // The notebook still holds notes — the .NET rule — so retry with force.
        await controller.deleteNotebook(notebook.id, force: true);
      }
  }
}

Future<void> _deleteNote(
  BuildContext context,
  DivanController controller,
  AppLocalizations l10n,
) async {
  final note = controller.selected;
  if (note == null) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.divanDeleteNoteTitle(note.title)),
      content: Text(l10n.divanDeleteUndoable),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.divanCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.divanDelete),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await controller.deleteNote(note.id);
}

Future<void> _transfer(
  BuildContext context,
  DivanController controller,
  AppLocalizations l10n,
  String folder,
  Future<void> Function(Future<void> Function() action) onFlash,
) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => _TransferDialog(l10n: l10n, folder: folder),
  );
  if (choice == null) return;

  final parts = choice.split('\u0001');
  final mode = parts.first;
  final path = parts.length > 1 ? parts[1] : '';
  if (path.trim().isEmpty) return;

  await onFlash(
    mode == 'export'
        ? () => controller.export(path.trim())
        : () => controller.import(path.trim()),
  );
}

Future<void> _sync(
  BuildContext context,
  DivanController controller,
  AppLocalizations l10n,
  Future<void> Function(Future<void> Function() action) onFlash,
) async {
  final mode = await showDialog<SyncMode>(
    context: context,
    builder: (context) => _SyncDialog(l10n: l10n),
  );
  if (mode == null) return;
  await onFlash(() => controller.syncNow(mode: mode));
}

class _NewNoteResult {
  const _NewNoteResult({
    required this.title,
    required this.body,
    required this.tags,
    required this.notebookId,
  });

  final String title;
  final String body;
  final String tags;
  final int? notebookId;
}

class _NewNoteDialog extends StatefulWidget {
  const _NewNoteDialog({
    required this.l10n,
    required this.notebooks,
    required this.defaultNotebookId,
  });

  final AppLocalizations l10n;
  final List<Notebook> notebooks;
  final int? defaultNotebookId;

  @override
  State<_NewNoteDialog> createState() => _NewNoteDialogState();
}

class _NewNoteDialogState extends State<_NewNoteDialog> {
  late final TextEditingController _title = TextEditingController();
  late final TextEditingController _tags = TextEditingController();
  late final TextEditingController _body = TextEditingController();
  late int? _notebookId = widget.defaultNotebookId;

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.l10n.divanNewNote),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('divan.dialog.title'),
            controller: _title,
            autofocus: true,
            decoration: InputDecoration(labelText: widget.l10n.divanFieldTitle),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            key: const Key('divan.dialog.notebook'),
            initialValue: _notebookId,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(widget.l10n.divanDefaultNotebook),
              ),
              for (final notebook in widget.notebooks)
                DropdownMenuItem(
                  value: notebook.id,
                  child: Text(notebook.name),
                ),
            ],
            onChanged: (value) => setState(() => _notebookId = value),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('divan.dialog.tags'),
            controller: _tags,
            decoration: InputDecoration(labelText: widget.l10n.divanFieldTags),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('divan.dialog.body'),
            controller: _body,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(labelText: widget.l10n.divanFieldBody),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.l10n.divanCancel),
      ),
      FilledButton(
        key: const Key('divan.dialog.save'),
        onPressed: () => Navigator.of(context).pop(
          _NewNoteResult(
            title: _title.text,
            body: _body.text,
            tags: _tags.text,
            notebookId: _notebookId,
          ),
        ),
        child: Text(widget.l10n.divanAdd),
      ),
    ],
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    this.initial = '',
  });

  final String title;
  final String label;
  final String initial;

  /// Localized cancel label.
  static String cancel = 'Cancel';

  /// Localized confirm label.
  static String confirm = 'OK';

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 360,
      child: TextField(
        key: const Key('divan.dialog.name'),
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(_NameDialog.cancel),
      ),
      FilledButton(
        key: const Key('divan.dialog.name.save'),
        onPressed: () => Navigator.of(context).pop(_name.text),
        child: Text(_NameDialog.confirm),
      ),
    ],
  );
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.l10n, required this.folder});

  final AppLocalizations l10n;
  final String folder;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late final TextEditingController _path = TextEditingController(
    text: widget.folder,
  );

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.l10n.divanTransfer),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.l10n.divanTransferHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            key: divanTransferFieldKey,
            controller: _path,
            decoration: InputDecoration(
              labelText: widget.l10n.divanFieldFolder,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.l10n.divanCancel),
      ),
      OutlinedButton(
        key: const Key('divan.transfer.import'),
        onPressed: () => Navigator.of(context).pop('import\u0001${_path.text}'),
        child: Text(widget.l10n.divanImport),
      ),
      FilledButton(
        key: const Key('divan.transfer.export'),
        onPressed: () => Navigator.of(context).pop('export\u0001${_path.text}'),
        child: Text(widget.l10n.divanExport),
      ),
    ],
  );
}

class _SyncDialog extends StatelessWidget {
  const _SyncDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(l10n.divanSync),
    content: Text(l10n.divanSyncHint),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.divanCancel),
      ),
      OutlinedButton(
        key: const Key('divan.sync.pull'),
        onPressed: () => Navigator.of(context).pop(SyncMode.pull),
        child: Text(l10n.divanSyncPull),
      ),
      OutlinedButton(
        key: const Key('divan.sync.push'),
        onPressed: () => Navigator.of(context).pop(SyncMode.push),
        child: Text(l10n.divanSyncPush),
      ),
      FilledButton(
        key: const Key('divan.sync.merge'),
        onPressed: () => Navigator.of(context).pop(SyncMode.merge),
        child: Text(l10n.divanSyncMerge),
      ),
    ],
  );
}
