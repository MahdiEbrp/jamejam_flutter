/// divan — see doc/divan.md and AGENTS.md
library;

enum DivanBlockKind {
  /// `# Heading` through `###### Heading`.
  heading,

  /// `- item`, `* item`, `+ item`.
  bullet,

  /// `- [ ] item` / `- [x] item` — the checklist shape the service parses.
  checklist,

  /// `1. item`, `1) item`.
  numbered,

  /// `> quoted`.
  quote,

  /// A fenced ``` block, kept verbatim.
  code,

  /// `---`, `***`, `___`.
  rule,

  /// Anything else: running text.
  paragraph,
}

class DivanBlock {
  const DivanBlock({required this.kind, required this.lines, this.level = 0});

  /// What the block is.
  final DivanBlockKind kind;

  /// The block's lines (headings and paragraphs carry exactly one entry).
  final List<DivanBlockLine> lines;

  /// Heading level 1–6, or the list nesting depth for quoted/nested lines.
  final int level;
}

class DivanBlockLine {
  const DivanBlockLine({
    required this.text,
    this.done = false,
    this.lineNumber = 0,
    this.marker = '',
  });

  /// The line's text, without its marker.
  final String text;

  /// True when a checklist box is ticked.
  final bool done;

  /// 1-based line in the source body (checklist rows use it to toggle in place).
  final int lineNumber;

  /// The list marker as written (`-`, `*`, `+`, `3.`), for numbered lists and quotes.
  final String marker;
}

enum DivanSpanKind {
  /// Literal text.
  plain,

  /// `**bold**` / `__bold__`.
  bold,

  /// `*italic*` / `_italic_`.
  italic,

  /// `` `code` ``.
  code,

  /// `[[wiki-link]]`.
  link,
}

class DivanSpan {
  const DivanSpan(this.kind, this.text);

  /// What the run is.
  final DivanSpanKind kind;

  /// The run's text — for a link, the target without its brackets.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is DivanSpan && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => 'DivanSpan(${kind.name}: $text)';
}

abstract final class DivanMarkdown {
  /// Splits [body] into renderable blocks.
  static List<DivanBlock> parse(String body) {
    final blocks = <DivanBlock>[];
    final lines = body.split('\n');
    var index = 0;

    while (index < lines.length) {
      final raw = lines[index];
      final line = raw.trimRight();
      final lineNumber = index + 1;

      if (line.trim().isEmpty) {
        index++;
        continue;
      }

      // ``` fences run until the next fence (or the end of the note).
      if (_isFence(line)) {
        final code = <DivanBlockLine>[];
        index++;
        while (index < lines.length && !_isFence(lines[index])) {
          code.add(DivanBlockLine(text: lines[index], lineNumber: index + 1));
          index++;
        }
        if (index < lines.length) index++; // closing fence
        blocks.add(DivanBlock(kind: DivanBlockKind.code, lines: code));
        continue;
      }

      if (_isRule(line)) {
        blocks.add(const DivanBlock(kind: DivanBlockKind.rule, lines: []));
        index++;
        continue;
      }

      final heading = _heading(line);
      if (heading != null) {
        blocks.add(
          DivanBlock(
            kind: DivanBlockKind.heading,
            level: heading.level,
            lines: [DivanBlockLine(text: heading.text, lineNumber: lineNumber)],
          ),
        );
        index++;
        continue;
      }

      // Lists run until a line stops matching their marker.
      final listKind = _listKind(line);
      if (listKind != null) {
        final items = <DivanBlockLine>[];
        while (index < lines.length) {
          final current = lines[index].trimRight();
          final item = _listItem(current, index + 1);
          if (item == null || item.kind != listKind) break;
          items.add(item.line);
          index++;
        }
        blocks.add(DivanBlock(kind: listKind, lines: items));
        continue;
      }

      if (line.trimLeft().startsWith('>')) {
        final quoted = <DivanBlockLine>[];
        while (index < lines.length &&
            lines[index].trimLeft().startsWith('>')) {
          final text = lines[index].trimLeft().substring(1).trim();
          quoted.add(DivanBlockLine(text: text, lineNumber: index + 1));
          index++;
        }
        blocks.add(DivanBlock(kind: DivanBlockKind.quote, lines: quoted));
        continue;
      }

      // A paragraph: consecutive plain lines, a hard break keeps them apart.
      final paragraph = <DivanBlockLine>[];
      while (index < lines.length) {
        final current = lines[index].trimRight();
        if (current.trim().isEmpty ||
            _isFence(current) ||
            _isRule(current) ||
            _heading(current) != null ||
            _listKind(current) != null ||
            current.trimLeft().startsWith('>')) {
          break;
        }
        paragraph.add(
          DivanBlockLine(text: current.trim(), lineNumber: index + 1),
        );
        index++;
      }
      blocks.add(DivanBlock(kind: DivanBlockKind.paragraph, lines: paragraph));
    }

    return blocks;
  }

  /// Splits one line of text into its inline runs.
  static List<DivanSpan> inline(String text) {
    final spans = <DivanSpan>[];
    final buffer = StringBuffer();
    var index = 0;

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(DivanSpan(DivanSpanKind.plain, buffer.toString()));
      buffer.clear();
    }

    while (index < text.length) {
      // `code` wins over every emphasis rule.
      if (text[index] == '`') {
        final close = text.indexOf('`', index + 1);
        if (close > index + 1) {
          flush();
          spans.add(
            DivanSpan(DivanSpanKind.code, text.substring(index + 1, close)),
          );
          index = close + 1;
          continue;
        }
      }

      if (text.startsWith('[[', index)) {
        final close = text.indexOf(']]', index + 2);
        if (close > index + 2) {
          flush();
          spans.add(
            DivanSpan(DivanSpanKind.link, text.substring(index + 2, close)),
          );
          index = close + 2;
          continue;
        }
      }

      if (text.startsWith('**', index) || text.startsWith('__', index)) {
        final marker = text.substring(index, index + 2);
        final close = text.indexOf(marker, index + 2);
        if (close > index + 2) {
          flush();
          spans.add(
            DivanSpan(DivanSpanKind.bold, text.substring(index + 2, close)),
          );
          index = close + 2;
          continue;
        }
      }

      if (text[index] == '*' || text[index] == '_') {
        final close = text.indexOf(text[index], index + 1);
        if (close > index + 1) {
          flush();
          spans.add(
            DivanSpan(DivanSpanKind.italic, text.substring(index + 1, close)),
          );
          index = close + 1;
          continue;
        }
      }

      buffer.write(text[index]);
      index++;
    }

    flush();
    return spans;
  }

  static bool _isFence(String line) =>
      line.trimLeft().startsWith('```') || line.trimLeft().startsWith('~~~');

  static bool _isRule(String line) {
    final trimmed = line.trim();
    if (trimmed.length < 3) return false;
    final first = trimmed[0];
    if (first != '-' && first != '*' && first != '_') return false;
    return trimmed.split('').every((character) => character == first);
  }

  static ({int level, String text})? _heading(String line) {
    final match = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line.trimLeft());
    if (match == null) return null;
    return (level: match.group(1)!.length, text: match.group(2)!.trim());
  }

  /// The list kind for [line], or null when the line is not a list item.
  static DivanBlockKind? _listKind(String line) => _listItem(line, 0)?.kind;

  static ({DivanBlockKind kind, DivanBlockLine line})? _listItem(
    String line,
    int lineNumber,
  ) {
    final match = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$').firstMatch(line);
    if (match == null) return null;

    final marker = match.group(2)!;
    final rest = match.group(3)!;
    final numbered = RegExp(r'^\d').hasMatch(marker);

    // The checklist shape the service parses: `- [ ] text` / `- [x] text`.
    final box = RegExp(r'^\[([ xX])\]\s?(.*)$').firstMatch(rest);
    if (box != null && !numbered) {
      return (
        kind: DivanBlockKind.checklist,
        line: DivanBlockLine(
          text: box.group(2)!.trimRight(),
          done: box.group(1)!.toLowerCase() == 'x',
          lineNumber: lineNumber,
          marker: marker,
        ),
      );
    }

    return (
      kind: numbered ? DivanBlockKind.numbered : DivanBlockKind.bullet,
      line: DivanBlockLine(text: rest, lineNumber: lineNumber, marker: marker),
    );
  }
}
