/// taqvim — see doc/taqvim.md and AGENTS.md
library;

abstract final class TaqvimDefaults {
  /// Maximum characters in an event title.
  static const int maxTitleLength = 150;

  /// Maximum characters in a location.
  static const int maxLocationLength = 200;

  /// Maximum characters in event notes.
  static const int maxNotesLength = 10000;

  /// Maximum characters in the tag list of one event.
  static const int maxTagsLength = 400;

  /// Maximum characters in a single tag.
  static const int maxTagLength = 30;

  /// Maximum tags on one event.
  static const int maxTagsPerEvent = 12;

  /// Upper rail on stored events (the pad's own safety valve).
  static const int maxEvents = 10000;

  /// Maximum reminders on one event.
  static const int maxRemindersPerEvent = 8;

  /// Minutes before an event a reminder may fire at most (4 weeks).
  static const int maxReminderMinutes = 40320;

  /// Maximum interval between recurrences (e.g. "every 1000 weeks" is refused).
  static const int maxRecurrenceInterval = 1000;

  /// Maximum occurrences a counted recurrence may promise.
  static const int maxRecurrenceCount = 10000;

  /// How far ahead agendas may look at most (about a year).
  static const int maxAgendaDays = 370;

  /// How far in the future an event may be scheduled (years).
  static const int maxScheduleHorizonYears = 10;

  /// Default duration of a timed event with no explicit end.
  static const int defaultEventMinutes = 60;

  /// Default calendar name for events that do not name one.
  static const String defaultCalendar = 'Personal';

  /// Default free-slot window start (a named default, settable per call).
  static const String workingDayStart = '09:00';

  /// Default free-slot window end.
  static const String workingDayEnd = '17:00';

  /// Default minimum length of a free slot worth reporting (minutes).
  static const int defaultFreeSlotMinutes = 30;

  /// Upper rail for the free-slot minimum (half a day).
  static const int maxFreeSlotMinutes = 720;

  /// Maximum .ics file size accepted for import (4 MiB).
  static const int maxIcsBytes = 4 * 1024 * 1024;

  /// Maximum events a single .ics import may add.
  static const int maxIcsEvents = 2000;

  /// Maximum events embedded in one AI prompt.
  static const int maxAiEvents = 120;

  /// Maximum characters of one event's notes in an AI prompt.
  static const int maxAiNotesChars = 800;

  /// Maximum characters of an AI question.
  static const int maxAiQuestionChars = 400;

  /// Default depth of the undo stack.
  static const int undoDepth = 20;

  /// Default search result limit.
  static const int searchLimit = 20;

  /// Upper rail for the search limit.
  static const int searchLimitBound = 100;

  /// Persian month names (Farvardin … Esfand) for Jalali display.
  static const List<String> jalaliMonths = [
    'Farvardin',
    'Ordibehesht',
    'Khordad',
    'Tir',
    'Mordad',
    'Shahrivar',
    'Mehr',
    'Aban',
    'Azar',
    'Dey',
    'Bahman',
    'Esfand',
  ];

  /// Events tagged with this get the Anahita forecast on day views (customizable via options).
  static const String outdoorTag = 'outdoor';

  /// At most this many due Haft Khan tasks appear on a day view.
  static const int maxDueTasksOnAgenda = 8;

  /// English month names, indexed 1-12 (January first) — for natural-language capture.
  static const List<String> monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}

class TaqvimException implements Exception {
  const TaqvimException(this.message);

  /// Human-readable, culture-invariant reason.
  final String message;

  @override
  String toString() => 'TaqvimException: $message';
}
