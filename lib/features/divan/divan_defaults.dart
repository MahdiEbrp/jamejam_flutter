/// divan — see doc/divan.md and AGENTS.md
abstract final class DivanDefaults {
  // ── Undo ──

  /// Undo snapshots kept.
  static const int undoDepth = 20;

  /// Upper rail for the undo depth.
  static const int undoDepthBound = 100;

  // ── Field bounds ──

  /// Longest note title.
  static const int maxTitleLength = 150;

  /// Longest note body (markdown).
  static const int maxBodyLength = 100000;

  /// Longest notebook name.
  static const int maxNotebookNameLength = 60;

  /// Maximum notebooks in one pad.
  static const int maxNotebooks = 100;

  /// Maximum notes in one pad.
  static const int maxNotes = 10000;

  /// Maximum tags per note.
  static const int maxTagsPerNote = 12;

  /// Longest single tag.
  static const int maxTagLength = 30;

  /// Longest joined tags string.
  static const int maxTagsLength = 400;

  // ── Reading & search ──

  /// Average reading speed for the reading-time estimate.
  static const int readingWordsPerMinute = 200;

  /// Maximum search results returned.
  static const int searchLimit = 20;

  /// Upper rail for the search limit.
  static const int searchLimitBound = 100;

  /// Name of the notebook daily notes land in.
  static const String journalNotebook = 'Journal';

  // ── Import / export ──

  /// Maximum markdown files one import may bring in.
  static const int maxImportFiles = 500;

  // ── AI ──

  /// Longest note body sent to the AI.
  static const int maxAiBodyChars = 4000;

  /// Upper rail for the AI body clip.
  static const int maxAiBodyBound = 20000;

  /// Longest AI question.
  static const int maxAiQuestionChars = 400;

  /// Maximum context notes sent with an AI question.
  static const int maxAiContextNotes = 20;

  /// Maximum tags the AI may suggest.
  static const int maxAiTags = 8;

  /// Default notebook name used when none exists and none is given.
  static const String defaultNotebook = 'Notebook';
}
