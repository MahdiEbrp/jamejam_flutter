/// haftkhan — see doc/haftkhan.md and AGENTS.md
import 'dart:convert';

import '../../core/date_only.dart';
import '../../core/uids.dart';
import 'models.dart';

class TaskDto {
  const TaskDto({
    required this.id,
    required this.title,
    required this.notes,
    required this.priority,
    required this.state,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
    required this.project,
    required this.tags,
    required this.effort,
    required this.recurrence,
    required this.recurrenceInterval,
    required this.startedAt,
    this.uid,
  });

  final int id;
  final String title;
  final String notes;
  final int priority;
  final int state;
  final String? dueDate;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;
  final String project;
  final List<String> tags;
  final int effort;
  final int recurrence;
  final int recurrenceInterval;
  final String? startedAt;

  /// Stable sync identity (version-2 files; null in version-1 files).
  final String? uid;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'priority': priority,
    'state': state,
    'dueDate': dueDate,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'completedAt': completedAt,
    'project': project,
    'tags': tags,
    'effort': effort,
    'recurrence': recurrence,
    'recurrenceInterval': recurrenceInterval,
    'startedAt': startedAt,
    'uid': uid,
  };

  factory TaskDto.fromJson(Map<String, dynamic> json) => TaskDto(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    notes: (json['notes'] as String?) ?? '',
    priority: (json['priority'] as num).toInt(),
    state: (json['state'] as num).toInt(),
    dueDate: json['dueDate'] as String?,
    createdAt: json['createdAt'] as String,
    updatedAt: json['updatedAt'] as String,
    completedAt: json['completedAt'] as String?,
    project: (json['project'] as String?) ?? '',
    tags: ((json['tags'] as List?) ?? const []).cast<String>(),
    effort: (json['effort'] as num?)?.toInt() ?? 0,
    recurrence: (json['recurrence'] as num?)?.toInt() ?? 0,
    recurrenceInterval: (json['recurrenceInterval'] as num?)?.toInt() ?? 1,
    startedAt: json['startedAt'] as String?,
    uid: json['uid'] as String?,
  );
}

class DependencyDto {
  const DependencyDto({
    required this.taskId,
    required this.dependsOnId,
    this.taskUid,
    this.dependsOnUid,
  });

  final int taskId;
  final int dependsOnId;

  /// The blocked task's stable uid (version-2 files).
  final String? taskUid;

  /// The blocker's stable uid (version-2 files).
  final String? dependsOnUid;

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'dependsOnId': dependsOnId,
    'taskUid': taskUid,
    'dependsOnUid': dependsOnUid,
  };

  factory DependencyDto.fromJson(Map<String, dynamic> json) => DependencyDto(
    taskId: (json['taskId'] as num).toInt(),
    dependsOnId: (json['dependsOnId'] as num).toInt(),
    taskUid: json['taskUid'] as String?,
    dependsOnUid: json['dependsOnUid'] as String?,
  );
}

class BackupFile {
  const BackupFile({
    required this.version,
    required this.exportedAt,
    required this.tasks,
    required this.dependencies,
  });

  final int version;
  final String exportedAt;
  final List<TaskDto> tasks;
  final List<DependencyDto> dependencies;

  Map<String, dynamic> toJson() => {
    'version': version,
    'exportedAt': exportedAt,
    'tasks': tasks.map((task) => task.toJson()).toList(),
    'dependencies': dependencies.map((link) => link.toJson()).toList(),
  };

  factory BackupFile.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt();
    if (version == null) {
      throw const FormatException('The backup is missing its version field.');
    }
    if (version < Backup.oldestSupportedVersion ||
        version > Backup.currentVersion) {
      throw FormatException(
        'Unsupported backup version $version '
        '(this build reads ${Backup.oldestSupportedVersion}–${Backup.currentVersion}).',
      );
    }

    final rawTasks = json['tasks'];
    final rawDependencies = json['dependencies'];
    if (rawTasks != null && rawTasks is! List) {
      throw const FormatException('The backup tasks field must be a list.');
    }
    if (rawDependencies != null && rawDependencies is! List) {
      throw const FormatException(
        'The backup dependencies field must be a list.',
      );
    }

    return BackupFile(
      version: version,
      exportedAt: (json['exportedAt'] as String?) ?? '',
      tasks: ((json['tasks'] as List?) ?? const [])
          .map(
            (task) => TaskDto.fromJson((task as Map).cast<String, dynamic>()),
          )
          .toList(),
      dependencies: ((json['dependencies'] as List?) ?? const [])
          .map(
            (link) =>
                DependencyDto.fromJson((link as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

abstract final class Backup {
  /// Current backup schema version.
  static const int currentVersion = 2;

  /// Oldest backup schema version this build accepts.
  static const int oldestSupportedVersion = 1;

  /// Converts a task to its serializable form.
  static TaskDto toDto(HaftKhanTask task) => TaskDto(
    id: task.id,
    title: task.title,
    notes: task.notes,
    priority: task.priority.code,
    state: task.state.code,
    dueDate: task.dueDate?.toIso(),
    createdAt: task.createdAt.toUtc().toIso8601String(),
    updatedAt: task.updatedAt.toUtc().toIso8601String(),
    completedAt: task.completedAt?.toUtc().toIso8601String(),
    project: task.project,
    tags: task.tags,
    effort: task.effort.code,
    recurrence: task.recurrence.code,
    recurrenceInterval: task.recurrenceInterval,
    startedAt: task.startedAt?.toUtc().toIso8601String(),
    uid: task.uid.isEmpty ? null : task.uid,
  );

  /// Rebuilds a task from its serialized form, validating every enum.
  ///
  /// Version-1 files carry no `uid`, so one is minted here — imported tasks must still be
  /// addressable by sync afterwards.
  static HaftKhanTask fromDto(TaskDto dto) => HaftKhanTask(
    id: dto.id,
    title: dto.title,
    notes: dto.notes,
    priority: TaskPriority.fromCode(dto.priority),
    state: TaskState.fromCode(dto.state),
    dueDate: dto.dueDate == null || dto.dueDate!.isEmpty
        ? null
        : DateOnly.parseIso(dto.dueDate!),
    createdAt: DateTime.parse(dto.createdAt).toUtc(),
    updatedAt: DateTime.parse(dto.updatedAt).toUtc(),
    completedAt: dto.completedAt == null
        ? null
        : DateTime.parse(dto.completedAt!).toUtc(),
    startedAt: dto.startedAt == null
        ? null
        : DateTime.parse(dto.startedAt!).toUtc(),
    project: dto.project,
    tags: dto.tags,
    effort: TaskEffort.fromCode(dto.effort),
    recurrence: RecurrenceKind.fromCode(dto.recurrence),
    recurrenceInterval: dto.recurrenceInterval,
    uid: (dto.uid == null || dto.uid!.isEmpty) ? Uids.newUid() : dto.uid!,
  );

  /// Serializes a backup to indented JSON.
  static String toJson(BackupFile backup) =>
      const JsonEncoder.withIndent('  ').convert(backup.toJson());

  /// Parses a backup document.
  ///
  /// Throws [FormatException] for anything malformed — the caller wraps it in a
  /// human-readable message rather than letting a raw parse error reach the UI.
  static BackupFile fromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('The backup must be a JSON object.');
    }
    return BackupFile.fromJson(decoded.cast<String, dynamic>());
  }

  /// Serializes tasks to a human-readable Markdown checklist.
  ///
  /// The line shape is byte-compatible with the .NET tool's `ToMarkdown`, because people
  /// paste these files into issue trackers and notes apps:
  ///
  /// ```
  /// - [x] Slay the dragon  (due: 2026-09-25, project: labours, #myth #hero, effort: large) — notes
  /// ```
  static String toMarkdown(List<HaftKhanTask> tasks, DateOnly today) {
    final lines = <String>['# Haft Khan export', ''];

    for (final task in tasks) {
      final checkbox = task.state == TaskState.done ? 'x' : ' ';
      final bits = <String>[];

      final due = task.dueDate;
      if (due != null) {
        bits.add(
          due < today ? 'overdue: ${due.toIso()}' : 'due: ${due.toIso()}',
        );
      }
      if (task.project.isNotEmpty) {
        bits.add('project: ${task.project}');
      }
      if (task.tags.isNotEmpty) {
        bits.add(task.tags.map((tag) => '#$tag').join(' '));
      }
      if (task.effort != TaskEffort.none) {
        bits.add('effort: ${task.effort.canonical}');
      }
      if (task.recurrence != RecurrenceKind.none) {
        bits.add(
          'every: ${task.recurrenceInterval} ${task.recurrence.canonical}',
        );
      }

      final suffix = bits.isEmpty ? '' : '  (${bits.join(', ')})';
      final notes = task.notes.isEmpty
          ? ''
          : ' — ${task.notes.replaceAll('\n', ' ')}';
      lines.add('- [$checkbox] ${task.title}$suffix$notes');
    }

    return '${lines.join('\n')}\n';
  }
}
