/// haftkhan — see doc/haftkhan.md and AGENTS.md
import '../../core/date_only.dart';
import '../sync/sync_client.dart';
import '../sync/sync_models.dart';
import 'backup.dart';
import 'models.dart';
import 'recurrence.dart';
import 'task_guard.dart';
import 'task_repository.dart';

class HaftKhanService {
  HaftKhanService({
    required TaskRepository repository,
    required DateTime Function() clock,
    HaftKhanOptions? options,
  }) : _repository = repository,
       _clock = clock,
       _options = _validated(options ?? const HaftKhanOptions());

  final TaskRepository _repository;
  final DateTime Function() _clock;

  final HaftKhanOptions _options;

  /// The validated options in effect (surfaced for tests and diagnostics).
  HaftKhanOptions get options => _options;

  /// Creates and stores a new task.
  ///
  /// Throws [ArgumentError] for an invalid title, tags, dates, or a blocker id that does not
  /// exist; [RangeError] for a value over its configured cap.
  Future<HaftKhanTask> addTask({
    String? title,
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
    final newTask = NewTask(
      title: TaskGuard.cleanTitle(title, _options.maxTitleLength),
      notes: TaskGuard.cleanNotes(notes, _options.maxNotesLength),
      priority: TaskGuard.parsePriority(priorityName),
      dueDate: TaskGuard.parseDueDate(dueDateText, today()),
      project: TaskGuard.cleanProject(project, _options.maxTitleLength),
      tags: TaskGuard.cleanTags(
        tagsCsv,
        maxTags: _options.maxTagsPerTask,
        maxTagLength: _options.maxTagLength,
      ),
      effort: TaskGuard.parseEffort(effortName),
      recurrence: TaskGuard.parseRecurrenceKind(recurrenceName),
      recurrenceInterval: TaskGuard.parseRecurrenceInterval(
        intervalText,
        _options.maxRecurrenceInterval,
      ),
      blockedBy: blockedBy ?? const [],
    );

    for (final blocker in newTask.blockedBy) {
      if (await _repository.find(blocker) == null) {
        throw ArgumentError.value(
          blocker,
          'blockedBy',
          'Blocker task $blocker does not exist.',
        );
      }
    }

    // A brand-new task has no incoming edges yet, so no cycle is possible here.
    final created = await _repository.add(newTask);
    await _pushUndo('add', const [], createdIds: [created.id]);
    return created;
  }

  /// Gets one task, or throws when it does not exist.
  Future<HaftKhanTask> find(String? idText) async {
    final id = TaskGuard.parseId(idText);
    final task = await _repository.find(id);
    if (task == null) throw TaskNotFoundException(id);
    return task;
  }

  /// Marks an open task as in progress (records the start time once).
  ///
  /// Throws [StateError] when the task is already done.
  Future<HaftKhanTask> start(String? idText) async {
    final task = await find(idText);
    if (task.state == TaskState.done) {
      throw StateError('Task ${task.id} is already done.');
    }

    final updated = task.copyWith(
      state: TaskState.doing,
      updatedAt: _now(),
      startedAt: task.startedAt ?? _now(),
    );
    await _pushUndo('start', [task]);
    await _repository.update(updated);
    return updated;
  }

  /// Completes a task (recording the completion time).
  ///
  /// Recurring tasks spawn their next occurrence automatically. Open blockers refuse
  /// completion unless [force] is true.
  ///
  /// Throws [StateError] when the task is already done or is blocked without [force].
  Future<CompleteResult> complete(String? idText, {bool force = false}) async {
    final task = await find(idText);
    if (task.state == TaskState.done) {
      throw StateError('Task ${task.id} is already done.');
    }

    final blockers = await _openBlockersOf(task.id);
    if (blockers.isNotEmpty && !force) {
      throw StateError(
        'Task ${task.id} is blocked by open task(s): ${_describe(blockers)}. '
        'Confirm to conquer anyway.',
      );
    }

    final now = _now();
    await _pushUndo('done', [task]);
    await _repository.update(
      task.copyWith(state: TaskState.done, updatedAt: now, completedAt: now),
    );

    if (task.recurrence == RecurrenceKind.none) {
      return CompleteResult(await find(idText), null);
    }

    final nextDue = Recurrence.nextDue(
      task.recurrence,
      task.recurrenceInterval,
      task.dueDate,
      DateOnly.fromDateTime(now.toUtc()),
    );
    final spawned = await _repository.add(
      NewTask(
        title: task.title,
        notes: task.notes,
        priority: task.priority,
        dueDate: nextDue,
        project: task.project,
        tags: List.of(task.tags),
        effort: task.effort,
        recurrence: task.recurrence,
        recurrenceInterval: task.recurrenceInterval,
      ),
    );
    await _pushUndo('respawn', const [], createdIds: [spawned.id]);
    return CompleteResult(await find(idText), spawned);
  }

  /// Removes a task (undoable). Throws when it does not exist.
  Future<void> remove(String? idText) async {
    final task = await find(idText);
    await _pushUndo('remove', [task]);
    await _repository.remove(task.id);
  }

  /// Removes all completed tasks (undoable) and returns how many were removed.
  Future<int> clearCompleted() async {
    final done = (await _repository.listAll())
        .where((task) => task.state == TaskState.done)
        .toList();
    await _pushUndo('clear-done', done);
    return _repository.removeCompleted();
  }

  /// Lists the requested view.
  Future<List<HaftKhanTask>> list(TaskView view) async {
    switch (view) {
      case TaskView.open:
        return _repository.listOpen();
      case TaskView.all:
        return _repository.listAll();
      case TaskView.done:
        final all = await _repository.listAll();
        return List.unmodifiable(
          all.where((task) => task.state == TaskState.done),
        );
      case TaskView.today:
        final today = this.today();
        final due = await _repository.listDueOnOrBefore(today);
        return List.unmodifiable(due.where((task) => task.dueDate == today));
      case TaskView.overdue:
        final today = this.today();
        final due = await _repository.listDueOnOrBefore(today);
        return List.unmodifiable(
          due.where((task) => task.dueDate != null && task.dueDate! < today),
        );
    }
  }

  /// Lists a view with filters: a tag (case-insensitive), a project (case-insensitive),
  /// and/or a minimum priority.
  Future<List<HaftKhanTask>> listFiltered(
    TaskView view, {
    String? tag,
    String? project,
    String? priorityName,
  }) async {
    var tasks = await list(view);

    if (priorityName != null) {
      final minPriority = TaskGuard.parsePriority(priorityName);
      tasks = tasks
          .where((task) => task.priority.code >= minPriority.code)
          .toList();
    }

    final needleTag = tag?.trim();
    if (needleTag != null && needleTag.isNotEmpty) {
      tasks = tasks
          .where(
            (task) => task.tags.any(
              (existing) => existing.toLowerCase() == needleTag.toLowerCase(),
            ),
          )
          .toList();
    }

    final needleProject = project?.trim();
    if (needleProject != null && needleProject.isNotEmpty) {
      tasks = tasks
          .where(
            (task) => task.project.toLowerCase() == needleProject.toLowerCase(),
          )
          .toList();
    }

    return List.unmodifiable(tasks);
  }

  /// Searches title, notes, project, and tags for a case-insensitive substring.
  ///
  /// Throws [ArgumentError] for an empty query.
  Future<List<HaftKhanTask>> search(String? query) async {
    if (query == null || query.trim().isEmpty) {
      throw ArgumentError.value(
        query,
        'query',
        'The search text must not be empty.',
      );
    }

    final needle = query.trim().toLowerCase();
    bool hit(String text) => text.toLowerCase().contains(needle);

    final all = await _repository.listAll();
    return List.unmodifiable(
      all.where(
        (task) =>
            hit(task.title) ||
            hit(task.notes) ||
            hit(task.project) ||
            task.tags.any(hit),
      ),
    );
  }

  /// The kanban board: to-do, doing, and recently-conquered columns.
  Future<List<BoardColumn>> board() async {
    final open = await _repository.listOpen();
    final done =
        (await _repository.listAll())
            .where((task) => task.state == TaskState.done)
            .toList()
          ..sort((a, b) {
            final left = a.completedAt;
            final right = b.completedAt;
            if (left == null && right == null) return 0;
            if (left == null) return 1;
            if (right == null) return -1;
            return right.compareTo(left);
          });

    List<HaftKhanTask> column(TaskState state) => List.unmodifiable(
      open
          .where((task) => task.state == state)
          .take(_options.boardTasksPerColumn),
    );

    return List.unmodifiable([
      BoardColumn('TODO', column(TaskState.todo)),
      BoardColumn('DOING', column(TaskState.doing)),
      BoardColumn(
        'DONE',
        List.unmodifiable(done.take(_options.boardTasksPerColumn)),
      ),
    ]);
  }

  /// The Eisenhower matrix over open tasks (urgency = overdue/today, importance = high/critical).
  Future<List<MatrixQuadrant>> matrix() async {
    final today = this.today();
    final open = await _repository.listOpen();

    bool isUrgent(HaftKhanTask task) =>
        task.dueDate != null && task.dueDate! <= today;
    bool isImportant(HaftKhanTask task) =>
        task.priority == TaskPriority.high ||
        task.priority == TaskPriority.critical;

    List<HaftKhanTask> pick(bool Function(HaftKhanTask) test) =>
        List.unmodifiable(open.where(test));

    return List.unmodifiable([
      MatrixQuadrant(
        'DO NOW — urgent + important',
        pick((task) => isUrgent(task) && isImportant(task)),
      ),
      MatrixQuadrant(
        'SCHEDULE — important, not urgent',
        pick((task) => !isUrgent(task) && isImportant(task)),
      ),
      MatrixQuadrant(
        'DELEGATE — urgent, not important',
        pick((task) => isUrgent(task) && !isImportant(task)),
      ),
      MatrixQuadrant(
        'LATER — neither',
        pick((task) => !isUrgent(task) && !isImportant(task)),
      ),
    ]);
  }

  /// The single next best labour: first unblocked open task in priority order, or null.
  Future<HaftKhanTask?> nextFocus() async {
    final blockedIds = await _blockedIds();
    final open = await _repository.listOpen();
    for (final task in open) {
      if (!blockedIds.contains(task.id)) return task;
    }
    return null;
  }

  /// Rich productivity report: counts, overdue, today/7-day completions, streaks, focus picks.
  Future<ProductivityReport> report() async {
    final today = this.today();
    final counts = await _repository.countByState(today);
    final all = await _repository.listAll();

    final completions =
        all
            .where(
              (task) =>
                  task.state == TaskState.done && task.completedAt != null,
            )
            .map((task) => DateOnly.fromDateTime(task.completedAt!.toUtc()))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final doneToday = all
        .where(
          (task) =>
              task.state == TaskState.done &&
              task.completedAt != null &&
              DateOnly.fromDateTime(task.completedAt!.toUtc()) == today,
        )
        .length;
    final doneLast7Days = all
        .where(
          (task) =>
              task.state == TaskState.done &&
              task.completedAt != null &&
              DateOnly.fromDateTime(task.completedAt!.toUtc()) >
                  today.addDays(-7),
        )
        .length;

    final blockedIds = await _blockedIds();
    final open = await _repository.listOpen();

    return ProductivityReport(
      todo: counts.todo,
      doing: counts.doing,
      done: counts.done,
      overdue: counts.overdue,
      doneToday: doneToday,
      doneLast7Days: doneLast7Days,
      currentStreak: _currentStreak(completions, today),
      bestStreak: _bestStreak(completions),
      focus: List.unmodifiable(
        open
            .where((task) => !blockedIds.contains(task.id))
            .take(_options.reviewFocusCount),
      ),
    );
  }

  /// Reverts the last mutating operation.
  ///
  /// Throws [StateError] when the undo history is empty.
  Future<UndoResult> undo() => _repository.undo();

  /// Imports tasks from a parsed backup (ids are reassigned; dependency edges are remapped).
  ///
  /// When [replace] is true the current list is cleared first (undoable).
  ///
  /// Throws [RangeError] when the backup holds more tasks than [HaftKhanOptions.maxImportTasks].
  Future<({int tasks, int links})> importBackup(
    BackupFile backup, {
    required bool replace,
  }) async {
    if (backup.tasks.length > _options.maxImportTasks) {
      throw RangeError('Import is capped at ${_options.maxImportTasks} tasks.');
    }

    if (replace) {
      await _pushUndo(
        'import-replace',
        await _repository.listAll(),
        replaceAll: true,
      );
      for (final task in await _repository.listAll()) {
        if (task.state != TaskState.done) {
          await _repository.remove(task.id);
        }
      }
      await _repository.removeCompleted();
    }

    final today = this.today();
    final idMap = <int, int>{};
    final uidMap = <String, int>{};
    final createdIds = <int>[];

    for (final dto in backup.tasks) {
      final created = await _repository.add(
        NewTask(
          title: TaskGuard.cleanTitle(dto.title, _options.maxTitleLength),
          notes: TaskGuard.cleanNotes(dto.notes, _options.maxNotesLength),
          priority: TaskGuard.parsePriority(
            TaskPriority.fromCode(dto.priority).name,
          ),
          dueDate: dto.dueDate == null || dto.dueDate!.isEmpty
              ? null
              : TaskGuard.parseDueDate(dto.dueDate, today),
          project: TaskGuard.cleanProject(dto.project, _options.maxTitleLength),
          tags: TaskGuard.cleanTags(
            dto.tags.join(','),
            maxTags: _options.maxTagsPerTask,
            maxTagLength: _options.maxTagLength,
          ),
          effort: _validateImportedEnum(
            dto.effort,
            TaskEffort.fromCode,
            'TaskEffort',
          ),
          recurrence: _validateImportedEnum(
            dto.recurrence,
            RecurrenceKind.fromCode,
            'RecurrenceKind',
          ),
          recurrenceInterval: TaskGuard.parseRecurrenceInterval(
            dto.recurrenceInterval.toString(),
            _options.maxRecurrenceInterval,
          ),
          uid: dto.uid,
        ),
      );

      idMap[dto.id] = created.id;
      if (created.uid.isNotEmpty) uidMap[created.uid] = created.id;
      createdIds.add(created.id);
    }

    var links = 0;
    for (final dependency in backup.dependencies) {
      int? taskId;
      int? dependsOnId;

      final taskUid = dependency.taskUid;
      final dependsOnUid = dependency.dependsOnUid;
      if (taskUid != null &&
          taskUid.isNotEmpty &&
          dependsOnUid != null &&
          dependsOnUid.isNotEmpty) {
        taskId = uidMap[taskUid];
        dependsOnId = uidMap[dependsOnUid];
      }

      taskId ??= idMap[dependency.taskId];
      dependsOnId ??= idMap[dependency.dependsOnId];

      if (taskId != null && dependsOnId != null) {
        await _repository.addDependency(taskId, dependsOnId);
        links++;
      }
    }

    await _pushUndo('import', const [], createdIds: createdIds);
    return (tasks: createdIds.length, links: links);
  }

  /// Every task plus every dependency edge — the export payload.
  Future<({List<HaftKhanTask> tasks, List<TaskLink> dependencies})>
  exportData() async => (
    tasks: await _repository.listAll(),
    dependencies: await _repository.listDependencies(),
  );

  /// Syncs with a remote document.
  ///
  /// [SyncMode.merge] pulls, merges by stable uid (last-write-wins on `updatedAt`, ties keep
  /// local), unions dependencies, and pushes the merged result so both sides converge;
  /// [SyncMode.pull] only merges locally; [SyncMode.push] replaces the remote (refused while
  /// the remote is non-empty unless [force]). The whole merge is undoable.
  ///
  /// Throws [SyncException] for a transport, protocol, or push-safety failure.
  Future<SyncReport> sync(
    SyncClient client, {
    SyncMode mode = SyncMode.merge,
    bool force = false,
  }) async {
    final localTasks = await _repository.listAll();
    final remote = await _parseRemote(await client.get());
    final remoteTasks = [
      ...remote.tasks,
    ]; // sorted below, so never the shared const list

    if (mode == SyncMode.push) {
      if (remoteTasks.isNotEmpty && !force) {
        throw SyncException(
          'The remote already holds ${remoteTasks.length} task(s); pushing replaces them. '
          'Confirm to overwrite.',
        );
      }

      final pushed = await _push(client);
      return SyncReport(
        mode: SyncMode.push,
        pulled: 0,
        pushed: pushed,
        total: localTasks.length,
      );
    }

    // Snapshot the whole store first — undo reverts the entire merge.
    await _pushUndo('sync', localTasks, replaceAll: true);

    var pulled = 0;
    remoteTasks.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    for (final remoteTask in remoteTasks) {
      final existing = await _repository.findByUid(remoteTask.uid);
      if (existing != null &&
          !existing.updatedAt.isBefore(remoteTask.updatedAt)) {
        continue; // local wins (last-write-wins; ties keep local)
      }

      await _repository.upsert(remoteTask);
      pulled++;
    }

    await _mergeDependencies(remote.dependencies);
    final total = (await _repository.listAll()).length;

    if (mode == SyncMode.pull) {
      return SyncReport(
        mode: SyncMode.pull,
        pulled: pulled,
        pushed: 0,
        total: total,
      );
    }

    final pushedCount = await _push(client);
    return SyncReport(
      mode: SyncMode.merge,
      pulled: pulled,
      pushed: pushedCount,
      total: total,
    );
  }

  /// Adds a dependency edge between existing tasks: [idText] becomes blocked until every id
  /// in [blockedByCsv] is done. Cycle-safe.
  ///
  /// Throws [ArgumentError] for an unknown id or a self-link, [StateError] when the link
  /// would close a dependency cycle.
  Future<void> addLink(String? idText, String? blockedByCsv) async {
    final task = await find(idText);
    for (final blocker in TaskGuard.parseIdList(blockedByCsv)) {
      if (await _repository.find(blocker) == null) {
        throw ArgumentError('Blocker task $blocker does not exist.');
      }
      if (blocker == task.id) {
        throw ArgumentError('A task cannot block itself.');
      }
      if (await _reaches(blocker, task.id)) {
        throw StateError(
          'Dependency rejected: task ${task.id} would depend on itself through a cycle.',
        );
      }

      await _repository.addDependency(task.id, blocker);
    }
  }

  /// The ids of the tasks currently blocking [id] (unfinished blockers only).
  ///
  /// Exposed for the UI: a row can then say *why* it refuses completion instead of only
  /// failing when the user tries.
  Future<List<int>> blockersOf(int id) => _openBlockersOf(id);

  /// Removes every dependency edge of a task (both directions).
  Future<void> removeLinks(String? idText) async {
    final task = await find(idText);
    await _pushUndo('unlink', [task]);
    await _repository.removeDependenciesFor(task.id);
  }

  /// Today in UTC — the day every "today"/"overdue" decision is measured against.
  DateOnly today() => DateOnly.fromDateTime(_clock().toUtc());

  // --- internals ---------------------------------------------------------------

  static HaftKhanOptions _validated(HaftKhanOptions value) {
    value.validate(); // fail fast: bad limits never reach business logic
    return value;
  }

  DateTime _now() => _clock().toUtc();

  /// Parses the remote payload; empty when the remote does not exist yet.
  ///
  /// A payload that is not a Haft Khan backup is a protocol failure, not a merge candidate:
  /// nothing local is touched.
  static Future<({List<HaftKhanTask> tasks, List<DependencyDto> dependencies})>
  _parseRemote(String? json) async {
    if (json == null) {
      return (
        tasks: const <HaftKhanTask>[],
        dependencies: const <DependencyDto>[],
      );
    }

    try {
      final backup = Backup.fromJson(json);
      return (
        tasks: backup.tasks.map(Backup.fromDto).toList(),
        dependencies: backup.dependencies,
      );
    } catch (_) {
      throw const SyncException(
        'The remote did not return a valid Haft Khan backup.',
      );
    }
  }

  /// Uploads the full local store as a version-2 backup.
  Future<int> _push(SyncClient client) async {
    final data = await exportData();
    final dependencies = <DependencyDto>[];
    for (final link in data.dependencies) {
      dependencies.add(
        DependencyDto(
          taskId: link.taskId,
          dependsOnId: link.dependsOnId,
          taskUid: (await _repository.find(link.taskId))?.uid,
          dependsOnUid: (await _repository.find(link.dependsOnId))?.uid,
        ),
      );
    }

    final backup = BackupFile(
      version: Backup.currentVersion,
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      tasks: data.tasks.map(Backup.toDto).toList(),
      dependencies: dependencies,
    );

    await client.put(Backup.toJson(backup));
    return data.tasks.length;
  }

  /// Unions local and remote dependency edges (matched by stable uid), then applies the result.
  Future<void> _mergeDependencies(
    List<DependencyDto> remoteDependencies,
  ) async {
    final tasks = await _repository.listAll();
    final idToUid = {for (final task in tasks) task.id: task.uid};

    final pairs = <String>{};
    for (final link in await _repository.listDependencies()) {
      final a = idToUid[link.taskId];
      final b = idToUid[link.dependsOnId];
      if (a != null && b != null) pairs.add('$a\u0000$b');
    }

    for (final dependency in remoteDependencies) {
      final taskUid = dependency.taskUid;
      final dependsOnUid = dependency.dependsOnUid;
      if (taskUid != null &&
          taskUid.isNotEmpty &&
          dependsOnUid != null &&
          dependsOnUid.isNotEmpty) {
        pairs.add('$taskUid\u0000$dependsOnUid');
      }
    }

    final uidToId = {for (final task in tasks) task.uid: task.id};
    final merged = <TaskLink>[];
    for (final pair in pairs) {
      final parts = pair.split('\u0000');
      final taskId = uidToId[parts[0]];
      final dependsOnId = uidToId[parts[1]];
      if (taskId != null && dependsOnId != null) {
        merged.add(TaskLink(taskId, dependsOnId));
      }
    }

    merged.sort((a, b) {
      final byTask = a.taskId.compareTo(b.taskId);
      return byTask != 0 ? byTask : a.dependsOnId.compareTo(b.dependsOnId);
    });

    await _repository.setDependencies(merged);
  }

  /// Walks blocker edges upward from [from] looking for [target].
  Future<bool> _reaches(int from, int target) async {
    final adjacency = <int, List<int>>{};
    for (final link in await _repository.listDependencies()) {
      adjacency.putIfAbsent(link.taskId, () => []).add(link.dependsOnId);
    }

    final visited = <int>{};
    final stack = <int>[from];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (current == target) return true;
      if (!visited.add(current)) continue;

      final blockers = adjacency[current];
      if (blockers != null) stack.addAll(blockers);
    }

    return false;
  }

  Future<List<int>> _openBlockersOf(int taskId) async {
    final links = await _repository.listDependencies();
    final blockers = <int>{
      for (final link in links)
        if (link.taskId == taskId) link.dependsOnId,
    };

    final open = <int>[];
    for (final blocker in blockers) {
      final task = await _repository.find(blocker);
      if (task != null && task.state != TaskState.done) open.add(blocker);
    }
    return open;
  }

  Future<Set<int>> _blockedIds() async {
    final openIds = {for (final task in await _repository.listOpen()) task.id};
    final blocked = <int>{};
    for (final link in await _repository.listDependencies()) {
      if (!openIds.contains(link.taskId)) continue;
      final blocker = await _repository.find(link.dependsOnId);
      if (blocker != null && blocker.state != TaskState.done) {
        blocked.add(link.taskId);
      }
    }
    return blocked;
  }

  Future<void> _pushUndo(
    String operation,
    List<HaftKhanTask> affected, {
    bool replaceAll = false,
    List<int>? createdIds,
  }) async {
    final tags = <int, List<String>>{};
    for (final task in affected) {
      tags[task.id] = await _repository.getTags(task.id);
    }

    final ids = {for (final task in affected) task.id};
    final dependencies = ids.isEmpty
        ? const <TaskLink>[]
        : (await _repository.listDependencies())
              .where(
                (link) =>
                    ids.contains(link.taskId) || ids.contains(link.dependsOnId),
              )
              .toList();

    await _repository.pushUndo(
      UndoSnapshot(
        operation: operation,
        tasks: affected,
        tags: tags,
        dependencies: dependencies,
        createdTaskIds: createdIds ?? const [],
        replaceAll: replaceAll,
      ),
      maxDepth: _options.maxUndoDepth,
    );
  }

  static String _describe(Iterable<int> ids) =>
      ids.map((id) => '#$id').join(', ');

  static int _currentStreak(
    List<DateOnly> completionsDescending,
    DateOnly today,
  ) {
    if (completionsDescending.isEmpty) return 0;

    final expected = completionsDescending.first == today
        ? today
        : today.addDays(-1);
    if (completionsDescending.first != expected) return 0;

    var streak = 0;
    var cursor = expected;
    for (final date in completionsDescending) {
      if (date != cursor) break;
      streak++;
      cursor = cursor.addDays(-1);
    }
    return streak;
  }

  static int _bestStreak(List<DateOnly> completionsDescending) {
    if (completionsDescending.isEmpty) return 0;

    var best = 1;
    var run = 1;
    for (var i = 1; i < completionsDescending.length; i++) {
      run = completionsDescending[i] == completionsDescending[i - 1].addDays(-1)
          ? run + 1
          : 1;
      if (run > best) best = run;
    }
    return best;
  }

  static T _validateImportedEnum<T>(
    int value,
    T Function(int) parse,
    String typeName,
  ) {
    try {
      return parse(value);
    } on ArgumentError {
      throw ArgumentError('Imported value $value is not a valid $typeName.');
    }
  }
}
