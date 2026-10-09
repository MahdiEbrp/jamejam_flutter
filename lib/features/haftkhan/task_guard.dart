/// haftkhan — see doc/haftkhan.md and AGENTS.md
import '../../core/date_only.dart';
import '../../core/text_guard.dart';
import 'models.dart';

class HaftKhanOptions {
  const HaftKhanOptions({
    this.maxTitleLength = defaultMaxTitleLength,
    this.maxNotesLength = defaultMaxNotesLength,
    this.maxTasksInSummary = defaultMaxTasksInSummary,
    this.maxNotesInPrompt = defaultMaxNotesInPrompt,
    this.breakdownMinSubtasks = defaultBreakdownMinSubtasks,
    this.breakdownMaxSubtasks = defaultBreakdownMaxSubtasks,
    this.maxTagsPerTask = defaultMaxTagsPerTask,
    this.maxTagLength = defaultMaxTagLength,
    this.maxRecurrenceInterval = defaultMaxRecurrenceInterval,
    this.maxUndoDepth = defaultMaxUndoDepth,
    this.boardTasksPerColumn = defaultBoardTasksPerColumn,
    this.reviewFocusCount = defaultReviewFocusCount,
    this.maxImportTasks = defaultMaxImportTasks,
  });

  // ── Named defaults ──
  static const int defaultMaxTitleLength = 200;
  static const int defaultMaxNotesLength = 4000;
  static const int defaultMaxTasksInSummary = 30;
  static const int defaultMaxNotesInPrompt = 1000;
  static const int defaultBreakdownMinSubtasks = 3;
  static const int defaultBreakdownMaxSubtasks = 7;
  static const int defaultMaxTagsPerTask = 10;
  static const int defaultMaxTagLength = 32;
  static const int defaultMaxRecurrenceInterval = 365;
  static const int defaultMaxUndoDepth = 50;
  static const int defaultBoardTasksPerColumn = 10;
  static const int defaultReviewFocusCount = 3;
  static const int defaultMaxImportTasks = 1000;

  // ── Safety rails (the bounds of configuration itself) ──
  static const int maxTitleLengthBound = 10000;
  static const int maxNotesLengthBound = 100000;
  static const int maxTasksInSummaryBound = 1000;
  static const int maxNotesInPromptBound = 32000;
  static const int maxTagsPerTaskBound = 100;
  static const int maxTagLengthBound = 128;
  static const int maxRecurrenceIntervalBound = 3650;
  static const int maxUndoDepthBound = 1000;
  static const int boardTasksPerColumnBound = 100;
  static const int reviewFocusCountBound = 20;
  static const int maxImportTasksBound = 100000;

  /// Maximum allowed title length (input guard).
  final int maxTitleLength;

  /// Maximum allowed notes length (input guard).
  final int maxNotesLength;

  /// Maximum number of open tasks embedded in an AI summary prompt.
  final int maxTasksInSummary;

  /// Maximum notes length copied into AI prompts.
  final int maxNotesInPrompt;

  /// Minimum number of subtasks the AI is asked to produce.
  final int breakdownMinSubtasks;

  /// Maximum number of subtasks the AI is asked to produce.
  final int breakdownMaxSubtasks;

  /// Maximum tags per task.
  final int maxTagsPerTask;

  /// Maximum length of a single tag.
  final int maxTagLength;

  /// Maximum recurrence interval.
  final int maxRecurrenceInterval;

  /// Number of undo snapshots kept.
  final int maxUndoDepth;

  /// Tasks shown per kanban board column.
  final int boardTasksPerColumn;

  /// Focus items listed in the weekly review.
  final int reviewFocusCount;

  /// Maximum tasks accepted by one import.
  final int maxImportTasks;

  /// Validates every value against its rail.
  ///
  /// Throws [RangeError] — the Dart counterpart of the .NET `ArgumentOutOfRangeException`
  /// this port replaced — so a bad limit fails at construction, never mid-operation.
  void validate() {
    void between(int value, int min, int max, String name) {
      if (value < min || value > max) {
        throw RangeError.range(value, min, max, name);
      }
    }

    between(maxTitleLength, 1, maxTitleLengthBound, 'MaxTitleLength');
    between(maxNotesLength, 1, maxNotesLengthBound, 'MaxNotesLength');
    between(maxTasksInSummary, 1, maxTasksInSummaryBound, 'MaxTasksInSummary');
    between(maxNotesInPrompt, 1, maxNotesInPromptBound, 'MaxNotesInPrompt');
    between(maxTagsPerTask, 1, maxTagsPerTaskBound, 'MaxTagsPerTask');
    between(maxTagLength, 1, maxTagLengthBound, 'MaxTagLength');
    between(
      maxRecurrenceInterval,
      1,
      maxRecurrenceIntervalBound,
      'MaxRecurrenceInterval',
    );
    between(maxUndoDepth, 1, maxUndoDepthBound, 'MaxUndoDepth');
    between(
      boardTasksPerColumn,
      1,
      boardTasksPerColumnBound,
      'BoardTasksPerColumn',
    );
    between(reviewFocusCount, 1, reviewFocusCountBound, 'ReviewFocusCount');
    between(maxImportTasks, 1, maxImportTasksBound, 'MaxImportTasks');

    if (breakdownMinSubtasks < 1) {
      throw RangeError.range(
        breakdownMinSubtasks,
        1,
        null,
        'BreakdownMinSubtasks',
      );
    }
    if (breakdownMaxSubtasks < breakdownMinSubtasks) {
      throw RangeError.range(
        breakdownMaxSubtasks,
        breakdownMinSubtasks,
        null,
        'BreakdownMaxSubtasks',
      );
    }
  }
}

abstract final class TaskGuard {
  /// Sanitizes and validates a task title (required, control-char free, bounded).
  static String cleanTitle(
    String? title, [
    int maxLength = HaftKhanOptions.defaultMaxTitleLength,
  ]) => TextGuard.sanitizeRequired(title, maxLength, 'title');

  /// Sanitizes optional notes (control-char free, bounded; whitespace-only becomes empty).
  static String cleanNotes(
    String? notes, [
    int maxLength = HaftKhanOptions.defaultMaxNotesLength,
  ]) => TextGuard.sanitizeOptional(notes, maxLength, 'notes');

  /// Sanitizes an optional project name (single line, bounded).
  static String cleanProject(
    String? project, [
    int maxLength = HaftKhanOptions.defaultMaxTitleLength,
  ]) {
    return TextGuard.sanitizeOptional(
      project,
      maxLength,
      'project',
    ).replaceAll('\r', '').replaceAll('\n', ' ').trim();
  }

  /// Sanitizes a comma-separated tag list: trims each tag, drops empties, de-duplicates
  /// case-insensitively, and enforces count and length limits.
  static List<String> cleanTags(
    String? csv, {
    int maxTags = HaftKhanOptions.defaultMaxTagsPerTask,
    int maxTagLength = HaftKhanOptions.defaultMaxTagLength,
  }) {
    if (maxTags < 1) {
      throw ArgumentError.value(maxTags, 'maxTags', 'must be at least 1');
    }
    if (maxTagLength < 1) {
      throw ArgumentError.value(
        maxTagLength,
        'maxTagLength',
        'must be at least 1',
      );
    }
    if (csv == null || csv.trim().isEmpty) return const [];

    final tags = <String>[];
    for (final raw in csv.split(',')) {
      final tag = TextGuard.sanitizeRequired(raw, maxTagLength, 'tags');
      if (tags.any((existing) => existing.toLowerCase() == tag.toLowerCase())) {
        continue;
      }
      tags.add(tag);
      if (tags.length > maxTags) {
        throw ArgumentError.value(
          csv,
          'tags',
          'a task can have at most $maxTags tags',
        );
      }
    }
    return tags;
  }

  /// Parses a priority name (case-insensitive). Null defaults to [TaskPriority.normal].
  static TaskPriority parsePriority(String? name) {
    if (name == null || name.trim().isEmpty) return TaskPriority.normal;
    return switch (name.trim().toLowerCase()) {
      'low' => TaskPriority.low,
      'normal' => TaskPriority.normal,
      'high' => TaskPriority.high,
      'critical' => TaskPriority.critical,
      _ => throw ArgumentError.value(
        name,
        'priority',
        'unknown priority; use low, normal, high, or critical',
      ),
    };
  }

  /// Parses an effort estimate (case-insensitive). Null defaults to [TaskEffort.none].
  static TaskEffort parseEffort(String? name) {
    if (name == null || name.trim().isEmpty) return TaskEffort.none;
    return switch (name.trim().toLowerCase()) {
      'none' => TaskEffort.none,
      's' || 'small' => TaskEffort.small,
      'm' || 'medium' => TaskEffort.medium,
      'l' || 'large' => TaskEffort.large,
      'xl' || 'xlarge' => TaskEffort.xLarge,
      _ => throw ArgumentError.value(
        name,
        'effort',
        'unknown effort; use none, s, m, l, xl',
      ),
    };
  }

  /// Parses a recurrence kind (case-insensitive). Null defaults to [RecurrenceKind.none].
  static RecurrenceKind parseRecurrenceKind(String? name) {
    if (name == null || name.trim().isEmpty) return RecurrenceKind.none;
    return switch (name.trim().toLowerCase()) {
      'none' => RecurrenceKind.none,
      'daily' || 'day' => RecurrenceKind.daily,
      'weekly' || 'week' => RecurrenceKind.weekly,
      'monthly' || 'month' => RecurrenceKind.monthly,
      _ => throw ArgumentError.value(
        name,
        'recurrence',
        'unknown recurrence; use none, daily, weekly, or monthly',
      ),
    };
  }

  /// Parses a recurrence interval (default 1, bounded).
  static int parseRecurrenceInterval(
    String? text, [
    int maxInterval = HaftKhanOptions.defaultMaxRecurrenceInterval,
  ]) {
    if (text == null || text.trim().isEmpty) return 1;
    final interval = int.tryParse(text.trim());
    if (interval == null || interval < 1 || interval > maxInterval) {
      throw ArgumentError.value(
        text,
        'interval',
        'invalid interval; use a number between 1 and $maxInterval',
      );
    }
    return interval;
  }

  /// Parses a due date: strict ISO `yyyy-MM-dd` or natural language relative to [today].
  ///
  /// Supported natural forms: `today`/`tod`, `tomorrow`/`tmr`, `next week`,
  /// `next <weekday>` (always strictly in the future), `in N day(s)/week(s)/month(s)`,
  /// and a bare weekday (today when it matches, otherwise the next occurrence).
  static DateOnly? parseDueDate(String? text, DateOnly today) {
    if (text == null || text.trim().isEmpty) return null;
    final input = text.trim();

    try {
      return DateOnly.parseIso(input);
    } on FormatException {
      // fall through to natural language
    }

    final natural = _parseNaturalDate(input.toLowerCase(), today);
    if (natural == null) {
      throw ArgumentError.value(
        text,
        'dueDate',
        "invalid date; use yyyy-MM-dd or natural language like 'tomorrow', "
            "'next monday', 'in 3 days'",
      );
    }
    return natural;
  }

  /// Parses a task id typed by the user.
  static int parseId(String? text) {
    final id = int.tryParse((text ?? '').trim());
    if (id == null || id <= 0) {
      throw ArgumentError.value(
        text,
        'id',
        'invalid task id; use a positive number',
      );
    }
    return id;
  }

  /// Parses a comma-separated list of ids (deduplicated, order preserved).
  static List<int> parseIdList(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    final ids = <int>[];
    for (final part in text.split(',')) {
      final id = parseId(part);
      if (!ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  /// Parses a list-view name (case-insensitive). Null defaults to [TaskView.open].
  static TaskView parseView(String? name) {
    if (name == null || name.trim().isEmpty) return TaskView.open;
    return switch (name.trim().toLowerCase()) {
      'open' => TaskView.open,
      'all' => TaskView.all,
      'done' => TaskView.done,
      'today' => TaskView.today,
      'overdue' => TaskView.overdue,
      _ => throw ArgumentError.value(
        name,
        'view',
        'unknown view; use open, all, done, today, or overdue',
      ),
    };
  }

  static DateOnly? _parseNaturalDate(String input, DateOnly today) {
    if (input == 'today' || input == 'tod') return today;
    if (input == 'tomorrow' || input == 'tmr') return today.addDays(1);
    if (input == 'next week') return today.addDays(7);

    if (input.startsWith('in ')) {
      final parts = input
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.length == 3) {
        final amount = int.tryParse(parts[1]);
        if (amount != null && amount >= 1) {
          return switch (parts[2]) {
            'day' || 'days' => today.addDays(amount),
            'week' || 'weeks' => today.addDays(7 * amount),
            'month' || 'months' => today.addMonths(amount),
            _ => null,
          };
        }
      }
      return null;
    }

    final strictlyFuture = input.startsWith('next ');
    final weekdayText = strictlyFuture ? input.substring(5) : input;
    final weekday = switch (weekdayText.trim()) {
      'monday' || 'mon' => DateTime.monday,
      'tuesday' || 'tue' => DateTime.tuesday,
      'wednesday' || 'wed' => DateTime.wednesday,
      'thursday' || 'thu' => DateTime.thursday,
      'friday' || 'fri' => DateTime.friday,
      'saturday' || 'sat' => DateTime.saturday,
      'sunday' || 'sun' => DateTime.sunday,
      _ => null,
    };

    return weekday == null
        ? null
        : _nextWeekday(today, weekday, strictlyFuture);
  }

  static DateOnly _nextWeekday(
    DateOnly today,
    int target,
    bool strictlyFuture,
  ) {
    var daysAhead = (target - today.weekday + 7) % 7;
    if (daysAhead == 0 && strictlyFuture) daysAhead = 7;
    return today.addDays(daysAhead);
  }
}
