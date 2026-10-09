/// haftkhan — see doc/haftkhan.md and AGENTS.md
import '../../core/date_only.dart';

enum TaskState {
  /// Not started yet.
  todo(0, 'todo'),

  /// In progress.
  doing(1, 'doing'),

  /// Conquered.
  done(2, 'done');

  const TaskState(this.code, this.name);

  /// Stable integer used by the database and the backup format.
  final int code;

  /// Canonical lowercase name.
  final String name;

  static TaskState fromCode(int code) => values.firstWhere(
    (state) => state.code == code,
    orElse: () => throw ArgumentError('Unknown task state code $code.'),
  );
}

enum TaskPriority {
  low(0, 'low'),
  normal(1, 'normal'),
  high(2, 'high'),
  critical(3, 'critical');

  const TaskPriority(this.code, this.name);

  /// Stable integer used by the database and the backup format.
  final int code;

  /// Canonical lowercase name.
  final String name;

  static TaskPriority fromCode(int code) => values.firstWhere(
    (priority) => priority.code == code,
    orElse: () => throw ArgumentError('Unknown task priority code $code.'),
  );
}

enum TaskEffort {
  none(0, 'none', 'none'),
  small(1, 's', 'small'),
  medium(2, 'm', 'medium'),
  large(3, 'l', 'large'),
  xLarge(4, 'xl', 'xlarge');

  const TaskEffort(this.code, this.name, this.canonical);

  /// Stable integer used by the database and the backup format.
  final int code;

  /// Canonical short name, as typed on the command line.
  final String name;

  /// The long, culture-invariant name (`.NET` enum name, lowercased) used by exports.
  final String canonical;

  static TaskEffort fromCode(int code) => values.firstWhere(
    (effort) => effort.code == code,
    orElse: () => throw ArgumentError('Unknown task effort code $code.'),
  );
}

enum RecurrenceKind {
  none(0, 'none', 'none'),
  daily(1, 'daily', 'daily'),
  weekly(2, 'weekly', 'weekly'),
  monthly(3, 'monthly', 'monthly');

  const RecurrenceKind(this.code, this.name, this.canonical);

  /// Stable integer used by the database and the backup format.
  final int code;

  /// Canonical short name, as typed on the command line.
  final String name;

  /// The long, culture-invariant name (`.NET` enum name, lowercased) used by exports.
  final String canonical;

  /// True when completing the task spawns a successor.
  bool get isRecurring => this != RecurrenceKind.none;

  static RecurrenceKind fromCode(int code) => values.firstWhere(
    (kind) => kind.code == code,
    orElse: () => throw ArgumentError('Unknown recurrence code $code.'),
  );
}

enum TaskView {
  /// Open tasks (to-do and doing) — the default view.
  open,

  /// Every task, done or not.
  all,

  /// Only conquered tasks.
  done,

  /// Open tasks due today.
  today,

  /// Open tasks past their due date.
  overdue,
}

class HaftKhanTask {
  const HaftKhanTask({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.priority = TaskPriority.normal,
    this.state = TaskState.todo,
    this.dueDate,
    this.completedAt,
    this.startedAt,
    this.project = '',
    this.tags = const [],
    this.effort = TaskEffort.none,
    this.recurrence = RecurrenceKind.none,
    this.recurrenceInterval = 1,
    this.uid = '',
  });

  /// Stable identifier used by the UI and storage.
  final int id;

  /// What has to be done (sanitized, non-empty).
  final String title;

  /// Optional details (sanitized; empty when absent).
  final String notes;

  /// Importance; higher sorts first.
  final TaskPriority priority;

  /// Lifecycle state.
  final TaskState state;

  /// Optional due date (day precision).
  final DateOnly? dueDate;

  /// When the task was created (UTC).
  final DateTime createdAt;

  /// When the task was last modified (UTC).
  final DateTime updatedAt;

  /// When the task was completed (UTC); null while open.
  final DateTime? completedAt;

  /// When the task was last started (UTC); null if never started.
  final DateTime? startedAt;

  /// Project the task belongs to (empty = none).
  final String project;

  /// Tags attached to the task (never null).
  final List<String> tags;

  /// Estimated effort.
  final TaskEffort effort;

  /// Recurrence schedule (none = one-off).
  final RecurrenceKind recurrence;

  /// Recurrence interval (every N days/weeks/months).
  final int recurrenceInterval;

  /// Stable identity used for syncing across devices — generated at creation and preserved
  /// by export/import. Local ids are device-only.
  final String uid;

  /// True while the task is still open (to-do or doing).
  bool get isOpen => state != TaskState.done;

  /// True for tasks that repeat.
  bool get isRecurring => recurrence.isRecurring;

  /// Copies the task with the given fields replaced.
  HaftKhanTask copyWith({
    int? id,
    String? title,
    String? notes,
    TaskPriority? priority,
    TaskState? state,
    DateOnly? dueDate,
    bool clearDueDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? startedAt,
    String? project,
    List<String>? tags,
    TaskEffort? effort,
    RecurrenceKind? recurrence,
    int? recurrenceInterval,
    String? uid,
  }) {
    return HaftKhanTask(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      state: state ?? this.state,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      startedAt: startedAt ?? this.startedAt,
      project: project ?? this.project,
      tags: tags ?? this.tags,
      effort: effort ?? this.effort,
      recurrence: recurrence ?? this.recurrence,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      uid: uid ?? this.uid,
    );
  }

  @override
  String toString() => 'HaftKhanTask(#$id "$title" ${state.name})';
}

class NewTask {
  const NewTask({
    required this.title,
    this.notes = '',
    this.priority = TaskPriority.normal,
    this.dueDate,
    this.project = '',
    this.tags = const [],
    this.effort = TaskEffort.none,
    this.recurrence = RecurrenceKind.none,
    this.recurrenceInterval = 1,
    this.blockedBy = const [],
    this.uid,
  });

  /// What has to be done (already sanitized).
  final String title;

  /// Optional details (already sanitized).
  final String notes;

  /// Importance.
  final TaskPriority priority;

  /// Optional due date.
  final DateOnly? dueDate;

  /// Project the task belongs to (empty = none).
  final String project;

  /// Tags to attach (already sanitized).
  final List<String> tags;

  /// Estimated effort.
  final TaskEffort effort;

  /// Recurrence schedule.
  final RecurrenceKind recurrence;

  /// Recurrence interval.
  final int recurrenceInterval;

  /// Ids of tasks this one is blocked by (must exist when created).
  final List<int> blockedBy;

  /// Stable sync identity; generated by the store when null or empty.
  final String? uid;
}

class TaskLink {
  const TaskLink(this.taskId, this.dependsOnId);

  /// The blocked task.
  final int taskId;

  /// The blocker.
  final int dependsOnId;

  @override
  bool operator ==(Object other) =>
      other is TaskLink &&
      other.taskId == taskId &&
      other.dependsOnId == dependsOnId;

  @override
  int get hashCode => Object.hash(taskId, dependsOnId);

  @override
  String toString() => 'TaskLink($taskId → $dependsOnId)';
}

class TaskCounts {
  const TaskCounts({
    required this.todo,
    required this.doing,
    required this.done,
    required this.overdue,
  });

  final int todo;
  final int doing;
  final int done;
  final int overdue;

  /// Every task regardless of state.
  int get total => todo + doing + done;
}

class UndoSnapshot {
  const UndoSnapshot({
    required this.operation,
    required this.tasks,
    required this.tags,
    required this.dependencies,
    required this.createdTaskIds,
    required this.replaceAll,
  });

  /// Name of the operation that is about to run (e.g. "done", "remove").
  final String operation;

  /// Prior-state tasks (empty when the operation introduced brand-new tasks only).
  final List<HaftKhanTask> tasks;

  /// Prior tags per task id.
  final Map<int, List<String>> tags;

  /// Prior dependency edges touching the affected tasks.
  final List<TaskLink> dependencies;

  /// Ids created by the operation — undo deletes these.
  final List<int> createdTaskIds;

  /// When true, undo first wipes the store, then restores the snapshot.
  final bool replaceAll;
}

class UndoResult {
  const UndoResult(this.operation, this.restoredTasks);

  /// The reverted operation.
  final String operation;

  /// How many tasks were restored to their prior state.
  final int restoredTasks;
}

class CompleteResult {
  const CompleteResult(this.completed, this.next);

  /// The completed task.
  final HaftKhanTask completed;

  /// The freshly spawned next occurrence, or null for one-off tasks.
  final HaftKhanTask? next;
}

class ProductivityReport {
  const ProductivityReport({
    required this.todo,
    required this.doing,
    required this.done,
    required this.overdue,
    required this.doneToday,
    required this.doneLast7Days,
    required this.currentStreak,
    required this.bestStreak,
    required this.focus,
  });

  final int todo;
  final int doing;
  final int done;
  final int overdue;
  final int doneToday;
  final int doneLast7Days;
  final int currentStreak;
  final int bestStreak;

  /// Top unblocked open tasks to tackle next.
  final List<HaftKhanTask> focus;
}

class BoardColumn {
  const BoardColumn(this.title, this.tasks);

  /// Column heading (e.g. "TODO").
  final String title;

  /// Tasks in the column (already capped for display).
  final List<HaftKhanTask> tasks;
}

class MatrixQuadrant {
  const MatrixQuadrant(this.title, this.tasks);

  /// Quadrant heading (e.g. "DO NOW — urgent + important").
  final String title;

  /// Tasks in the quadrant.
  final List<HaftKhanTask> tasks;
}

class TaskNotFoundException implements Exception {
  const TaskNotFoundException(this.id);

  /// The missing task's id.
  final int id;

  @override
  String toString() => 'Task $id was not found.';
}
