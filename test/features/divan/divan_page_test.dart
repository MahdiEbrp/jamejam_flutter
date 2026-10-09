// The pad screen end to end: the three panes, the editor, the notebook dialogs, the
// checklist toggle, the journal quick-add, undo, transfer, AI, and sync — driven through the
// real composition root with an in-memory pad store.
//
// `divan add`/`divan edit`/`divan notebook`/`divan daily`/`divan todo`/`divan ai`/`divan sync`
// are the CLI verbs this screen stands in for; the assertions below are their GUI equivalents.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/divan/divan_page.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../helpers/test_harness.dart';

String _completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

/// Drains the snack-bar queue (one bar shows at a time; the rest wait for the fake clock).
Future<void> _flushMessages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }
}

/// Pumps the screen onto a surface wide enough for all three panes.
Future<void> _pumpPage(
  TestHarness harness,
  WidgetTester tester, {
  Size size = const Size(1400, 1400),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(harness.wrap(const DivanPage()));
  await tester.pumpAndSettle();
}

/// Pumps the screen in Persian, to prove the pad is RTL-ready.
Future<void> _pumpPersian(TestHarness harness, WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: harness.services.providers(),
      child: const MaterialApp(
        locale: Locale('fa'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DivanPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the header, the stats, and the empty state', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();

    await _pumpPage(harness, tester);

    expect(find.text('Divan — the notes pad'), findsOneWidget);
    expect(find.text('0 notes'), findsOneWidget);
    expect(
      find.text('Pick a note on the left, or create one.'),
      findsOneWidget,
    );
    expect(find.byKey(divanAddNoteButtonKey), findsOneWidget);
    expect(find.byKey(divanJournalButtonKey), findsOneWidget);
  });

  testWidgets('the notes column lists the pad and selection fills the editor', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final controller = harness.services.divan;
    await controller.createNotebook('Work');
    final note = await controller.addNote(
      title: 'Alpha',
      body: '- [ ] ship it',
      tags: 'work',
      notebookId: 1,
    );

    await _pumpPage(harness, tester);

    expect(find.byKey(divanNotebookTileKey(1)), findsOneWidget);
    expect(find.byKey(divanNoteTileKey(note!.id)), findsOneWidget);
    expect(find.byKey(divanAllNotebooksKey), findsOneWidget);

    await tester.tap(find.byKey(divanNoteTileKey(note.id)));
    await tester.pumpAndSettle();

    expect(controller.selected?.id, note.id);
    expect(
      find.descendant(
        of: find.byKey(divanTitleFieldKey),
        matching: find.text('Alpha'),
      ),
      findsOneWidget,
    );
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.byKey(divanChecklistItemKey(1)), findsOneWidget);
  });

  testWidgets('editing the body and saving writes through the service', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final controller = harness.services.divan;
    final note = await controller.addNote(title: 'Draft', body: 'one');

    await _pumpPage(harness, tester);
    await tester.tap(find.byKey(divanNoteTileKey(note!.id)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(divanBodyFieldKey), 'two words here');
    await tester.tap(find.byKey(divanSaveButtonKey));
    await tester.pumpAndSettle();

    expect(controller.selected!.body, 'two words here');
    expect(find.text('Note saved.'), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('the new-note dialog creates and selects a note', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final controller = harness.services.divan;
    await controller.createNotebook('Work');

    await _pumpPage(harness, tester);

    await tester.tap(find.byKey(divanAddNoteButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('divan.dialog.title')),
      'Shopping',
    );
    await tester.enterText(
      find.byKey(const Key('divan.dialog.body')),
      '- [ ] milk',
    );
    await tester.tap(find.byKey(const Key('divan.dialog.save')));
    await tester.pumpAndSettle();

    expect(controller.notes.single.title, 'Shopping');
    expect(controller.selected!.body, '- [ ] milk');
    expect(controller.todos.single.item.text, 'milk');
    expect(find.text('Note added.'), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('the notebook dialog creates a notebook', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();

    await _pumpPage(harness, tester);

    await tester.tap(find.byKey(divanAddNotebookButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('divan.dialog.name')), 'Work');
    await tester.tap(find.byKey(const Key('divan.dialog.name.save')));
    await tester.pumpAndSettle();

    expect(harness.services.divan.notebooks.single.name, 'Work');
    expect(find.byKey(divanNotebookTileKey(1)), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('the pinned chip narrows the listing', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final controller = harness.services.divan;
    final pinned = await controller.addNote(title: 'Pinned one', body: 'x');
    await controller.setPinned(pinned!.id, true);
    final loose = await controller.addNote(title: 'Loose one', body: 'y');

    await _pumpPage(harness, tester);
    expect(find.byKey(divanNoteTileKey(loose!.id)), findsOneWidget);

    await tester.tap(find.byKey(divanPinnedFilterKey));
    await tester.pumpAndSettle();

    expect(controller.pinnedOnly, isTrue);
    expect(find.byKey(divanNoteTileKey(pinned.id)), findsOneWidget);
    expect(find.byKey(divanNoteTileKey(loose.id)), findsNothing);

    await tester.tap(find.byKey(divanClearFiltersKey));
    await tester.pumpAndSettle();
    expect(controller.hasFilters, isFalse);
  });

  testWidgets('the journal button opens today\'s note', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();

    await _pumpPage(harness, tester);

    await tester.tap(find.byKey(divanJournalButtonKey));
    await tester.pumpAndSettle();

    final controller = harness.services.divan;
    expect(controller.selected, isNotNull);
    expect(controller.selected!.body, startsWith('# '));
    expect(find.text('Journal opened.'), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('the quick add sends an item to the journal', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();

    await _pumpPage(harness, tester);

    await tester.enterText(find.byKey(divanTodoFieldKey), 'call the bank');
    await tester.tap(find.byKey(divanTodoAddButtonKey));
    await tester.pumpAndSettle();
    await _flushMessages(tester);

    expect(harness.services.divan.todos.single.item.text, 'call the bank');
    expect(find.text('call the bank'), findsWidgets);
  });

  testWidgets('a checklist box toggles from the editor', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final controller = harness.services.divan;
    final note = await controller.addNote(
      title: 'List',
      body: '- [ ] first\n- [ ] second',
    );

    await _pumpPage(harness, tester);
    await tester.tap(find.byKey(divanNoteTileKey(note!.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(divanChecklistItemKey(1)));
    await tester.pumpAndSettle();

    expect(controller.selected!.body.split('\n').first, '- [x] first');
    expect(
      controller.todos.single.item.text,
      'second',
      reason: 'the checked item left the todos list',
    );
  });

  testWidgets('undo restores the last change and then goes quiet', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final controller = harness.services.divan;
    await controller.addNote(title: 'Alpha', body: 'x');

    await _pumpPage(harness, tester);
    expect(
      tester.widget<IconButton>(find.byKey(divanUndoButtonKey)).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(divanUndoButtonKey));
    await tester.pumpAndSettle();

    expect(controller.notes, isEmpty);
    expect(find.text('Last undone.'), findsNothing);
    expect(find.text('Last change undone.'), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('the AI card summarizes the selected note', (tester) async {
    final harness = TestHarness(
      httpClient: MockClient(
        (_) async => http.Response(_completion('- one\n- two\n- three'), 200),
      ),
    );
    addTearDown(harness.dispose);
    await harness.build();
    await harness.secretStore.write(SecretKeys.aiApiKey, 'sk-test');
    final controller = harness.services.divan;
    final note = await controller.addNote(title: 'Alpha', body: 'body text');

    await _pumpPage(harness, tester);
    await tester.tap(find.byKey(divanNoteTileKey(note!.id)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(divanAiSummarizeKey));
    await tester.tap(find.byKey(divanAiSummarizeKey));
    await tester.pumpAndSettle();

    expect(controller.aiAnswer, '- one\n- two\n- three');
    expect(find.text('- one\n- two\n- three'), findsOneWidget);
  });

  testWidgets('the AI buttons wait for a selection', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    await harness.services.divan.addNote(title: 'Alpha', body: 'x');
    // Nothing is selected: the pad starts on the listing, not on the first note.
    await harness.services.divan.select(null);

    await _pumpPage(harness, tester);

    expect(
      tester.widget<OutlinedButton>(find.byKey(divanAiSummarizeKey)).onPressed,
      isNull,
    );
    await harness.services.divan.select(1);
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(find.byKey(divanAiSummarizeKey)).onPressed,
      isNotNull,
    );
  });

  testWidgets('the transfer dialog exports markdown into the typed folder', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('divan-page-export');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    await harness.services.divan.addNote(title: 'Alpha', body: 'body');

    await _pumpPage(harness, tester);

    await tester.tap(find.byKey(divanTransferButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(divanTransferFieldKey), directory.path);
    await tester.tap(find.byKey(const Key('divan.transfer.export')));
    await tester.pumpAndSettle();

    expect(
      directory.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.md'),
      ),
      hasLength(1),
    );
    expect(find.text('Exported 1 note(s).'), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('the sync dialog runs a first sync against the remote', (
    tester,
  ) async {
    final harness = TestHarness(
      httpClient: MockClient((request) async {
        if (request.method == 'GET') return http.Response('', 404);
        return http.Response('', 200);
      }),
    );
    addTearDown(harness.dispose);
    await harness.build();
    await harness.services.settings.set(
      SettingKeys.divanSyncUrl,
      'https://example.test/pad.json',
    );
    await harness.services.divan.addNote(title: 'Alpha', body: 'body');

    await _pumpPage(harness, tester);

    await tester.tap(find.byKey(divanSyncButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('divan.sync.merge')));
    await tester.pumpAndSettle();

    final run = harness.services.divan.lastSync;
    expect(run, isNotNull);
    expect(run!.firstSync, isTrue);
    // Once in the snack bar, once in the tools pane's sync line.
    expect(find.textContaining('First sync'), findsWidgets);
    await _flushMessages(tester);
  });

  testWidgets('a narrow window falls back to tabs', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();

    await _pumpPage(harness, tester, size: const Size(700, 1000));

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Notes'), findsWidgets);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
  });

  testWidgets('the pad renders in Persian and right to left', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();

    await _pumpPersian(harness, tester);

    expect(find.text('دیوان — دفتر یادداشت‌ها'), findsOneWidget);
    expect(find.text('یادداشت تازه'), findsOneWidget);
    final direction = Directionality.of(
      tester.element(find.byKey(divanAddNoteButtonKey)),
    );
    expect(direction, TextDirection.rtl);
  });

  testWidgets('a service error renders the error card', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final controller = harness.services.divan;
    await controller.createNotebook('Work');

    await _pumpPage(harness, tester);

    await controller.createNotebook('work');
    await tester.pumpAndSettle();

    expect(
      find.text("A notebook named 'work' already exists."),
      findsOneWidget,
    );
    expect(find.text('Dismiss'), findsOneWidget);
  });
}
