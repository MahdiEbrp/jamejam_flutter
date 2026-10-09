/// haftkhan — see doc/haftkhan.md and AGENTS.md
import '../../core/date_only.dart';
import '../../core/uids.dart';
import 'models.dart';

abstract interface class TaskRepository {
  /// Stores a new task (with its tags and dependency links) and returns it with its id.
  Future<HaftKhanTask> add(NewTask task);

  /// Gets the task with [id], or null when absent.
  Future<HaftKhanTask?> find(int id);

  /// Overwrites an existing task (matched by id, tags replaced).
  Future<void> update(HaftKhanTask task);

  /// Removes the task with [id] (and its tags/dependency links). Returns true when it existed.
  Future<bool> remove(int id);

  /// Removes every completed task. Returns the number of removed tasks.
  Future<int> removeCompleted();

  /// Lists open tasks (to-do and doing): priority high→low, then due date, then id.
  Future<List<HaftKhanTask>> listOpen();

  /// Lists every task grouped by state, then priority, then due date.
  Future<List<HaftKhanTask>> listAll();

  /// Lists open tasks due on or before [dueDate], ordered by due date, then priority.
  Future<List<HaftKhanTask>> listDueOnOrBefore(DateOnly dueDate);

  /// Counts tasks per state, plus open tasks overdue relative to [today].
  Future<TaskCounts> countByState(DateOnly today);

  /// Finds a task by its stable sync identity, or null when absent.
  Future<HaftKhanTask?> findByUid(String uid);

  /// Inserts or updates a task matched by its stable uid (sync support): the local id is
  /// preserved when the task exists; content and timestamps come from [task] verbatim.
  Future<HaftKhanTask> upsert(HaftKhanTask task);

  /// Replaces every dependency edge (used by the sync merge).
  Future<void> setDependencies(List<TaskLink> links);

  /// Adds a dependency edge: [taskId] is blocked until [dependsOnId] is done.
  Future<void> addDependency(int taskId, int dependsOnId);

  /// Lists every dependency edge.
  Future<List<TaskLink>> listDependencies();

  /// Removes dependency edges in both directions for [taskId].
  Future<void> removeDependenciesFor(int taskId);

  /// Gets the tags stored for [taskId] (empty when it has none).
  Future<List<String>> getTags(int taskId);

  /// Pushes an undo snapshot (oldest entries are dropped beyond the depth limit).
  Future<void> pushUndo(UndoSnapshot snapshot, {required int maxDepth});

  /// Pops the newest snapshot and restores the prior state it describes.
  Future<UndoResult> undo();
}

abstract final class TaskOrdering {
  /// Open tasks: priority high→low, then due date (undated last), then id.
  static List<HaftKhanTask> open(List<HaftKhanTask> tasks) {
    final sorted = tasks.where((task) => task.isOpen).toList()
      ..sort(_byPriorityThenDue);
    return List.unmodifiable(sorted);
  }

  /// Every task: state, then priority high→low, then due date (undated last), then id.
  static List<HaftKhanTask> all(List<HaftKhanTask> tasks) {
    final sorted = [...tasks]..sort(_byStateThenPriorityThenDue);
    return List.unmodifiable(sorted);
  }

  /// Due-date-ordered open tasks due on or before [dueDate].
  static List<HaftKhanTask> dueOnOrBefore(
    List<HaftKhanTask> tasks,
    DateOnly dueDate,
  ) {
    final matching =
        tasks
            .where(
              (task) =>
                  task.isOpen &&
                  task.dueDate != null &&
                  task.dueDate! <= dueDate,
            )
            .toList()
          ..sort((a, b) {
            final byDate = a.dueDate!.compareTo(b.dueDate!);
            if (byDate != 0) return byDate;
            return b.priority.code.compareTo(a.priority.code);
          });
    return List.unmodifiable(matching);
  }

  static int _byStateThenPriorityThenDue(HaftKhanTask a, HaftKhanTask b) {
    final byState = a.state.code.compareTo(b.state.code);
    return byState != 0 ? byState : _byPriorityThenDue(a, b);
  }

  // One comparator per view, so a listing never depends on the sort's stability.
  static int _byPriorityThenDue(HaftKhanTask a, HaftKhanTask b) {
    final byDue = _compareDue(a.dueDate, b.dueDate);
    if (byDue != 0) return byDue;
    return b.priority.code.compareTo(a.priority.code);
  }

  static int _compareDue(DateOnly? a, DateOnly? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1; // undated tasks sort last
    if (b == null) return -1;
    return a.compareTo(b);
  }
}

class MemoryTaskRepository implements TaskRepository {
  final Map<int, HaftKhanTask> _tasks = {};
  final Map<int, List<String>> _tags = {};
  final List<TaskLink> _dependencies = [];
  final List<UndoSnapshot> _undo = [];
  int _nextId = 1;

  @override
  Future<HaftKhanTask> add(NewTask task) async {
    final id = _nextId++;
    final now = DateTime.now().toUtc();
    final created = HaftKhanTask(
      id: id,
      title: task.title,
      notes: task.notes,
      priority: task.priority,
      state: TaskState.todo,
      dueDate: task.dueDate,
      createdAt: now,
      updatedAt: now,
      project: task.project,
      tags: List.unmodifiable(task.tags),
      effort: task.effort,
      recurrence: task.recurrence,
      recurrenceInterval: task.recurrenceInterval,
      uid: (task.uid == null || task.uid!.isEmpty) ? Uids.newUid() : task.uid!,
    );

    _tasks[id] = created;
    _tags[id] = List.of(task.tags);
    for (final blocker in task.blockedBy) {
      await addDependency(id, blocker);
    }
    return created;
  }

  @override
  Future<HaftKhanTask?> find(int id) async => _tasks[id];

  @override
  Future<void> update(HaftKhanTask task) async {
    if (!_tasks.containsKey(task.id)) {
      throw TaskNotFoundException(task.id);
    }
    _tasks[task.id] = task;
    _tags[task.id] = List.of(task.tags);
  }

  @override
  Future<bool> remove(int id) async {
    final removed = _tasks.remove(id) != null;
    _tags.remove(id);
    _dependencies.removeWhere(
      (link) => link.taskId == id || link.dependsOnId == id,
    );
    return removed;
  }

  @override
  Future<int> removeCompleted() async {
    final done = _tasks.values
        .where((task) => task.state == TaskState.done)
        .toList();
    for (final task in done) {
      await remove(task.id);
    }
    return done.length;
  }

  @override
  Future<List<HaftKhanTask>> listOpen() async =>
      TaskOrdering.open(_tasks.values.toList());

  @override
  Future<List<HaftKhanTask>> listAll() async =>
      TaskOrdering.all(_tasks.values.toList());

  @override
  Future<List<HaftKhanTask>> listDueOnOrBefore(DateOnly dueDate) async =>
      TaskOrdering.dueOnOrBefore(_tasks.values.toList(), dueDate);

  @override
  Future<TaskCounts> countByState(DateOnly today) async {
    var todo = 0;
    var doing = 0;
    var done = 0;
    var overdue = 0;
    for (final task in _tasks.values) {
      switch (task.state) {
        case TaskState.todo:
          todo++;
        case TaskState.doing:
          doing++;
        case TaskState.done:
          done++;
      }
      if (task.isOpen && task.dueDate != null && task.dueDate! < today) {
        overdue++;
      }
    }
    return TaskCounts(todo: todo, doing: doing, done: done, overdue: overdue);
  }

  @override
  Future<HaftKhanTask?> findByUid(String uid) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'The uid must not be empty.');
    }
    for (final task in _tasks.values) {
      if (task.uid == uid) return task;
    }
    return null;
  }

  @override
  Future<HaftKhanTask> upsert(HaftKhanTask task) async {
    final uid = task.uid.isEmpty ? Uids.newUid() : task.uid;
    final existing = await findByUid(uid);
    final localId = existing?.id ?? _nextId;
    if (localId >= _nextId) _nextId = localId + 1;

    final stored = task.copyWith(
      id: localId,
      uid: uid,
      tags: List.unmodifiable(task.tags),
    );
    _tasks[localId] = stored;
    _tags[localId] = List.of(task.tags);
    return stored;
  }

  @override
  Future<void> setDependencies(List<TaskLink> links) async {
    _dependencies
      ..clear()
      ..addAll(links);
  }

  @override
  Future<void> addDependency(int taskId, int dependsOnId) async {
    if (taskId == dependsOnId) {
      throw ArgumentError('A task cannot block itself.');
    }
    if (!_tasks.containsKey(taskId) || !_tasks.containsKey(dependsOnId)) {
      throw ArgumentError(
        'Both tasks must exist to link $taskId → $dependsOnId.',
      );
    }

    final link = TaskLink(taskId, dependsOnId);
    if (!_dependencies.contains(link)) _dependencies.add(link);
  }

  @override
  Future<List<TaskLink>> listDependencies() async =>
      List.unmodifiable(_dependencies);

  @override
  Future<void> removeDependenciesFor(int taskId) async {
    _dependencies.removeWhere(
      (link) => link.taskId == taskId || link.dependsOnId == taskId,
    );
  }

  @override
  Future<List<String>> getTags(int taskId) async =>
      List.unmodifiable(_tags[taskId] ?? const []);

  @override
  Future<void> pushUndo(UndoSnapshot snapshot, {required int maxDepth}) async {
    _undo.add(snapshot);
    while (_undo.length > maxDepth) {
      _undo.removeAt(0);
    }
  }

  @override
  Future<UndoResult> undo() async {
    if (_undo.isEmpty) {
      throw StateError('Nothing to undo.');
    }

    final snapshot = _undo.removeLast();

    // Same order as the .NET store: wipe (when the snapshot covers the whole store), drop
    // whatever the operation created, restore the touched tasks, then relink their edges.
    if (snapshot.replaceAll) {
      for (final id in _tasks.keys.toList()) {
        await remove(id);
      }
    }

    for (final createdId in snapshot.createdTaskIds) {
      await remove(createdId);
    }

    for (final task in snapshot.tasks) {
      _tasks[task.id] = task;
      _tags[task.id] = List.of(snapshot.tags[task.id] ?? task.tags);
      if (task.id >= _nextId) _nextId = task.id + 1;
    }

    final touchedIds = {
      ...snapshot.tasks.map((task) => task.id),
      ...snapshot.createdTaskIds,
    };
    _dependencies.removeWhere(
      (link) =>
          touchedIds.contains(link.taskId) ||
          touchedIds.contains(link.dependsOnId),
    );
    for (final link in snapshot.dependencies) {
      if (!_dependencies.contains(link)) _dependencies.add(link);
    }

    return UndoResult(
      snapshot.operation,
      snapshot.tasks.length + snapshot.createdTaskIds.length,
    );
  }
}
