// Parity port of tests/JameJam.Tests/Divan/DivanCoreTests.cs — the option rails, the pure
// markdown analytics, and the service over the in-memory store.
//
// The .NET suite uses `FixedTimeProvider(2026-09-20T12:00Z)`; this port injects the same
// clock, so every timestamp assertion stays case-for-case comparable.
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/divan/divan_defaults.dart';
import 'package:jamejam/features/divan/divan_options.dart';
import 'package:jamejam/features/divan/divan_service.dart';
import 'package:jamejam/features/divan/divan_store.dart';
import 'package:jamejam/features/divan/models.dart';

void main() {
  group('DivanOptions rails', () {
    test('the defaults are valid', () {
      expect(const DivanOptions().validate, returnsNormally);
    });

    test('undoDepth has rails', () {
      for (final depth in [-1, 101]) {
        expect(
          () => DivanOptions(undoDepth: depth).validate(),
          throwsRangeError,
          reason: 'undoDepth $depth',
        );
      }
    });

    test('searchLimit has rails', () {
      for (final limit in [0, 101]) {
        expect(
          () => DivanOptions(searchLimit: limit).validate(),
          throwsRangeError,
          reason: 'searchLimit $limit',
        );
      }
    });

    test('reading speed has rails', () {
      for (final wpm in [49, 1001]) {
        expect(
          () => DivanOptions(readingWordsPerMinute: wpm).validate(),
          throwsRangeError,
          reason: 'wpm $wpm',
        );
      }
    });

    test('the AI body clip has rails', () {
      for (final clip in [99, 20001]) {
        expect(
          () => DivanOptions(maxAiBodyChars: clip).validate(),
          throwsRangeError,
          reason: 'clip $clip',
        );
      }
    });

    test('the environment can move every rail', () {
      final options = DivanOptions.fromEnvironment(const {
        'JAMEJAM_DIVAN_UNDO_DEPTH': '5',
        'JAMEJAM_DIVAN_SEARCH_LIMIT': '50',
        'JAMEJAM_DIVAN_READING_WPM': '300',
        'JAMEJAM_DIVAN_AI_BODY_CHARS': '800',
      });

      expect(options.undoDepth, 5);
      expect(options.searchLimit, 50);
      expect(options.readingWordsPerMinute, 300);
      expect(options.maxAiBodyChars, 800);
      options.validate();
    });
  });

  group('DivanText', () {
    test('word count counts whitespace runs', () {
      expect(DivanText.wordCount(''), 0);
      expect(DivanText.wordCount('one'), 1);
      expect(DivanText.wordCount('  two  words\nhere\t '), 3);
    });

    test('checklist parses the three list markers and both states', () {
      const body =
          '# Plan\n- [ ] alpha\n  * [X] beta\n+ [x] gamma\nplain line\n'
          '- [not a box]\n';
      final items = DivanText.checklist(body);

      expect(items, hasLength(3));
      expect((items[0].text, items[0].done), ('alpha', false));
      expect((items[1].text, items[1].done), ('beta', true));
      expect((items[2].text, items[2].done), ('gamma', true));
      expect(items[0].lineNumber, 2);
    });

    test('checklist ignores non-boxes', () {
      expect(
        DivanText.checklist('- plain bullet\n- [missing space\n-- [] weird\n'),
        isEmpty,
      );
    });

    test('extract links finds and deduplicates', () {
      final links = DivanText.extractLinks(
        'See [[Alpha]] then [[beta]] and [[Alpha]] again. [[Unclosed stays',
      );
      expect(links, ['Alpha', 'beta']);
    });

    test('extract links skips empty, multiline, and piped targets', () {
      expect(
        DivanText.extractLinks('[[]] [[multi\nline]] [[pip|ed]]'),
        isEmpty,
      );
    });

    test('snippet flattens and clips', () {
      final snippet = DivanText.snippet(
        '# Title\n\nfirst line\nsecond line',
        22,
      );
      expect(snippet, '# Title first line sec…');
      expect(DivanText.snippet('short', 22), isNot(contains('…')));
    });

    test('clip trims and cuts to the rail', () {
      expect(DivanText.clip('  around  ', 10), 'around');
      expect(DivanText.clip('0123456789abc', 5), '01234');
    });

    test('clean tags deduplicates, caps length and count', () {
      expect(DivanText.cleanTags('work, WORK, , x'), 'work,x');
      expect(
        DivanText.cleanTags(List.generate(20, (i) => 't$i').join(',')),
        't0,t1,t2,t3,t4,t5,t6,t7,t8,t9,t10,t11',
      );
      expect(
        DivanText.cleanTags('${'x' * 31},ok'),
        'ok',
        reason: 'a tag longer than the rail is dropped, not clipped',
      );
    });

    test('clean body normalizes line endings, trims and clips', () {
      expect(DivanText.cleanBody('a\r\nb\r\n'), 'a\nb');
      expect(
        DivanText.cleanBody('y' * (DivanDefaults.maxBodyLength + 10)).length,
        DivanDefaults.maxBodyLength,
      );
    });
  });

  group('DivanService', () {
    final now = DateTime.utc(2026, 9, 20, 12);

    late MemoryDivanStore store;
    late DivanService service;

    setUp(() {
      store = MemoryDivanStore();
      service = DivanService(store: store, clock: () => now);
    });

    Future<Note> add(
      String title,
      String body, {
      String? notebook,
      String tags = '',
    }) => service.addNote(title, body, notebookText: notebook, tags: tags);

    test('createNotebook is unique and resolvable', () async {
      final notebook = await service.createNotebook('Research');
      expect(notebook.id, 1);

      await expectLater(
        service.createNotebook('RESEARCH'),
        throwsA(
          isA<DivanException>().having(
            (error) => error.message,
            'message',
            contains('already exists'),
          ),
        ),
      );

      expect((await service.resolveNotebook('research')).id, notebook.id);
      expect((await service.resolveNotebook('${notebook.id}')).id, notebook.id);
    });

    test('resolveNotebook creates the default on an empty pad', () async {
      final resolved = await service.resolveNotebook(null);
      expect(resolved.name, DivanDefaults.defaultNotebook);
    });

    test('addNote lands in the right notebook with clean tags', () async {
      await service.createNotebook('Research');
      final note = await add(
        '  Trimmed title  ',
        'body',
        notebook: 'research',
        tags: 'work, WORK, , x',
      );

      expect(note.title, 'Trimmed title');
      expect(note.notebookId, 1);
      expect(note.tags, 'work,x');
    });

    test('append and edit update the body partially', () async {
      final note = await add('Note', 'first');
      final appended = await service.append(note.id, 'second');
      expect(appended.body, 'first\nsecond');

      final edited = await service.editNote(
        note.id,
        title: 'Renamed',
        tags: 'tag1',
      );
      expect(edited.title, 'Renamed');
      expect(edited.body, 'first\nsecond');
      expect(edited.tags, 'tag1');
      expect(edited.updatedAt, now);

      await expectLater(
        service.editNote(99, title: 'Ghost'),
        throwsA(isA<DivanException>()),
      );
    });

    test('pin, archive, move and delete work', () async {
      await service.createNotebook('Other');
      final note = await add('Note', 'body', notebook: 'Other');

      expect((await service.pin(note.id, true)).pinned, isTrue);
      expect((await service.archive(note.id, true)).archived, isTrue);
      final moved = await service.move(note.id, 'Other');
      expect(moved.notebookId, 1);

      final deleted = await service.delete(note.id);
      expect(deleted.title, 'Note');
      expect(await service.getNote(note.id), isNull);
    });

    test('list filters and sorts pinned first', () async {
      await service.createNotebook('B2');
      final a = await add('Alpha', 'body', tags: 'work');
      final b = await add('Beta', 'body', notebook: 'B2', tags: 'home');
      await service.pin(b.id, true);
      final c = await add('Gamma', '- [ ] task');
      await service.archive(c.id, true);

      expect((await service.list()).map((note) => note.id), [b.id, a.id]);
      expect(
        (await service.list(
          DivanFilter(notebookId: b.notebookId),
        )).map((note) => note.id),
        [b.id, a.id],
      );
      expect(
        (await service.list(
          const DivanFilter(tag: 'work'),
        )).map((note) => note.id),
        [a.id],
      );
      expect(
        (await service.list(
          const DivanFilter(pinnedOnly: true),
        )).map((note) => note.id),
        [b.id],
      );
      expect(
        (await service.list(
          const DivanFilter(archivedOnly: true),
        )).map((note) => note.id),
        [c.id],
      );

      final d = await add('Delta', '- [ ] another');
      expect(
        (await service.list(
          const DivanFilter(checklistsOnly: true),
        )).map((note) => note.id),
        [d.id],
        reason: 'the checklists view only shows active notes',
      );
    });

    test('search finds every term and nothing else', () async {
      await add('Alpha', 'the quick brown fox');
      await add('Beta', 'quick timeline');
      await add('Gamma', 'slow turtle');

      expect(
        (await service.list(
          const DivanFilter(query: 'quick timeline'),
        )).map((note) => note.id),
        [2],
      );
      expect(
        (await service.list(
          const DivanFilter(query: 'quick'),
        )).map((note) => note.id),
        [1, 2],
      );
      expect(await service.list(const DivanFilter(query: 'zebra')), isEmpty);
    });

    test('backlinks are bidirectional', () async {
      final a = await add('Alpha', 'see [[Beta]]');
      final b = await add('Beta', 'back to [[alpha]]');
      await add('Gamma', 'no links');

      expect((await service.backlinks(a.id)).map((note) => note.id), [b.id]);
      expect((await service.backlinks(b.id)).map((note) => note.id), [a.id]);
      expect(await service.backlinks(3), isEmpty);
    });

    test('openTodos aggregates across notes', () async {
      final a = await add('A', '- [ ] one\n- [x] two');
      final b = await add('B', '* [ ] three');
      final todos = await service.openTodos();

      expect(todos, hasLength(2));
      expect((todos[0].note.id, todos[0].item.text), (a.id, 'one'));
      expect((todos[1].note.id, todos[1].item.text), (b.id, 'three'));
    });

    test('daily is idempotent and lands in the journal', () async {
      final first = await service.daily();
      final notebooks = await service.listNotebooks();
      expect(
        notebooks
            .firstWhere((notebook) => notebook.id == first.notebookId)
            .name,
        DivanDefaults.journalNotebook,
      );
      expect(first.title, '2026-09-20');
      expect(first.body, startsWith('# Sunday, 2026-09-20'));

      final again = await service.daily();
      expect(again.id, first.id);
    });

    test('metrics counts everything', () async {
      final note = await add(
        'T',
        '# Heading\n\nsome words here\n- [x] done\n- [ ] open\nSee [[Other]]',
      );
      final metrics = service.metrics(note);
      final words = DivanText.wordCount(note.body);

      expect(metrics.words, words);
      expect(metrics.characters, note.body.length);
      expect(metrics.checklistTotal, 2);
      expect(metrics.checklistDone, 1);
      expect(metrics.links, ['Other']);
      expect(
        metrics.readingSeconds,
        (words * 60 / DivanDefaults.readingWordsPerMinute).ceil(),
      );
    });

    test('stats sums the pad', () async {
      await service.createNotebook('B2');
      await add('A', 'words here', tags: 't1');
      final b = await add('B', '- [ ] task', notebook: 'B2');
      await service.archive(b.id, true);

      final stats = await service.stats();
      expect(
        (stats.notebooks, stats.notes, stats.archivedNotes, stats.taggedNotes),
        (1, 1, 1, 1),
      );
      expect(stats.words, 2);
    });

    test('allTags is distinct, case-insensitive and skips archived', () async {
      await add('A', 'body', tags: 'work,Idea');
      await add('B', 'body', tags: 'WORK, home');
      final archived = await add('C', 'body', tags: 'hidden');
      await service.archive(archived.id, true);

      expect(await service.allTags(), ['work', 'Idea', 'home']);
    });

    test('undo restores notebooks and notes together', () async {
      await service.createNotebook('Keeper');
      final note = await add('Note', 'body', notebook: 'Keeper');
      expect(await store.undoCount, 2, reason: 'notebook + note snapshots');

      await service.delete(note.id);
      expect(await service.getNote(note.id), isNull);

      expect(await service.undo(), isTrue);
      expect((await service.getNote(note.id))!.title, 'Note');

      expect(await service.undo(), isTrue);
      expect(await service.listNotebooks(), hasLength(1));
      expect(await service.getNote(note.id), isNull);

      expect(await service.undo(), isTrue);
      expect(await service.listNotebooks(), isEmpty);
      expect(await service.undo(), isFalse);
    });

    test('undo depth trims the oldest snapshot', () async {
      final tight = DivanService(
        store: store,
        clock: () => now,
        options: const DivanOptions(undoDepth: 1),
      );
      await tight.createNotebook('N');
      expect(await store.undoCount, 1);

      await tight.addNote('A', 'body');
      expect(await store.undoCount, 1);
      await tight.addNote('B', 'body');

      expect(await tight.undo(), isTrue);
      expect(await tight.getNote(2), isNull);
      expect(await tight.getNote(1), isNotNull);
    });

    test('undo trims to the configured depth over many notes', () async {
      final padded = DivanService(
        store: MemoryDivanStore(),
        clock: () => now,
        options: const DivanOptions(undoDepth: 5),
      );
      for (var i = 0; i < 8; i++) {
        await padded.addNote('N$i', '');
      }

      for (var i = 0; i < 5; i++) {
        expect(await padded.undo(), isTrue, reason: 'undo #$i');
      }

      expect(await padded.undo(), isFalse);
      expect(await padded.list(), hasLength(3), reason: 'N0..N2 remain');
    });

    test('removeNotebook guards notes then force clears', () async {
      await service.createNotebook('Doomed');
      await add('Note', 'body', notebook: 'Doomed');

      await expectLater(
        service.removeNotebook('Doomed'),
        throwsA(
          isA<DivanException>().having(
            (error) => error.message,
            'message',
            contains('--force'),
          ),
        ),
      );

      expect(await service.removeNotebook('Doomed', force: true), 1);
      expect(await service.listNotebooks(), isEmpty);
      expect(await service.list(), isEmpty);
    });
  });
}
