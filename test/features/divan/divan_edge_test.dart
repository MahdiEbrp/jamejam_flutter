// Parity port of tests/JameJam.Tests/Divan/DivanEdgeTests.cs (the service-level guards the
// CLI reached through its verbs) plus the markdown export/import round trip from
// DivanCoreTests.cs.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/divan/divan_defaults.dart';
import 'package:jamejam/features/divan/divan_service.dart';
import 'package:jamejam/features/divan/divan_store.dart';
import 'package:jamejam/features/divan/models.dart';
import 'package:jamejam/features/divan/sqlite_divan_store.dart';

void main() {
  final clock = DateTime.utc(2026, 9, 20, 12);

  DivanService build([DivanStore? store]) =>
      DivanService(store: store ?? MemoryDivanStore(), clock: () => clock);

  group('DivanService guards', () {
    test('notebook names are guarded', () async {
      final service = build();
      await service.createNotebook('Alpha');

      expect(
        () => service.createNotebook('alpha'),
        throwsA(
          isA<DivanException>().having(
            (error) => error.message,
            'message',
            contains('already exists'),
          ),
        ),
      );

      await service.createNotebook('Beta');
      expect(
        () => service.renameNotebook('1', 'beta'),
        throwsA(
          isA<DivanException>().having(
            (error) => error.message,
            'message',
            contains('already exists'),
          ),
        ),
      );

      // Renaming a notebook to its own name is allowed.
      expect((await service.renameNotebook('2', 'Beta')).name, 'Beta');
    });

    test('a blank notebook name is rejected', () async {
      final service = build();
      expect(() => service.createNotebook('   '), throwsArgumentError);
      expect(() => service.renameNotebook('1', '  '), throwsArgumentError);
    });

    test('append joins per body shape', () async {
      final service = build();
      final bare = await service.addNote('Bare', 'text');
      expect((await service.append(bare.id, 'more')).body, 'text\nmore');

      final trailing = await service.addNote('Trailing', 'text\n');
      expect((await service.append(trailing.id, 'more')).body, 'text\nmore');

      final empty = await service.addNote('Empty', '');
      expect((await service.append(empty.id, 'more')).body, 'more');

      await expectLater(
        service.append(999, 'x'),
        throwsA(isA<DivanException>()),
      );
      await expectLater(service.append(1, '   '), throwsArgumentError);
    });

    test('addNote trims long titles and rejects a blank one', () async {
      final service = build();
      final longTitle = 'x' * (DivanDefaults.maxTitleLength + 50);
      final note = await service.addNote(longTitle, '');
      expect(note.title.length, DivanDefaults.maxTitleLength);

      expect(() => service.addNote('   ', ''), throwsArgumentError);
    });

    test('a note body is clipped to the rail', () async {
      final service = build();
      final note = await service.addNote(
        'Long',
        'y' * (DivanDefaults.maxBodyLength + 100),
      );
      expect(note.body.length, DivanDefaults.maxBodyLength);
    });

    test('store updates of missing entities throw', () async {
      final store = MemoryDivanStore();
      await expectLater(
        store.updateNotebook(Notebook(id: 99, name: 'Ghost', createdAt: clock)),
        throwsA(
          isA<DivanException>().having(
            (error) => error.message,
            'message',
            contains('No notebook #99'),
          ),
        ),
      );

      await expectLater(
        store.updateNote(
          Note(
            id: 99,
            notebookId: 1,
            title: 'Ghost',
            body: '',
            createdAt: clock,
            updatedAt: clock,
          ),
        ),
        throwsA(isA<DivanException>()),
      );
    });

    test('SQLite updates of missing entities throw', () async {
      final directory = Directory.systemTemp.createTempSync(
        'divan-edge-sqlite',
      );
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });

      final store = SqliteDivanStore('${directory.path}/divan.db');
      await store.initialize();

      await expectLater(
        store.updateNotebook(Notebook(id: 99, name: 'Ghost', createdAt: clock)),
        throwsA(isA<DivanException>()),
      );
      await expectLater(
        store.updateNote(
          Note(
            id: 99,
            notebookId: 1,
            title: 'Ghost',
            body: '',
            createdAt: clock,
            updatedAt: clock,
          ),
        ),
        throwsA(isA<DivanException>()),
      );
      await store.close();
    });
  });

  group('markdown export and import', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('divan-export');
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    test('a pad round-trips through a folder of markdown files', () async {
      final service = build();
      await service.createNotebook('Research');
      await service.addNote(
        'Alpha',
        'body one',
        notebookText: 'Research',
        tags: 'work',
      );
      await service.addNote('Beta', '- [ ] x', notebookText: 'Research');
      await service.pin(1, true);

      expect(await service.export(directory.path), 2);
      expect(
        directory.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.md'),
        ),
        hasLength(2),
      );

      final fresh = build();
      expect(await fresh.import(directory.path), 2);

      final imported = await fresh.list();
      expect(imported.map((note) => note.title), ['Alpha', 'Beta']);
      expect(
        imported.firstWhere((note) => note.title == 'Alpha').pinned,
        isTrue,
      );
      expect((await fresh.resolveNotebook(null)).name, 'Research');
    });

    test('the front matter carries notebook, tags, pin and body', () async {
      final service = build();
      await service.createNotebook('Research');
      final note = await service.addNote(
        'Alpha',
        '# Heading\n\nbody',
        notebookText: 'Research',
        tags: 'work,idea',
      );
      await service.pin(note.id, true);
      await service.export(directory.path);

      final file = directory.listSync().whereType<File>().singleWhere(
        (entry) => entry.path.endsWith('.md'),
      );
      final contents = file.readAsStringSync();

      expect(contents, startsWith('---\n'));
      expect(contents, contains('title: Alpha'));
      expect(contents, contains('notebook: Research'));
      expect(contents, contains('tags: work,idea'));
      expect(contents, contains('pinned: true'));
      expect(contents, contains('# Heading'));
    });

    test('import skips unparseable files but imports the good ones', () async {
      File('${directory.path}/a-good.md').writeAsStringSync(
        '---\ntitle: Good One\nnotebook: Real\ntags: x\npinned: true\n---\n\n'
        'body here\n',
      );
      File(
        '${directory.path}/b-plain.md',
      ).writeAsStringSync('no front matter at all\n');
      File(
        '${directory.path}/c-unterminated.md',
      ).writeAsStringSync('---\ntitle: Never Closed\nbody continues forever\n');
      File(
        '${directory.path}/d-notitle.md',
      ).writeAsStringSync('---\nnotebook: Real\n---\nbody\n');

      final service = build();
      await service.createNotebook('Real');

      expect(await service.import(directory.path), 1);
      final imported = await service.list();
      expect(imported.single.title, 'Good One');
      expect(imported.single.pinned, isTrue);
      expect(imported.single.tags, 'x');
    });

    test('import fails friendly on a missing or empty folder', () async {
      final service = build();
      await expectLater(
        service.import('${directory.path}/ghost'),
        throwsA(
          isA<DivanException>().having(
            (error) => error.message,
            'message',
            contains('No such folder'),
          ),
        ),
      );
      await expectLater(
        service.import(directory.path),
        throwsA(
          isA<DivanException>().having(
            (error) => error.message,
            'message',
            contains('No .md files found'),
          ),
        ),
      );
    });

    test('an import is a single undoable step', () async {
      File(
        '${directory.path}/a.md',
      ).writeAsStringSync('---\ntitle: Imported\n---\nbody\n');

      final store = MemoryDivanStore();
      final service = build(store);
      await service.import(directory.path);

      // Two snapshots, exactly like the CLI: the import itself, then the implicit notebook
      // creation it had to do — and both captured the same empty pad, so one undo takes the
      // imported note *and* the notebook it landed in back to that state.
      expect(await store.undoCount, 2);
      expect(await service.list(), hasLength(1));

      expect(await service.undo(), isTrue);
      expect(await service.list(), isEmpty);
      expect(await service.listNotebooks(), isEmpty);
    });
  });
}
