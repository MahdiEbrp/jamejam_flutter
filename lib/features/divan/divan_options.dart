/// divan — see doc/divan.md and AGENTS.md
import 'divan_defaults.dart';

class DivanOptions {
  const DivanOptions({
    this.undoDepth = DivanDefaults.undoDepth,
    this.searchLimit = DivanDefaults.searchLimit,
    this.readingWordsPerMinute = DivanDefaults.readingWordsPerMinute,
    this.maxAiBodyChars = DivanDefaults.maxAiBodyChars,
  });

  /// How many undo snapshots are kept.
  final int undoDepth;

  /// Maximum search results returned.
  final int searchLimit;

  /// Reading speed for the reading-time estimate.
  final int readingWordsPerMinute;

  /// Longest note body clipped into an AI prompt.
  final int maxAiBodyChars;

  /// Reads the rails from the environment (`JAMEJAM_DIVAN_*`), falling back to the defaults.
  ///
  /// The .NET CLI bound these through `DivanOptions`; a GUI has no flags, but the
  /// environment is still the operator's seam — and it keeps the parity tests honest.
  factory DivanOptions.fromEnvironment(Map<String, String> environment) {
    const defaults = DivanOptions();
    int read(String key, int fallback) =>
        int.tryParse(environment[key] ?? '') ?? fallback;

    return DivanOptions(
      undoDepth: read('JAMEJAM_DIVAN_UNDO_DEPTH', defaults.undoDepth),
      searchLimit: read('JAMEJAM_DIVAN_SEARCH_LIMIT', defaults.searchLimit),
      readingWordsPerMinute: read(
        'JAMEJAM_DIVAN_READING_WPM',
        defaults.readingWordsPerMinute,
      ),
      maxAiBodyChars: read(
        'JAMEJAM_DIVAN_AI_BODY_CHARS',
        defaults.maxAiBodyChars,
      ),
    );
  }

  /// Validates every bound against its rail.
  ///
  /// Throws [RangeError] — the Dart equivalent of the .NET
  /// `ArgumentOutOfRangeException`, matching the other ported option records.
  void validate() {
    if (undoDepth < 0 || undoDepth > DivanDefaults.undoDepthBound) {
      throw RangeError.range(
        undoDepth,
        0,
        DivanDefaults.undoDepthBound,
        'undoDepth',
        'undoDepth must be between 0 and ${DivanDefaults.undoDepthBound}.',
      );
    }

    if (searchLimit < 1 || searchLimit > DivanDefaults.searchLimitBound) {
      throw RangeError.range(
        searchLimit,
        1,
        DivanDefaults.searchLimitBound,
        'searchLimit',
        'searchLimit must be between 1 and ${DivanDefaults.searchLimitBound}.',
      );
    }

    if (readingWordsPerMinute < 50 || readingWordsPerMinute > 1000) {
      throw RangeError.range(
        readingWordsPerMinute,
        50,
        1000,
        'readingWordsPerMinute',
        'readingWordsPerMinute must be between 50 and 1000.',
      );
    }

    if (maxAiBodyChars < 100 || maxAiBodyChars > DivanDefaults.maxAiBodyBound) {
      throw RangeError.range(
        maxAiBodyChars,
        100,
        DivanDefaults.maxAiBodyBound,
        'maxAiBodyChars',
        'maxAiBodyChars must be between 100 and '
            '${DivanDefaults.maxAiBodyBound}.',
      );
    }
  }

  @override
  String toString() =>
      'DivanOptions(undoDepth: $undoDepth, searchLimit: $searchLimit, '
      'readingWordsPerMinute: $readingWordsPerMinute, '
      'maxAiBodyChars: $maxAiBodyChars)';
}
