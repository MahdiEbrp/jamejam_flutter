/// haftkhan — see doc/haftkhan.md and AGENTS.md
import '../../core/date_only.dart';
import 'models.dart';

abstract final class Recurrence {
  /// Computes the due date of the next occurrence.
  ///
  /// [currentDue] is the completed occurrence's due date (null falls back to [completedOn],
  /// the day it was completed), and completed month arithmetic clamps to the target month's
  /// length — `Jan 31 + 1 month = Feb 28`.
  ///
  /// Throws [ArgumentError] for an interval below 1 or a non-recurring kind.
  static DateOnly nextDue(
    RecurrenceKind kind,
    int interval,
    DateOnly? currentDue,
    DateOnly completedOn,
  ) {
    if (interval < 1) {
      throw ArgumentError.value(interval, 'interval', 'must be at least 1');
    }

    final baseDate = currentDue ?? completedOn;
    return switch (kind) {
      RecurrenceKind.daily => baseDate.addDays(interval),
      RecurrenceKind.weekly => baseDate.addDays(7 * interval),
      RecurrenceKind.monthly => baseDate.addMonths(interval),
      RecurrenceKind.none => throw ArgumentError.value(
        kind,
        'kind',
        'task is not recurring',
      ),
    };
  }
}
