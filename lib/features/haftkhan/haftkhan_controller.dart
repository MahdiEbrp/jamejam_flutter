/// haftkhan — see doc/haftkhan.md and AGENTS.md
import 'package:flutter/foundation.dart';

import '../soroush/ai_funnel.dart';
import 'ai_task_assistant.dart';
import 'backup.dart';
import 'haftkhan_service.dart';
import 'models.dart';

enum HaftKhanTab {
  /// The task list, with its views and filters.
  list,

  /// The kanban board (to-do / doing / done).
  board,

  /// The Eisenhower matrix.
  matrix,

  /// Counts, streaks and focus picks.
  report,
}

class HaftKhanController extends ChangeNotifier {
  HaftKhanController({
    required HaftKhanService service,
    required AiFunnel funnel,
    AiTaskAssistant? assistant,
    DateTime Function()? clock,
  }) : _service = service,
       _funnel = funnel,
       _assistant = assistant ?? AiTaskAssistant(),
       _clock = clock ?? DateTime.now;

  final HaftKhanService _service;
  final AiFunnel _funnel;
  final AiTaskAssistant _assistant;
  final DateTime Function() _clock;

  /// The engine underneath — surfaced so the screen can read its options in diagnostics.
  HaftKhanService get service => _service;

  HaftKhanTab _tab = HaftKhanTab.list;
  TaskView _view = TaskView.open;
  String _search = '';
  String? _tagFilter;
  String? _projectFilter;
  String? _priorityFilter;

  List<HaftKhanTask> _tasks = const [];
  Map<int, List<int>> _openBlockers = const {};
  ProductivityReport? _report;
  List<BoardColumn> _board = const [];
  List<MatrixQuadrant> _matrix = const [];
  bool _busy = false;
  bool _canUndo = false;
  String? _error;

  /// The visible tab.
  HaftKhanTab get tab => _tab;

  /// The active list view.
  TaskView get view => _view;

  /// The current search text (empty means "no search").
  String get search => _search;

  /// The active tag filter, if any.
  String? get tagFilter => _tagFilter;

  /// The active project filter, if any.
  String? get projectFilter => _projectFilter;

  /// The active priority filter, if any.
  String? get priorityFilter => _priorityFilter;

  /// The tasks to render.
  List<HaftKhanTask> get tasks => _tasks;

  /// Tasks that still have unfinished blockers, with the blocker ids.
  Map<int, List<int>> get openBlockers => _openBlockers;

  /// The latest productivity report (loaded when the report tab is shown).
  ProductivityReport? get report => _report;

  /// The latest board columns.
  List<BoardColumn> get board => _board;

  /// The latest matrix quadrants.
  List<MatrixQuadrant> get matrix => _matrix;

  /// True while an async action is running.
  bool get busy => _busy;

  /// Whether the engine has anything to undo.
  bool get canUndo => _canUndo;

  /// The last error message, or null.
  String? get error => _error;

  /// Every tag currently in use, sorted — the tag filter menu.
  List<String> get availableTags {
    final tags = <String>{};
    for (final task in _tasks) {
      tags.addAll(task.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  /// Every project currently in use, sorted — the project filter menu.
  List<String> get availableProjects {
    final projects = <String>{};
    for (final task in _tasks) {
      if (task.project.isNotEmpty) projects.add(task.project);
    }
    final sorted = projects.toList()..sort();
    return sorted;
  }

  /// True when a task is blocked by at least one unfinished task.
  bool isBlocked(int taskId) => (_openBlockers[taskId] ?? const []).isNotEmpty;

  /// Switches tabs (and loads whatever the tab needs).
  Future<void> showTab(HaftKhanTab value) async {
    _tab = value;
    notifyListeners();
    await refresh();
  }

  /// Switches the list view.
  Future<void> showView(TaskView value) async {
    _view = value;
    await refresh();
  }

  /// Sets the search text (empty clears it).
  Future<void> setSearch(String value) async {
    _search = value.trim();
    await refresh();
  }

  /// Sets or clears the tag filter.
  Future<void> setTagFilter(String? value) async {
    _tagFilter = (value == null || value.isEmpty) ? null : value;
    await refresh();
  }

  /// Sets or clears the project filter.
  Future<void> setProjectFilter(String? value) async {
    _projectFilter = (value == null || value.isEmpty) ? null : value;
    await refresh();
  }

  /// Sets or clears the minimum-priority filter.
  Future<void> setPriorityFilter(String? value) async {
    _priorityFilter = (value == null || value.isEmpty) ? null : value;
    await refresh();
  }

  /// Clears every filter.
  Future<void> clearFilters() async {
    _tagFilter = null;
    _projectFilter = null;
    _priorityFilter = null;
    _search = '';
    await refresh();
  }

  /// Reloads everything the current tab needs.
  Future<void> refresh() async {
    _busy = true;
    notifyListeners();

    try {
      _tasks = await _visibleTasks();
      _openBlockers = await _blockersFor(_tasks);
      _board = await _service.board();
      _matrix = await _service.matrix();
      _report = await _service.report();
      _canUndo = true; // only a failed undo proves otherwise; see [undo]
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Creates a task from raw form text — the same guarded path the CLI used.
  Future<HaftKhanTask> addTask({
    required String title,
    String? notes,
    String? priorityName,
    String? dueDateText,
    String? project,
    String? tagsCsv,
    String? effortName,
    String? recurrenceName,
    String? intervalText,
    List<int>? blockedBy,
  }) async {
    final task = await _service.addTask(
      title: title,
      notes: notes,
      priorityName: priorityName,
      dueDateText: dueDateText,
      project: project,
      tagsCsv: tagsCsv,
      effortName: effortName,
      recurrenceName: recurrenceName,
      intervalText: intervalText,
      blockedBy: blockedBy,
    );
    await refresh();
    return task;
  }

  /// Marks a task as in progress.
  Future<HaftKhanTask> start(int id) async {
    final task = await _service.start('$id');
    await refresh();
    return task;
  }

  /// Completes a task; recurring tasks spawn their successor.
  Future<CompleteResult> complete(int id, {bool force = false}) async {
    final result = await _service.complete('$id', force: force);
    await refresh();
    return result;
  }

  /// Deletes a task.
  Future<void> remove(int id) async {
    await _service.remove('$id');
    await refresh();
  }

  /// Deletes every completed task and returns how many went.
  Future<int> clearCompleted() async {
    final removed = await _service.clearCompleted();
    await refresh();
    return removed;
  }

  /// Reverts the last mutation.
  Future<UndoResult> undo() async {
    final result = await _service.undo();
    await refresh();
    return result;
  }

  /// The blocker ids preventing a task from being completed.
  Future<List<int>> blockersOf(int id) => _service.blockersOf(id);

  /// Links [id] to the tasks in [blockedByCsv] (cycle-safe).
  Future<void> link(int id, String blockedByCsv) async {
    await _service.addLink('$id', blockedByCsv);
    await refresh();
  }

  /// Removes every link of a task.
  Future<void> unlink(int id) async {
    await _service.removeLinks('$id');
    await refresh();
  }

  /// Asks the model to break one task into subtasks.
  ///
  /// The prompt is built by [AiTaskAssistant] (markers, untrusted-data rule, bounded sizes)
  /// and sent through the Soroush funnel, so the safety layer sanitizes it once more.
  Future<AiTaskPlan> breakdown(int id) async {
    if (!await _funnel.hasUsableKey()) {
      throw StateError(
        'The AI breakdown needs an API key — add one in Soroush AI.',
      );
    }

    final task = await _service.find('$id');
    final response = await _funnel.completeText(
      _assistant.buildBreakdownPrompt(task),
    );
    return AiTaskAssistant.parsePlan(response);
  }

  /// Asks the model for a status summary of the open tasks.
  Future<String> summarise() async {
    final open = await _service.list(TaskView.open);
    if (open.isEmpty) {
      throw StateError('Nothing open to summarise.');
    }
    if (!await _funnel.hasUsableKey()) {
      throw StateError(
        'The AI summary needs an API key — add one in Soroush AI.',
      );
    }

    return _funnel.completeText(_assistant.buildSummaryPrompt(open));
  }

  /// The whole store as a backup file (what export writes and sync uploads).
  Future<BackupFile> exportBackup() async {
    final exported = await _service.exportData();
    final dependencies = <DependencyDto>[];
    for (final link in exported.dependencies) {
      dependencies.add(
        DependencyDto(
          taskId: link.taskId,
          dependsOnId: link.dependsOnId,
          taskUid: (await _service.find('${link.taskId}')).uid,
          dependsOnUid: (await _service.find('${link.dependsOnId}')).uid,
        ),
      );
    }

    return BackupFile(
      version: Backup.currentVersion,
      exportedAt: _clock().toUtc().toIso8601String(),
      tasks: exported.tasks.map(Backup.toDto).toList(),
      dependencies: dependencies,
    );
  }

  /// The store as a human-readable markdown checklist.
  Future<String> exportMarkdown() async {
    final exported = await _service.exportData();
    return Backup.toMarkdown(exported.tasks, _service.today());
  }

  /// Imports a parsed backup; [replace] clears the current list first.
  Future<({int tasks, int links})> importBackup(
    BackupFile backup, {
    required bool replace,
  }) async {
    final result = await _service.importBackup(backup, replace: replace);
    await refresh();
    return result;
  }

  Future<List<HaftKhanTask>> _visibleTasks() async {
    final needle = _search;
    if (needle.isNotEmpty) {
      return _service.search(needle);
    }

    return _service.listFiltered(
      _view,
      tag: _tagFilter,
      project: _projectFilter,
      priorityName: _priorityFilter,
    );
  }

  /// Maps each visible open task to the ids of its unfinished blockers.
  Future<Map<int, List<int>>> _blockersFor(List<HaftKhanTask> tasks) async {
    final map = <int, List<int>>{};
    for (final task in tasks) {
      if (task.state == TaskState.done) continue;
      final blockers = await _service.blockersOf(task.id);
      if (blockers.isNotEmpty) map[task.id] = blockers;
    }
    return map;
  }
}
