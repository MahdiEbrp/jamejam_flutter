/// taqvim — see doc/taqvim.md and AGENTS.md
library;

import 'taqvim_defaults.dart';

class TaqvimOptions {
  const TaqvimOptions({
    this.maxTitleLength = TaqvimDefaults.maxTitleLength,
    this.maxNotesLength = TaqvimDefaults.maxNotesLength,
    this.maxEvents = TaqvimDefaults.maxEvents,
    this.maxRemindersPerEvent = TaqvimDefaults.maxRemindersPerEvent,
    this.maxAgendaDays = TaqvimDefaults.maxAgendaDays,
    this.maxScheduleHorizonYears = TaqvimDefaults.maxScheduleHorizonYears,
    this.undoDepth = TaqvimDefaults.undoDepth,
    this.searchLimit = TaqvimDefaults.searchLimit,
    this.maxAiEvents = TaqvimDefaults.maxAiEvents,
    this.outdoorTag = TaqvimDefaults.outdoorTag,
  });

  /// Maximum characters in an event title.
  final int maxTitleLength;

  /// Maximum characters in event notes.
  final int maxNotesLength;

  /// Upper rail on stored events.
  final int maxEvents;

  /// Maximum reminders on one event.
  final int maxRemindersPerEvent;

  /// How far ahead agendas may look, in days.
  final int maxAgendaDays;

  /// How far in the future an event may be scheduled, in years.
  final int maxScheduleHorizonYears;

  /// Undo stack depth.
  final int undoDepth;

  /// Search result limit.
  final int searchLimit;

  /// Maximum events embedded in one AI prompt.
  final int maxAiEvents;

  /// Tag whose events get the weather forecast on a day view.
  final String outdoorTag;

  TaqvimOptions copyWith({
    int? maxTitleLength,
    int? maxNotesLength,
    int? maxEvents,
    int? maxRemindersPerEvent,
    int? maxAgendaDays,
    int? maxScheduleHorizonYears,
    int? undoDepth,
    int? searchLimit,
    int? maxAiEvents,
    String? outdoorTag,
  }) => TaqvimOptions(
    maxTitleLength: maxTitleLength ?? this.maxTitleLength,
    maxNotesLength: maxNotesLength ?? this.maxNotesLength,
    maxEvents: maxEvents ?? this.maxEvents,
    maxRemindersPerEvent: maxRemindersPerEvent ?? this.maxRemindersPerEvent,
    maxAgendaDays: maxAgendaDays ?? this.maxAgendaDays,
    maxScheduleHorizonYears:
        maxScheduleHorizonYears ?? this.maxScheduleHorizonYears,
    undoDepth: undoDepth ?? this.undoDepth,
    searchLimit: searchLimit ?? this.searchLimit,
    maxAiEvents: maxAiEvents ?? this.maxAiEvents,
    outdoorTag: outdoorTag ?? this.outdoorTag,
  );

  /// Validates every value against its named rail; throws [TaqvimException].
  ///
  /// The .NET checked `MaxRemindersPerEvent` and `UndoDepth` twice each (the later check is
  /// the stricter one), so the *effective* rails are reminders `1…8` and undo `0…20`. The
  /// messages of the later checks are the ones a caller ever sees; both are preserved.
  void validate() {
    if (maxTitleLength < 1 || maxTitleLength > TaqvimDefaults.maxTitleLength) {
      throw TaqvimException(
        'MaxTitleLength must be between 1 and ${TaqvimDefaults.maxTitleLength}.',
      );
    }

    if (maxNotesLength < 1 || maxNotesLength > TaqvimDefaults.maxNotesLength) {
      throw TaqvimException(
        'MaxNotesLength must be between 1 and ${TaqvimDefaults.maxNotesLength}.',
      );
    }

    if (maxEvents < 1 || maxEvents > TaqvimDefaults.maxEvents) {
      throw TaqvimException(
        'MaxEvents must be between 1 and ${TaqvimDefaults.maxEvents}.',
      );
    }

    if (maxRemindersPerEvent < 0 ||
        maxRemindersPerEvent > TaqvimDefaults.maxRemindersPerEvent) {
      throw TaqvimException(
        'MaxRemindersPerEvent must be between 0 and '
        '${TaqvimDefaults.maxRemindersPerEvent}.',
      );
    }

    if (maxAgendaDays < 1 || maxAgendaDays > TaqvimDefaults.maxAgendaDays) {
      throw TaqvimException(
        'MaxAgendaDays must be between 1 and ${TaqvimDefaults.maxAgendaDays}.',
      );
    }

    if (maxScheduleHorizonYears < 1 ||
        maxScheduleHorizonYears > TaqvimDefaults.maxScheduleHorizonYears) {
      throw TaqvimException(
        'MaxScheduleHorizonYears must be between 1 and '
        '${TaqvimDefaults.maxScheduleHorizonYears}.',
      );
    }

    if (undoDepth < 0 || undoDepth > 100) {
      throw const TaqvimException('UndoDepth must be between 0 and 100.');
    }

    if (maxRemindersPerEvent < 1 ||
        maxRemindersPerEvent > TaqvimDefaults.maxRemindersPerEvent) {
      throw TaqvimException(
        'MaxRemindersPerEvent must be between 1 and '
        '${TaqvimDefaults.maxRemindersPerEvent}.',
      );
    }

    if (undoDepth < 0 || undoDepth > TaqvimDefaults.undoDepth) {
      throw TaqvimException(
        'UndoDepth must be between 0 and ${TaqvimDefaults.undoDepth}.',
      );
    }

    if (outdoorTag.length > TaqvimDefaults.maxTagLength) {
      throw TaqvimException(
        'OutdoorTag may be at most ${TaqvimDefaults.maxTagLength} characters.',
      );
    }

    if (searchLimit < 1 || searchLimit > TaqvimDefaults.searchLimitBound) {
      throw TaqvimException(
        'SearchLimit must be between 1 and ${TaqvimDefaults.searchLimitBound}.',
      );
    }

    if (maxAiEvents < 1 || maxAiEvents > TaqvimDefaults.maxAiEvents) {
      throw TaqvimException(
        'MaxAiEvents must be between 1 and ${TaqvimDefaults.maxAiEvents}.',
      );
    }
  }

  /// Validates a custom instance (null = defaults) and returns it.
  static TaqvimOptions createValidated([TaqvimOptions? options]) {
    final effective = options ?? const TaqvimOptions();
    return effective..validate();
  }
}

abstract final class TaqvimParse {
  /// Parses a positive integer or fails with a friendly message.
  static int positiveInt(String text, String label) {
    final value = int.tryParse(text.trim());
    if (value == null || value <= 0) {
      throw TaqvimException('$label must be a positive number.');
    }
    return value;
  }
}
