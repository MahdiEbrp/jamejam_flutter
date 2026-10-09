// The pad screen's state machine: the notebook/tag/query filters, the selection that
// survives refreshes, the checklist toggle, the journal quick-add, undo, transfer, AI, and
// sync. The service, the stores, and the sync adapter have their own suites — this one is
// about what `DivanCommands` and the CLI's verb loop used to hold.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/divan/divan_controller.dart';
import 'package:jamejam/features/divan/divan_defaults.dart';
import 'package:jamejam/features/divan/divan_options.dart';
import 'package:jamejam/features/divan/divan_service.dart';
import 'package:jamejam/features/divan/divan_store.dart';
import 'package:jamejam/features/settings/memory_settings_store.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/settings/settings_controller.dart';
import 'package:jamejam/features/soroush/ai_funnel.dart';
import 'package:jamejam/features/sync/sync_client.dart';
import 'package:jamejam/features/sync/sync_models.dart';

/// The clock every case runs on, so timestamps are deterministic.
final DateTime _clock = DateTime.utc(2026, 9, 20, 12);

String _completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

/// A blob server in a variable — the smallest remote any host can implement.
class _BlobClient implements SyncClient {
  String? document;

  /// Every payload that was written.
  final List<String> puts = [];

  @override
  Future<String?> get() async => document;

  @override
  Future<void> put(String json) async {
    document = json;
    puts.add(json);
  }
}

Future<
  ({
    DivanController controller,
    DivanService service,
    DivanStore store,
    SettingsController settings,
    _BlobClient remote,
  })
>
_build({
  DivanStore? store,
  DivanOptions? options,
  SettingsController? settings,
  http.Client? httpClient,
  bool withFunnel = true,
  bool withSyncClient = true,
  String Function(String key)? environment,
}) async {
  final settingsController =
      settings ?? SettingsController(MemorySettingsStore());
  if (settings == null) await settingsController.load();

  final padStore = store ?? MemoryDivanStore();
  final service = DivanService(
    store: padStore,
    clock: () => _clock,
    options: options ?? const DivanOptions(),
  );

  final remote = _BlobClient();
  final controller = DivanController(
    service: service,
    settings: settingsController,
    funnel: withFunnel
        ? AiFunnel(
            settings: settingsController,
            secrets: await _seededSecrets(),
            httpClient:
                httpClient ??
                MockClient(
                  (_) async => http.Response(_completion('done'), 200),
                ),
          )
        : null,
    syncClientFactory: withSyncClient ? (url, {token}) => remote : null,
    environment: environment,
  );

  await controller.initialize();
  return (
    controller: controller,
    service: service,
    store: padStore,
    settings: settingsController,
    remote: remote,
  );
}

void main() {
  group('DivanController — loading', () {
    test('initialize loads notebooks, notes, tags, todos, and stats', () async {
      final built = await _build();
      await built.service.createNotebook('Work');
      await built.service.addNote(
        'Alpha',
        '- [ ] ship\n- [x] spec',
        notebookText: 'Work',
        tags: 'work',
      );

      await built.controller.refresh();

      expect(built.controller.notebooks.single.name, 'Work');
      expect(built.controller.notes.single.title, 'Alpha');
      expect(built.controller.tags, ['work']);
      expect(built.controller.todos.single.item.text, 'ship');
      expect(built.controller.stats!.notes, 1);
      expect(built.controller.stats!.openChecklistItems, 1);
      expect(
        built.controller.notebookNameOf(built.controller.notes.single),
        'Work',
      );
      expect(built.controller.undoAvailable, isTrue);
    });

    test('initialize is a no-op once the pad is loaded', () async {
      final built = await _build();
      await built.service.createNotebook('Keep');
      await built.controller.initialize();
      expect(built.controller.notebooks.single.name, 'Keep');

      await built.service.createNotebook('Second');
      await built.controller.initialize();
      expect(
        built.controller.notebooks,
        hasLength(1),
        reason: 'a loaded pad is not re-read by initialize',
      );

      await built.controller.refresh();
      expect(built.controller.notebooks, hasLength(2));
    });
  });

  group('DivanController — filters', () {
    test(
      'notebook, tag, query, pinned, archived, and checklist filters',
      () async {
        final built = await _build();
        final controller = built.controller;
        await built.service.createNotebook('Work');
        await built.service.createNotebook('Home');
        final ship = await built.service.addNote(
          'Ship it',
          '- [ ] deploy',
          notebookText: 'Work',
          tags: 'work,release',
        );
        await built.service.addNote('Buy milk', 'notes', notebookText: 'Home');
        await built.service.pin(ship.id, true);

        await controller.setNotebookFilter(1);
        expect(controller.notes.single.title, 'Ship it');

        await controller.setNotebookFilter(null);
        await controller.setTagFilter('release');
        expect(controller.notes.single.title, 'Ship it');

        await controller.setTagFilter(null);
        await controller.setQuery('milk');
        expect(controller.notes.single.title, 'Buy milk');

        await controller.setQuery('');
        await controller.setPinnedOnly(true);
        expect(controller.notes.single.title, 'Ship it');

        await controller.setPinnedOnly(false);
        await controller.setChecklistsOnly(true);
        expect(controller.notes.single.title, 'Ship it');
        expect(controller.hasFilters, isTrue);

        await controller.setChecklistsOnly(false);
        await controller.setArchivedOnly(true);
        expect(controller.notes, isEmpty);

        await controller.clearFilters();
        expect(controller.notes, hasLength(2));
        expect(controller.hasFilters, isFalse);
      },
    );

    test('a blank tag filter clears itself', () async {
      final built = await _build();
      await built.controller.setTagFilter('  ');
      expect(built.controller.tagFilter, isNull);
    });
  });

  group('DivanController — notes', () {
    test('addNote lands in the configured default notebook', () async {
      final built = await _build();
      await built.service.createNotebook('Journalish');
      await built.settings.set(SettingKeys.divanNotebook, 'Journalish');

      final note = await built.controller.addNote(title: 'Hello', body: 'Body');

      expect(note, isNotNull);
      expect(built.controller.notebookNameOf(note!), 'Journalish');
      expect(built.controller.selected?.id, note.id);
      expect(built.controller.message, 'Note added.');
    });

    test('addNote falls back to the store default and Untitled', () async {
      final built = await _build();
      final note = await built.controller.addNote();
      expect(note!.title, 'Untitled');
      expect((await built.service.resolveNotebook(null)).id, note.notebookId);
    });

    test('saveNote keeps the selection and reports the message', () async {
      final built = await _build();
      final note = await built.controller.addNote(title: 'Draft', body: 'one');

      await built.controller.saveNote(note!.id, body: 'two', tags: 'a');

      expect(built.controller.selected!.body, 'two');
      expect(built.controller.selected!.tags, 'a');
      expect(built.controller.message, 'Note saved.');
      expect(built.controller.metrics!.words, 1);
    });

    test(
      'append, move, pin, archive, and delete keep the panes in step',
      () async {
        final built = await _build();
        final controller = built.controller;
        await built.service.createNotebook('Target');
        final note = await controller.addNote(title: 'Note', body: 'one');

        await controller.appendToNote(note!.id, 'two');
        expect(controller.selected!.body, 'one\ntwo');

        await controller.moveNote(note.id, 1);
        expect(controller.selected!.notebookId, 1);

        await controller.setPinned(note.id, true);
        expect(controller.selected!.pinned, isTrue);
        expect(controller.message, 'Note pinned.');

        await controller.setArchived(note.id, true);
        expect(controller.selected!.archived, isTrue);
        expect(
          controller.notes,
          isEmpty,
          reason: 'archived notes leave the listing',
        );

        await controller.setArchivedOnly(true);
        expect(controller.notes.single.id, note.id);

        await controller.setArchivedOnly(false);
        await controller.deleteNote(note.id);
        expect(controller.selected, isNull);
        expect(controller.metrics, isNull);
        expect(controller.backlinks, isEmpty);
      },
    );

    test(
      'toggleChecklistItem flips the box and keeps the rest of the line',
      () async {
        final built = await _build();
        final controller = built.controller;
        final note = await controller.addNote(
          title: 'List',
          body: '* [ ] first\n  - [X] second\ntext',
        );

        await controller.toggleChecklistItem(note!.id, 1);
        expect(controller.selected!.body.split('\n').first, '* [x] first');

        await controller.toggleChecklistItem(note.id, 2);
        expect(controller.selected!.body.split('\n')[1], '  - [ ] second');

        // Line 3 is not a checklist item and line 9 does not exist: both are ignored.
        final before = controller.selected!.body;
        await controller.toggleChecklistItem(note.id, 3);
        await controller.toggleChecklistItem(note.id, 9);
        expect(controller.selected!.body, before);
      },
    );

    test('deleteNote clears the editor and keeps an undo snapshot', () async {
      final built = await _build();
      final controller = built.controller;
      final note = await controller.addNote(title: 'Gone', body: 'x');

      await controller.deleteNote(note!.id);
      expect(controller.message, 'Note deleted.');
      expect(await built.service.getNote(note.id), isNull);

      expect(await controller.undo(), isTrue);
      expect((await built.service.getNote(note.id))!.title, 'Gone');
    });
  });

  group('DivanController — journal and todos', () {
    test('openJournal creates today\'s note once and selects it', () async {
      final built = await _build();
      final controller = built.controller;

      await controller.openJournal();
      final first = controller.selected!;
      expect(first.title, '2026-09-20');
      expect(controller.notebookNameOf(first), DivanDefaults.journalNotebook);
      expect(controller.message, 'Journal opened.');

      await controller.openJournal();
      expect(controller.selected!.id, first.id);
    });

    test('addTodo appends an open item to the journal', () async {
      final built = await _build();
      final controller = built.controller;

      await controller.addTodo('  call the bank  ');

      // The journal body is the date heading plus one empty box; the item lands under it.
      expect(controller.selected!.body, startsWith('# '));
      expect(controller.selected!.body, endsWith('- [ ]\n- [ ] call the bank'));
      expect(controller.todos.single.item.text, 'call the bank');
      expect(controller.message, 'Todo added to the journal.');

      // A blank entry does nothing at all.
      final before = await built.store.undoCount;
      await controller.addTodo('   ');
      expect(await built.store.undoCount, before);
    });
  });

  group('DivanController — undo and transfer', () {
    test('undo reports when the stack is empty', () async {
      final built = await _build();
      expect(await built.controller.undo(), isFalse);
      expect(built.controller.message, 'Nothing to undo.');
    });

    test('export and import move a pad through a folder', () async {
      final directory = Directory.systemTemp.createTempSync('divan-controller');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });

      final built = await _build();
      await built.controller.addNote(title: 'Alpha', body: 'body');

      expect(await built.controller.export(directory.path), 1);
      expect(built.controller.message, 'Exported 1 note(s).');
      expect(
        directory.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.md'),
        ),
        hasLength(1),
      );

      final fresh = await _build();
      expect(await fresh.controller.import(directory.path), 1);
      expect(fresh.controller.message, 'Imported 1 note(s).');
      expect(fresh.controller.notes.single.title, 'Alpha');
    });

    test('a bad folder surfaces the service sentence', () async {
      final built = await _build();
      await built.controller.import('/definitely/not/here');
      expect(built.controller.error, contains('No such folder'));
    });
  });

  group('DivanController — notebooks', () {
    test('create, rename, archive, and delete report their messages', () async {
      final built = await _build();
      final controller = built.controller;

      final created = await controller.createNotebook('Work');
      expect(controller.message, "Notebook 'Work' created.");
      expect(created!.id, 1);

      await controller.renameNotebook(1, 'Office');
      expect(controller.notebooks.single.name, 'Office');
      expect(controller.message, 'Notebook renamed.');

      await controller.setNotebookArchived(1, true);
      expect(controller.notebooks.single.isArchived, isTrue);
      expect(controller.activeNotebooks, isEmpty);

      await controller.deleteNotebook(1);
      expect(controller.notebooks, isEmpty);
    });

    test('a duplicate name becomes the error text, not a throw', () async {
      final built = await _build();
      final controller = built.controller;
      await controller.createNotebook('Work');

      await controller.createNotebook('work');

      expect(controller.error, "A notebook named 'work' already exists.");
      expect(controller.notebooks, hasLength(1));
    });

    test('a non-empty notebook needs force', () async {
      final built = await _build();
      final controller = built.controller;
      await controller.createNotebook('Work');
      await built.service.addNote('Alpha', 'x', notebookText: 'Work');

      await controller.deleteNotebook(1);
      expect(controller.error, contains('holds 1 note(s)'));

      await controller.deleteNotebook(1, force: true);
      expect(controller.error, isNull);
      expect(controller.notebooks, isEmpty);
      expect(controller.message, 'Notebook deleted with 1 note(s).');
    });
  });

  group('DivanController — AI', () {
    test('summarize sends the pad prompt and stores the answer', () async {
      String? seen;
      final built = await _build(
        httpClient: MockClient((request) async {
          seen = request.body;
          return http.Response(_completion('- one\n- two\n- three'), 200);
        }),
      );
      final note = await built.controller.addNote(title: 'Alpha', body: 'body');

      await built.controller.summarize();

      expect(built.controller.aiKind, 'summary');
      expect(built.controller.aiAnswer, '- one\n- two\n- three');
      expect(seen, contains('Summarize the note below'));
      expect(seen, contains('---NOTE BEGIN---'));
      expect(note, isNotNull);
    });

    test('proposeTags parses the model into a tag list', () async {
      final built = await _build(
        httpClient: MockClient(
          (_) async =>
              http.Response(_completion('1. Work\n2. #idea\n3. work'), 200),
        ),
      );
      await built.controller.addNote(title: 'Alpha', body: 'body');

      await built.controller.proposeTags();

      expect(built.controller.aiKind, 'tags');
      // `ParseTags` keeps the model's order and does not dedupe — `CleanTags` does that
      // when the tags reach a note, exactly like the .NET pair.
      expect(built.controller.aiTags, ['work', 'idea', 'work']);

      final note = built.controller.selected!;
      await built.controller.saveNote(
        note.id,
        tags: built.controller.aiTags.join(','),
      );
      expect(built.controller.selected!.tags, 'work,idea');
    });

    test('ask carries the question and the note excerpts', () async {
      String? seen;
      final built = await _build(
        httpClient: MockClient((request) async {
          seen = request.body;
          return http.Response(_completion('The thesis said so.'), 200);
        }),
      );
      await built.controller.addNote(title: 'Thesis', body: 'the thesis text');

      await built.controller.ask('what did I write about the thesis?');

      expect(built.controller.aiQuestion, 'what did I write about the thesis?');
      expect(built.controller.aiAnswer, 'The thesis said so.');
      expect(seen, contains('---NOTES BEGIN---'));
      expect(seen, contains('[1] Thesis'));
      expect(seen, contains('untrusted data'));
    });

    test('a note-scoped call without a selection asks for one', () async {
      final built = await _build();
      await built.controller.summarize();
      expect(built.controller.error, 'Select a note first.');
      expect(built.controller.aiAnswer, isNull);
    });

    test('no provider is reported instead of thrown', () async {
      final built = await _build(withFunnel: false);
      await built.controller.proposeTitle();
      expect(built.controller.error, 'No AI provider is configured.');
    });

    test('clearAi empties the panel', () async {
      final built = await _build();
      await built.controller.addNote(title: 'Alpha', body: 'body');
      await built.controller.summarize();
      expect(built.controller.aiAnswer, isNotNull);

      built.controller.clearAi();
      expect(built.controller.aiAnswer, isNull);
      expect(built.controller.aiKind, '');
      expect(built.controller.aiTags, isEmpty);
    });
  });

  group('DivanController — sync', () {
    test('a merge pushes the pad and stores a device identity', () async {
      final built = await _build();
      await built.settings.set(
        SettingKeys.divanSyncUrl,
        'https://example.test/pad.json',
      );
      await built.controller.addNote(title: 'Alpha', body: 'body');

      final run = await built.controller.syncNow();
      expect(run, isNotNull);
      expect(run!.firstSync, isTrue);
      expect(built.controller.lastSync, run);
      expect(built.controller.message, run.describe());
      // The envelope carries the pad as an escaped payload, so the title appears inside it.
      expect(built.remote.document, contains('Alpha'));
      expect(built.remote.document, contains('jamejam.sync/1'));
      expect(
        built.controller.notebookNameOf(built.controller.notes.single),
        'Notebook',
      );

      final deviceId = await built.settings.read(SettingKeys.syncDeviceId);
      expect(deviceId, isNotNull);
      expect(deviceId!.length, 36);
      expect(await built.settings.read(SettingKeys.syncDeviceName), 'JameJam');
    });

    test('a second merge pulls the remote changes back', () async {
      final first = await _build();
      await first.settings.set(
        SettingKeys.divanSyncUrl,
        'https://example.test/pad.json',
      );
      await first.controller.addNote(title: 'Alpha', body: 'one');
      await first.controller.syncNow();

      final second = await _build();
      await second.settings.set(
        SettingKeys.divanSyncUrl,
        'https://example.test/pad.json',
      );
      second.remote.document = first.remote.document;

      final run = await second.controller.syncNow();
      expect(run!.applied, greaterThan(0));
      expect(second.controller.notes.single.title, 'Alpha');
    });

    test('push and pull modes are honoured', () async {
      final built = await _build();
      await built.settings.set(
        SettingKeys.divanSyncUrl,
        'https://example.test/pad.json',
      );

      final pulled = await built.controller.syncNow(mode: SyncMode.pull);
      expect(pulled!.pushed, isFalse);
      expect(built.remote.document, isNull);

      await built.controller.addNote(title: 'Alpha', body: 'body');
      final pushed = await built.controller.syncNow(mode: SyncMode.push);
      expect(pushed!.pushed, isTrue);
      expect(built.remote.document, contains('Alpha'));
    });

    test('a missing URL and a missing transport are both explained', () async {
      final built = await _build(withSyncClient: false);
      await built.controller.syncNow();
      expect(
        built.controller.error,
        'Remote sync is not configured — set divan.syncUrl first.',
      );

      await built.settings.set(
        SettingKeys.divanSyncUrl,
        'https://example.test/x.json',
      );
      await built.controller.syncNow();
      expect(built.controller.error, 'Sync is not available in this context.');
      expect(built.controller.lastSync, isNull);
    });

    test('syncOptionsFor carries the environment token', () async {
      final built = await _build(
        environment: (key) => key == 'JAMEJAM_SYNC_TOKEN' ? '  s3cret  ' : '',
      );
      final options = built.controller.syncOptionsFor(
        'https://example.test/x.json',
      );
      expect(options.endpoint, 'https://example.test/x.json');
      expect(options.bearerToken, 's3cret');
    });
  });
}

/// A secret store holding one AI key.
///
/// The funnel refuses to call a non-loopback endpoint without a key — the .NET's
/// `CompleteAiRequestAsync` gate — so a fixture that wants a request on the wire needs a key,
/// exactly like the original's tests (`ApiKey = "test-key-1234"`).
Future<MemorySecretStore> _seededSecrets() async {
  final secrets = MemorySecretStore();
  await secrets.write(SecretKeys.aiApiKey, 'sk-test');
  return secrets;
}
