// The Haft Khan screen, driven the way a user drives it: dialogs, row buttons, filters.
//
// The controller is the real one from [AppServices] (over an in-memory SQLite store), and the
// only two things stubbed are the ones the app can't own in a test — the keychain and HTTP.
// That keeps this suite honest about the widget → controller → engine → SQL path.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/haftkhan/haftkhan_controller.dart';
import 'package:jamejam/features/haftkhan/haftkhan_page.dart';
import 'package:jamejam/features/haftkhan/models.dart';
import 'package:jamejam/features/haftkhan/task_repository.dart';

import '../../helpers/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestHarness harness;
  late HaftKhanController controller;
  late List<String> prompts;
  var aiAnswer = 'Focus: finish the toolbox';

  String completion(String content) => jsonEncode({
    'choices': [
      {
        'message': {'content': content},
      },
    ],
  });

  setUp(() async {
    prompts = [];
    final secrets = MemorySecretStore();
    await secrets.write(SecretKeys.aiApiKey, 'sk-test');

    harness = TestHarness(
      secretStore: secrets,
      taskRepository: MemoryTaskRepository(),
      httpClient: MockClient((request) async {
        prompts.add(request.body);
        return http.Response(completion(aiAnswer), 200);
      }),
    );
    await harness.build();
    controller = harness.services.haftKhan;
  });

  tearDown(() => harness.dispose());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness.wrap(const HaftKhanPage()));
    await tester.pumpAndSettle();
  }

  group('the list', () {
    testWidgets('shows the empty view when nothing is stored', (tester) async {
      await pumpPage(tester);

      expect(find.text('No tasks in this view.'), findsOneWidget);
      expect(find.text('Slay the dragon'), findsNothing);
    });

    testWidgets('adds a task through the dialog and shows its metadata', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.byKey(haftKhanAddButtonKey));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(haftKhanTitleFieldKey),
        'Slay the dragon',
      );
      await tester.enterText(find.byKey(haftKhanDueFieldKey), '2020-01-01');
      await tester.tap(find.byKey(haftKhanSubmitButtonKey));
      await tester.pumpAndSettle();

      final stored = await harness.services.taskRepository.listAll();
      expect(stored.map((task) => task.title), ['Slay the dragon']);
      expect(stored.single.dueDate?.toIso(), '2020-01-01');
      expect(find.text('Slay the dragon'), findsOneWidget);
      expect(find.text('overdue'), findsOneWidget);
    });

    testWidgets('a guard rejection reaches the user and stores nothing', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.byKey(haftKhanAddButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(haftKhanTitleFieldKey), 'Malformed');
      await tester.enterText(find.byKey(haftKhanDueFieldKey), 'not-a-date');
      await tester.tap(find.byKey(haftKhanSubmitButtonKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('invalid date'), findsOneWidget);
      expect(find.byKey(haftKhanTitleFieldKey), findsOneWidget); // dialog stays
      expect(await harness.services.taskRepository.listAll(), isEmpty);
    });

    testWidgets('start and conquer run from the row button', (tester) async {
      final task = await controller.addTask(title: 'labour');
      await pumpPage(tester);

      expect(find.text('labour'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('haftkhan-state-${task.id}')));
      await tester.pumpAndSettle();
      expect(
        (await harness.services.taskRepository.find(task.id))!.state,
        TaskState.doing,
      );

      await tester.tap(find.byKey(ValueKey('haftkhan-state-${task.id}')));
      await tester.pumpAndSettle();
      expect(
        (await harness.services.taskRepository.find(task.id))!.state,
        TaskState.done,
      );
      // the open view no longer lists it
      expect(find.text('labour'), findsNothing);
    });

    testWidgets('undo brings a conquered task back', (tester) async {
      final task = await controller.addTask(title: 'labour');
      await controller.complete(task.id);
      await pumpPage(tester);

      await tester.tap(find.byKey(haftKhanUndoButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('labour'), findsOneWidget);
      expect(
        (await harness.services.taskRepository.find(task.id))!.state,
        TaskState.todo,
      );
    });

    testWidgets('removing asks for confirmation first', (tester) async {
      final task = await controller.addTask(title: 'labour');
      await pumpPage(tester);

      await tester.tap(find.byKey(ValueKey('haftkhan-menu-${task.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Remove #${task.id}'), findsOneWidget);

      await tester.tap(find.byKey(haftKhanConfirmButtonKey));
      await tester.pumpAndSettle();

      expect(await harness.services.taskRepository.find(task.id), isNull);
    });

    testWidgets('backing out of the confirmation keeps the task', (
      tester,
    ) async {
      final task = await controller.addTask(title: 'labour');
      await pumpPage(tester);

      await tester.tap(find.byKey(ValueKey('haftkhan-menu-${task.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('labour'), findsOneWidget);
      expect(await harness.services.taskRepository.find(task.id), isNotNull);
    });
  });

  group('views and filters', () {
    testWidgets('search narrows the list', (tester) async {
      await controller.addTask(title: 'Slay the dragon');
      await controller.addTask(title: 'Buy bread');
      await pumpPage(tester);

      await tester.enterText(find.byKey(haftKhanSearchFieldKey), 'bread');
      await tester.pumpAndSettle();

      expect(find.text('Buy bread'), findsOneWidget);
      expect(find.text('Slay the dragon'), findsNothing);

      await controller.clearFilters();
      await tester.pumpAndSettle();
      expect(find.text('Slay the dragon'), findsOneWidget);
    });

    testWidgets('the overdue view shows only what is late', (tester) async {
      await controller.addTask(title: 'late', dueDateText: '2020-01-01');
      await controller.addTask(title: 'soon', dueDateText: '2999-01-01');
      await pumpPage(tester);

      await tester.tap(find.text('Overdue'));
      await tester.pumpAndSettle();

      expect(find.text('late'), findsOneWidget);
      expect(find.text('soon'), findsNothing);
    });

    testWidgets('the priority filter narrows the list', (tester) async {
      await controller.addTask(title: 'urgent', priorityName: 'critical');
      await controller.addTask(title: 'plain');
      await pumpPage(tester);

      await tester.tap(find.byKey(haftKhanPriorityFilterKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('critical').last);
      await tester.pumpAndSettle();

      expect(find.text('urgent'), findsOneWidget);
      expect(find.text('plain'), findsNothing);
    });

    testWidgets('the board tab renders the three columns', (tester) async {
      await controller.addTask(title: 'a labour');
      await pumpPage(tester);

      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      expect(find.text('TODO'), findsOneWidget);
      expect(find.text('DOING'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('a labour'), findsOneWidget);
    });

    testWidgets('the report tab counts and the matrix tab places', (
      tester,
    ) async {
      final urgent = await controller.addTask(
        title: 'urgent thing',
        priorityName: 'critical',
        dueDateText: controller.service
            .today()
            .toIso(), // urgent *and* important
      );
      final finished = await controller.addTask(title: 'finished labour');
      await controller.complete(
        finished.id,
      ); // gives the streak something to report
      await pumpPage(tester);

      await tester.tap(find.text('Matrix'));
      await tester.pumpAndSettle();
      expect(controller.tab, HaftKhanTab.matrix);
      expect(
        controller.matrix.map((quadrant) => quadrant.title),
        contains('DO NOW — urgent + important'),
      );
      expect(find.text('#${urgent.id} urgent thing'), findsOneWidget);

      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      // the toolbar carries the same streak line as the report tab
      expect(find.textContaining('Streak'), findsWidgets);
      expect(find.textContaining('conquered today'), findsWidgets);
    });
  });

  group('the AI path', () {
    testWidgets(
      'the summary button sends the open tasks and shows the answer',
      (tester) async {
        aiAnswer = 'Focus: finish the toolbox';
        await controller.addTask(title: 'a labour');
        await pumpPage(tester);

        await tester.tap(find.text('Summarise with AI'));
        await tester.pumpAndSettle();

        expect(find.text('Focus: finish the toolbox'), findsOneWidget);
        expect(prompts.single, contains('#1 [normal] a labour'));
        expect(prompts.single, contains('untrusted data'));
      },
    );

    testWidgets('the breakdown menu item shows the parsed plan', (
      tester,
    ) async {
      aiAnswer = '1. Sharpen the sword\n2. Pack the shield';
      final task = await controller.addTask(title: 'Slay the dragon');
      await pumpPage(tester);

      await tester.tap(find.byKey(ValueKey('haftkhan-menu-${task.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Break down with AI'));
      await tester.pumpAndSettle();

      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      final text = (snack.content as Text).data!;
      expect(text, contains('Plan for #${task.id}'));
      expect(text, contains('Sharpen the sword'));
      expect(prompts.single, contains('---TASK BEGIN---'));
    });

    testWidgets('a summary with nothing open never calls the model', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text('Summarise with AI'));
      await tester.pumpAndSettle();

      expect(prompts, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('transfer', () {
    testWidgets('export copies a backup and reports the task count', (
      tester,
    ) async {
      await controller.addTask(title: 'seen');
      await pumpPage(tester);

      await tester.tap(find.text('Import / export'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(haftKhanExportButtonKey));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(haftKhanTransferFieldKey),
      );
      expect(field.controller!.text, contains('"version"'));
      expect(field.controller!.text, contains('seen'));
    });

    testWidgets('importing a bad payload reports it without crashing', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text('Import / export'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(haftKhanTransferFieldKey),
        'backup.txt',
      );
      await tester.tap(find.byKey(haftKhanImportButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget); // still open
      expect(await harness.services.taskRepository.listAll(), isEmpty);
    });
  });
}
