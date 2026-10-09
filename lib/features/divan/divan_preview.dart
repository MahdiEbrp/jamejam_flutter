/// divan — see doc/divan.md and AGENTS.md
library;

import 'package:flutter/material.dart';

import 'divan_markdown.dart';

Key divanPreviewItemKey(int lineNumber) =>
    Key('divan.preview.item.$lineNumber');

Key divanPreviewLinkKey(String target) => Key('divan.preview.link.$target');

class DivanPreview extends StatelessWidget {
  const DivanPreview({
    required this.body,
    required this.onToggleItem,
    required this.onOpenLink,
    this.emptyLabel = '',
    this.resolveLink,
    super.key,
  });

  /// The markdown to render (the editor's live text, not the stored body).
  final String body;

  /// Called with the source line number of a tapped checkbox.
  final void Function(int lineNumber) onToggleItem;

  /// Called with the target of a tapped wiki-link.
  final void Function(String target) onOpenLink;

  /// Shown when the note is empty.
  final String emptyLabel;

  /// Whether a link target names an existing note; unknown links render as plain chips.
  final bool Function(String target)? resolveLink;

  @override
  Widget build(BuildContext context) {
    final blocks = DivanMarkdown.parse(body);
    if (blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          emptyLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final block in blocks) _block(context, block)],
    );
  }

  Widget _block(BuildContext context, DivanBlock block) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    switch (block.kind) {
      case DivanBlockKind.heading:
        final sizes = <double>[26, 22, 19, 17, 15, 14];
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            block.lines.single.text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: sizes[block.level.clamp(1, 6) - 1],
              fontWeight: FontWeight.w600,
            ),
          ),
        );

      case DivanBlockKind.rule:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1),
        );

      case DivanBlockKind.code:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                width: double.infinity,
                child: SelectableText(
                  block.lines.map((line) => line.text).join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
          ),
        );

      case DivanBlockKind.quote:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Directional, so the quote rule sits on the reading edge in Persian too.
              border: BorderDirectional(
                start: BorderSide(color: scheme.outlineVariant, width: 3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in block.lines)
                    _rich(context, line.text, italic: true),
                ],
              ),
            ),
          ),
        );

      case DivanBlockKind.checklist:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in block.lines)
              CheckboxListTile(
                key: divanPreviewItemKey(line.lineNumber),
                dense: true,
                value: line.done,
                controlAffinity: ListTileControlAffinity.leading,
                title: _rich(context, line.text, strike: line.done),
                onChanged: (_) => onToggleItem(line.lineNumber),
              ),
          ],
        );

      case DivanBlockKind.bullet:
      case DivanBlockKind.numbered:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in block.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        block.kind == DivanBlockKind.numbered
                            ? line.marker
                            : '•',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(child: _rich(context, line.text)),
                  ],
                ),
              ),
          ],
        );

      case DivanBlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in block.lines) _rich(context, line.text),
            ],
          ),
        );
    }
  }

  /// Renders one line's inline runs.
  Widget _rich(
    BuildContext context,
    String text, {
    bool italic = false,
    bool strike = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.bodyMedium ?? const TextStyle();
    final spans = DivanMarkdown.inline(text);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final span in spans)
          switch (span.kind) {
            DivanSpanKind.plain => Text(
              span.text,
              style: base.copyWith(
                fontStyle: italic ? FontStyle.italic : null,
                decoration: strike ? TextDecoration.lineThrough : null,
              ),
            ),
            DivanSpanKind.bold => Text(
              span.text,
              style: base.copyWith(
                fontWeight: FontWeight.w700,
                decoration: strike ? TextDecoration.lineThrough : null,
              ),
            ),
            DivanSpanKind.italic => Text(
              span.text,
              style: base.copyWith(
                fontStyle: FontStyle.italic,
                decoration: strike ? TextDecoration.lineThrough : null,
              ),
            ),
            DivanSpanKind.code => Text(
              span.text,
              style: base.copyWith(
                fontFamily: 'monospace',
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            DivanSpanKind.link => ActionChip(
              key: divanPreviewLinkKey(span.text),
              label: Text(span.text),
              visualDensity: VisualDensity.compact,
              onPressed: () => onOpenLink(span.text),
            ),
          },
      ],
    );
  }
}
