// The pad's preview pane: the markdown pass that turns a note body into blocks and inline
// runs, and the pane that renders them — live checkboxes and clickable wiki-links included.
//
// The CLI never rendered markdown (it only wrote it), so these cases pin the GUI-only
// behaviour instead of a .NET counterpart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/divan/divan_markdown.dart';
import 'package:jamejam/features/divan/divan_page.dart';
import 'package:jamejam/features/divan/divan_preview.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('DivanMarkdown — blocks', () {
    test('headings carry their level', () {
      final blocks = DivanMarkdown.parse('# One\n## Two\n###### Six');
      expect(
        blocks.map((block) => block.kind),
        everyElement(DivanBlockKind.heading),
      );
      expect(blocks.map((block) => block.level), [1, 2, 6]);
      expect(blocks.first.lines.single.text, 'One');
    });

    test('checklists keep the source line number and the box state', () {
      final blocks = DivanMarkdown.parse('intro\n\n- [ ] open\n* [x] done');
      final checklist = blocks.last;
      expect(checklist.kind, DivanBlockKind.checklist);
      expect(checklist.lines.map((line) => line.lineNumber), [3, 4]);
      expect(checklist.lines.map((line) => line.done), [false, true]);
      expect(checklist.lines.map((line) => line.text), ['open', 'done']);
    });

    test('bullets, numbered lists, quotes, and rules are distinguished', () {
      final blocks = DivanMarkdown.parse(
        '- bullet\n1. numbered\n> quoted\n---',
      );
      expect(blocks.map((block) => block.kind), [
        DivanBlockKind.bullet,
        DivanBlockKind.numbered,
        DivanBlockKind.quote,
        DivanBlockKind.rule,
      ]);
      expect(blocks[1].lines.single.marker, '1.');
      expect(blocks[2].lines.single.text, 'quoted');
    });

    test('consecutive plain lines join into one paragraph', () {
      final blocks = DivanMarkdown.parse('one\ntwo\n\nthree');
      expect(blocks, hasLength(2));
      expect(blocks.first.kind, DivanBlockKind.paragraph);
      expect(blocks.first.lines.map((line) => line.text), ['one', 'two']);
      expect(blocks.last.lines.single.text, 'three');
    });

    test('fenced code stays verbatim, fences and all stripped', () {
      final blocks = DivanMarkdown.parse(
        'text\n\n```dart\nfinal x = 1;\n```\n\n# after',
      );
      final code = blocks.singleWhere(
        (block) => block.kind == DivanBlockKind.code,
      );
      expect(code.lines.map((line) => line.text), ['final x = 1;']);
      expect(blocks.last.kind, DivanBlockKind.heading);
    });

    test('an unclosed fence swallows the rest of the note', () {
      final blocks = DivanMarkdown.parse('```\nstill code');
      expect(blocks.single.kind, DivanBlockKind.code);
      expect(blocks.single.lines.single.text, 'still code');
    });

    test('a blank body is an empty document', () {
      expect(DivanMarkdown.parse(''), isEmpty);
      expect(DivanMarkdown.parse('   \n\n  '), isEmpty);
    });

    test('a dash that is not a list marker stays text', () {
      final blocks = DivanMarkdown.parse('-not a list\n-but close');
      expect(blocks.single.kind, DivanBlockKind.paragraph);
    });
  });

  group('DivanMarkdown — inline', () {
    test('plain text is one run', () {
      expect(DivanMarkdown.inline('just words'), [
        const DivanSpan(DivanSpanKind.plain, 'just words'),
      ]);
    });

    test('bold, italic, code, and wiki-links are separated', () {
      expect(DivanMarkdown.inline('a **b** _c_ `d` [[Target]]'), [
        const DivanSpan(DivanSpanKind.plain, 'a '),
        const DivanSpan(DivanSpanKind.bold, 'b'),
        const DivanSpan(DivanSpanKind.plain, ' '),
        const DivanSpan(DivanSpanKind.italic, 'c'),
        const DivanSpan(DivanSpanKind.plain, ' '),
        const DivanSpan(DivanSpanKind.code, 'd'),
        const DivanSpan(DivanSpanKind.plain, ' '),
        const DivanSpan(DivanSpanKind.link, 'Target'),
      ]);
    });

    test(
      'underscores and double underscores work like their asterisk forms',
      () {
        expect(DivanMarkdown.inline('__bold__ and __not closed'), [
          const DivanSpan(DivanSpanKind.bold, 'bold'),
          const DivanSpan(DivanSpanKind.plain, ' and __not closed'),
        ]);
      },
    );

    test('markers without a closing partner stay literal', () {
      expect(DivanMarkdown.inline('**open'), [
        const DivanSpan(DivanSpanKind.plain, '**open'),
      ]);
      expect(DivanMarkdown.inline('[[unclosed'), [
        const DivanSpan(DivanSpanKind.plain, '[[unclosed'),
      ]);
      expect(DivanMarkdown.inline('`code'), [
        const DivanSpan(DivanSpanKind.plain, '`code'),
      ]);
    });

    test('code wins over the emphasis inside it', () {
      expect(DivanMarkdown.inline('`a*b*c`'), [
        const DivanSpan(DivanSpanKind.code, 'a*b*c'),
      ]);
    });
  });

  group('DivanPreview — rendering', () {
    testWidgets('renders headings, lists, and links', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DivanPreview(
                body: '# Title\n\n- one\n1. first\n\nSee [[Alpha]].',
                onToggleItem: (_) {},
                onOpenLink: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('one'), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
      expect(find.byKey(divanPreviewLinkKey('Alpha')), findsOneWidget);
    });

    testWidgets('an empty note shows the empty label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DivanPreview(
              body: '',
              emptyLabel: 'Nothing to preview yet.',
              onToggleItem: (_) {},
              onOpenLink: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Nothing to preview yet.'), findsOneWidget);
    });
  });

  group('DivanPage — preview pane', () {
    testWidgets('the toggle swaps the source for the rendered note, and back', (
      tester,
    ) async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      await harness.build();
      final controller = harness.services.divan;
      final note = await controller.addNote(
        title: 'Alpha',
        body: '# Heading\n\n- [ ] task one',
      );

      await tester.binding.setSurfaceSize(const Size(1400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness.wrap(const DivanPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(divanNoteTileKey(note!.id)));
      await tester.pumpAndSettle();

      expect(find.byKey(divanBodyFieldKey), findsOneWidget);
      await tester.tap(find.byKey(divanPreviewToggleKey));
      await tester.pumpAndSettle();

      expect(find.byKey(divanBodyFieldKey), findsNothing);
      expect(find.text('Heading'), findsOneWidget);
      expect(find.byKey(divanPreviewItemKey(3)), findsOneWidget);

      // Ticking the box in the preview writes through to the note.
      await tester.tap(find.byKey(divanPreviewItemKey(3)));
      await tester.pumpAndSettle();
      expect(controller.selected!.body.split('\n').last, '- [x] task one');

      await tester.tap(find.byKey(divanPreviewToggleKey));
      await tester.pumpAndSettle();
      expect(find.byKey(divanBodyFieldKey), findsOneWidget);
    });

    testWidgets('a wiki-link in the preview opens the note it names', (
      tester,
    ) async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      await harness.build();
      final controller = harness.services.divan;
      final target = await controller.addNote(title: 'Target', body: 'here');
      final source = await controller.addNote(
        title: 'Source',
        body: 'see [[Target]] for details',
      );

      await tester.binding.setSurfaceSize(const Size(1400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness.wrap(const DivanPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(divanNoteTileKey(source!.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(divanPreviewToggleKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(divanPreviewLinkKey('Target')));
      await tester.pumpAndSettle();

      expect(controller.selected!.id, target!.id);
    });
  });
}
