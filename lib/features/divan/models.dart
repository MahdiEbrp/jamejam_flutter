/// divan — see doc/divan.md and AGENTS.md
import 'divan_defaults.dart';

class DivanException implements Exception {
  const DivanException(this.message);

  /// The reason, ready to show a user.
  final String message;

  @override
  String toString() => 'DivanException: $message';
}

class Notebook {
  const Notebook({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isArchived = false,
    DateTime? updatedAt,
  }) : _updatedAt = updatedAt;

  /// Assigned by the store (0 before an insert).
  final int id;

  /// Unique, case-insensitive name.
  final String name;

  /// When the notebook was created.
  final DateTime createdAt;

  /// Archived notebooks hide from lists but keep their notes.
  final bool isArchived;

  final DateTime? _updatedAt;

  /// When the notebook last changed (rename/archive); drives sync last-write-wins.
  ///
  /// Null means "never touched since creation" — the .NET record's `default`, which the
  /// sync adapter falls back to `createdAt` for.
  DateTime? get updatedAt => _updatedAt;

  Notebook copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    bool? isArchived,
    DateTime? updatedAt,
  }) => Notebook(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    isArchived: isArchived ?? this.isArchived,
    updatedAt: updatedAt ?? _updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Notebook &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.isArchived == isArchived &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, name, createdAt, isArchived, updatedAt);

  @override
  String toString() => 'Notebook(#$id, $name, archived: $isArchived)';
}

class Note {
  const Note({
    required this.notebookId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.id = 0,
    this.tags = '',
    this.pinned = false,
    this.archived = false,
    this.syncId = '',
  });

  /// Assigned by the store (0 before an insert).
  final int id;

  /// The notebook this note belongs to.
  final int notebookId;

  /// Human title (plain text).
  final String title;

  /// Markdown body.
  final String body;

  /// Comma-joined tags (empty when untagged).
  final String tags;

  /// Pinned notes sort first.
  final bool pinned;

  /// Soft-deleted notes.
  final bool archived;

  /// When the note was created.
  final DateTime createdAt;

  /// When the note was last changed.
  final DateTime updatedAt;

  /// Stable cross-device identity; stores assign one when empty.
  final String syncId;

  /// True when this note has no sync identity yet.
  bool get hasSyncId => syncId.isNotEmpty;

  /// Tags split into individual labels (empty when the note has none).
  List<String> get tagList =>
      tags.isEmpty ? const [] : tags.split(',').toList(growable: false);

  Note copyWith({
    int? id,
    int? notebookId,
    String? title,
    String? body,
    String? tags,
    bool? pinned,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncId,
  }) => Note(
    id: id ?? this.id,
    notebookId: notebookId ?? this.notebookId,
    title: title ?? this.title,
    body: body ?? this.body,
    tags: tags ?? this.tags,
    pinned: pinned ?? this.pinned,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncId: syncId ?? this.syncId,
  );

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.notebookId == notebookId &&
      other.title == title &&
      other.body == body &&
      other.tags == tags &&
      other.pinned == pinned &&
      other.archived == archived &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.syncId == syncId;

  @override
  int get hashCode => Object.hash(
    id,
    notebookId,
    title,
    body,
    tags,
    pinned,
    archived,
    createdAt,
    updatedAt,
    syncId,
  );

  @override
  String toString() => 'Note(#$id, $title${pinned ? ', pinned' : ''})';
}

class DivanTombstone {
  const DivanTombstone({required this.syncId, required this.deletedAt});

  /// The deleted note's sync identity.
  final String syncId;

  /// When the deletion happened (UTC).
  final DateTime deletedAt;

  @override
  bool operator ==(Object other) =>
      other is DivanTombstone &&
      other.syncId == syncId &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(syncId, deletedAt);

  @override
  String toString() => 'DivanTombstone($syncId, $deletedAt)';
}

class ChecklistItem {
  const ChecklistItem({
    required this.text,
    required this.done,
    required this.lineNumber,
  });

  /// The item text.
  final String text;

  /// Whether the box is checked.
  final bool done;

  /// 1-based line in the body.
  final int lineNumber;

  @override
  bool operator ==(Object other) =>
      other is ChecklistItem &&
      other.text == text &&
      other.done == done &&
      other.lineNumber == lineNumber;

  @override
  int get hashCode => Object.hash(text, done, lineNumber);

  @override
  String toString() => 'ChecklistItem(${done ? 'x' : ' '} $text @$lineNumber)';
}

class OpenTodo {
  const OpenTodo({required this.note, required this.item});

  /// The containing note.
  final Note note;

  /// The parsed item.
  final ChecklistItem item;

  @override
  String toString() => 'OpenTodo(#${note.id} L${item.lineNumber} ${item.text})';
}

class NoteMetrics {
  const NoteMetrics({
    required this.words,
    required this.characters,
    required this.readingSeconds,
    required this.checklistTotal,
    required this.checklistDone,
    required this.links,
  });

  /// Word count of the body.
  final int words;

  /// Character count of the body.
  final int characters;

  /// Estimated reading time at the configured pace.
  final int readingSeconds;

  /// Checklist items in the body.
  final int checklistTotal;

  /// Checked checklist items.
  final int checklistDone;

  /// Wiki-links (`[[…]]`) found in the body.
  final List<String> links;

  @override
  String toString() =>
      'NoteMetrics(words: $words, checklist: $checklistDone/$checklistTotal)';
}

class DivanFilter {
  const DivanFilter({
    this.notebookId,
    this.tag,
    this.query,
    this.pinnedOnly = false,
    this.archivedOnly = false,
    this.checklistsOnly = false,
  });

  /// Only this notebook.
  final int? notebookId;

  /// Only notes carrying this tag (case-insensitive).
  final String? tag;

  /// Substring over title and body.
  final String? query;

  /// Only pinned notes.
  final bool pinnedOnly;

  /// Only archived notes (list excludes them by default).
  final bool archivedOnly;

  /// Only notes containing at least one checklist item.
  final bool checklistsOnly;

  @override
  String toString() =>
      'DivanFilter(notebook: $notebookId, tag: $tag, query: $query)';
}

class DivanStats {
  const DivanStats({
    required this.notebooks,
    required this.notes,
    required this.archivedNotes,
    required this.taggedNotes,
    required this.words,
    required this.openChecklistItems,
    required this.links,
  });

  /// Notebook count.
  final int notebooks;

  /// Active (non-archived) note count.
  final int notes;

  /// Archived note count.
  final int archivedNotes;

  /// Notes carrying at least one tag.
  final int taggedNotes;

  /// Total word count across active notes.
  final int words;

  /// Unchecked checklist items across active notes.
  final int openChecklistItems;

  /// Wiki-links across active notes.
  final int links;

  @override
  String toString() =>
      'DivanStats(notebooks: $notebooks, notes: $notes, words: $words)';
}

abstract final class DivanText {
  /// Trims and clips text to a hard length (the shared rail helper).
  static String clip(String value, int maxLength) {
    final trimmed = value.trim();
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }

  /// Counts whitespace-separated words.
  static int wordCount(String body) {
    final matches = RegExp(r'\S+').allMatches(body);
    return matches.length;
  }

  /// Parses markdown checklist items (`- [ ]`, `- [x]`, `* [X]`) line by line.
  ///
  /// Shape: `"- [ ] text"` / `"* [x] text"` — a list marker, a space, `[`, the box
  /// character, `]`, then the text.
  static List<ChecklistItem> checklist(String body) {
    final items = <ChecklistItem>[];
    final lines = body.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].replaceFirst(RegExp(r'^\s+'), '');
      if (line.length < 6) continue;

      final marker = line[0];
      if (marker != '-' && marker != '*' && marker != '+') continue;
      if (line[1] != ' ' || line[2] != '[' || line[4] != ']') continue;

      final box = line[3].toLowerCase();
      if (box != ' ' && box != 'x') continue;

      items.add(
        ChecklistItem(
          text: line.substring(5).trim(),
          done: box == 'x',
          lineNumber: i + 1,
        ),
      );
    }

    return items;
  }

  /// Extracts wiki-link targets (`[[Note Title]]`) in order, deduplicated
  /// case-insensitively. Unclosed brackets are ignored.
  static List<String> extractLinks(String body) {
    final links = <String>[];
    final seen = <String>{};
    var rest = body;

    while (true) {
      final start = rest.indexOf('[[');
      if (start < 0) break;

      final after = rest.substring(start + 2);
      final end = after.indexOf(']]');
      if (end < 0) break;

      final candidate = after.substring(0, end).trim();
      rest = after.substring(end + 2);

      if (candidate.isEmpty ||
          candidate.contains('\n') ||
          candidate.contains('|')) {
        continue;
      }

      if (seen.add(candidate.toLowerCase())) {
        links.add(candidate);
      }
    }

    return links;
  }

  /// Builds a plain-text snippet of at most [maxLength] characters.
  ///
  /// Lines are flattened with single spaces; the budget is measured on the flattened text,
  /// and only a clipped snippet gets the trailing ellipsis.
  static String snippet(String body, int maxLength) {
    final flat = StringBuffer();
    for (final line in body.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        if (flat.length > 0) flat.write(' ');
        flat.write(trimmed);
      }

      if (flat.length >= maxLength) break;
    }

    if (flat.length <= maxLength) return flat.toString();
    return '${flat.toString().substring(0, maxLength)}…';
  }

  /// The `yyyy-MM-dd` form used for journal titles and export names.
  static String isoDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Trims a comma-separated tag list: distinct (case-insensitive), length-capped,
  /// count-capped, joined back with commas.
  static String cleanTags(String tags) {
    final split = tags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final kept = <String>[];
    final seen = <String>{};
    for (final tag in split) {
      if (tag.length > DivanDefaults.maxTagLength) continue;
      if (!seen.add(tag.toLowerCase())) continue;
      kept.add(tag);
      if (kept.length >= DivanDefaults.maxTagsPerNote) break;
    }

    final joined = kept.join(',');
    return joined.length <= DivanDefaults.maxTagsLength
        ? joined
        : joined.substring(0, DivanDefaults.maxTagsLength);
  }

  /// Normalizes a body: `\r\n` becomes `\n`, then trimmed and clipped to the rail.
  static String cleanBody(String body) {
    final normalized = body.replaceAll('\r\n', '\n').trim();
    return normalized.length <= DivanDefaults.maxBodyLength
        ? normalized
        : normalized.substring(0, DivanDefaults.maxBodyLength);
  }
}
