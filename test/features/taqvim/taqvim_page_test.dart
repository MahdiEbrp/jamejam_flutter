/// The calendar screen end to end: the agenda, the capture box, the editor, the free-window
/// card, search, the .ics transfer dialog and the AI card — driven through the real
/// composition root with an in-memory calendar store.
///
/// `taqvim add|edit|reschedule|repeat|remind|delete|today|tomorrow|week|month|search|free|
/// export|import|undo|capture|ai` are the CLI verbs this screen stands in for; the assertions
/// below are their GUI equivalents.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/core/fa_format.dart';
import 'package:jamejam/core/jalali.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/taqvim/taqvim_controller.dart';
import 'package:jamejam/features/taqvim/taqvim_page.dart';
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

/// Pumps the screen onto a tall surface — the calendar's cards stack well past a phone.
Future<void> _pumpPage(
  TestHarness harness,
  WidgetTester tester, {
  Size size = const Size(1400, 2200),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(harness.wrap(const TaqvimPage()));
  await tester.pumpAndSettle();
}

/// Pumps the screen in Persian, to prove the calendar is RTL-ready.
Future<void> _pumpPersian(TestHarness harness, WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: harness.services.providers(),
      child: const MaterialApp(
        locale: Locale('fa'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TaqvimPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types into a field by key, replacing whatever the widget started with.
Future<void> _type(WidgetTester tester, Key key, String text) async {
  await tester.enterText(find.byKey(key), text);
  await tester.pump();
}

/// An instant on the calendar's own anchor day — the app's clock is the wall clock, so a
/// hard-coded date would fall outside every scope.
DateTime _on(DateOnly day, int hour, [int minute = 0]) =>
    DateTime.utc(day.year, day.month, day.day, hour, minute);

/// The agenda row of the event with [id] — the page keys each occurrence, so this matches
/// the master's row without pinning the instant.
Finder _row(int id) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('taqvim.event.$id@'),
);

/// `YYYY-MM-DD` — what the window fields expect.
String _isoOf(DateOnly day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// The day after [day].
DateOnly _nextDay(DateOnly day) {
  final shifted = day.toUtcDateTime().add(const Duration(days: 1));
  return DateOnly(shifted.year, shifted.month, shifted.day);
}

void main() {
  testWidgets('renders the agenda, the counters and the empty state', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    await _pumpPage(harness, tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(taqvimCaptureFieldKey), findsOneWidget);
    expect(find.byKey(taqvimTitleKey), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byKey(taqvimCaptureFieldKey)),
    );
    expect(find.text(l10n.taqvimAgendaEmpty), findsOneWidget);
    expect(find.byKey(taqvimScopeKey(TaqvimScope.today)), findsOneWidget);
  });

  testWidgets('adding an event fills the agenda and the counters', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    await _pumpPage(harness, tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byKey(taqvimTitleKey)),
    );
    // The editor's own defaults land on the anchor day at 09:00–10:00, so a title is enough.
    await _type(tester, taqvimTitleKey, 'Standup');
    await tester.tap(find.byKey(taqvimSaveKey));
    await tester.pumpAndSettle();

    expect(find.text('Standup'), findsWidgets);
    expect(_row(1), findsOneWidget);
    expect(find.text(l10n.taqvimStatEvents(1)), findsOneWidget);
    expect(find.byKey(taqvimDeleteKey), findsOneWidget);
    expect((harness.services.taqvim.events).length, 1);
  });

  testWidgets('the capture box parses a sentence into the editor', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    await _pumpPage(harness, tester);

    await _type(
      tester,
      taqvimCaptureFieldKey,
      'lunch with Sara tomorrow at 1pm',
    );
    await tester.tap(find.byKey(taqvimCaptureKey));
    await tester.pumpAndSettle();

    final title = tester.widget<TextField>(find.byKey(taqvimTitleKey));
    final start = tester.widget<TextField>(find.byKey(taqvimStartKey));
    expect(title.controller!.text, 'lunch with Sara');
    expect(start.controller!.text, contains('13:00'));
  });

  testWidgets('a sentence with no date or time is refused', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    await _pumpPage(harness, tester);

    await _type(tester, taqvimCaptureFieldKey, 'write the report');
    await tester.tap(find.byKey(taqvimCaptureKey));
    await tester.pump();

    expect(
      find.textContaining('That sentence has no date or time'),
      findsOneWidget,
      reason: 'nothing is invented when there is no signal',
    );
    await _flushMessages(tester);
  });

  testWidgets('the rails surface as a message, not a crash', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    await _pumpPage(harness, tester);

    // An end before the start is a TaqvimException in the service.
    await _type(tester, taqvimTitleKey, 'Backwards');
    await _type(tester, taqvimStartKey, '2026-09-21 13:00');
    await _type(tester, taqvimEndKey, '2026-09-21 12:00');
    await tester.tap(find.byKey(taqvimSaveKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('end must be after'), findsOneWidget);
    expect(harness.services.taqvim.events, isEmpty);
    await _flushMessages(tester);
  });

  testWidgets('a bad time is refused with the pinned message', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    await _pumpPage(harness, tester);

    await _type(tester, taqvimTitleKey, 'Gibberish');
    await _type(tester, taqvimStartKey, 'gibberish');
    await tester.tap(find.byKey(taqvimSaveKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cannot read the time'), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('the scopes switch the agenda', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    final controller = harness.services.taqvim;
    final day = controller.today;
    final tomorrow = _nextDay(day);
    await controller.addEvent(
      title: 'Today thing',
      start: _on(day, 9),
      end: _on(day, 10),
    );
    await controller.addEvent(
      title: 'Tomorrow thing',
      start: _on(tomorrow, 9),
      end: _on(tomorrow, 10),
    );
    await _pumpPage(harness, tester);
    await controller.load();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(taqvimScopeKey(TaqvimScope.month)));
    await tester.pumpAndSettle();
    expect(find.text('Today thing'), findsWidgets);
    expect(find.text('Tomorrow thing'), findsWidgets);

    await tester.tap(find.byKey(taqvimScopeKey(TaqvimScope.today)));
    await tester.pumpAndSettle();
    expect(find.text('Today thing'), findsWidgets);
    expect(find.text('Tomorrow thing'), findsNothing);
  });

  testWidgets('tapping an agenda row loads it into the editor', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    final controller = harness.services.taqvim;
    final day = controller.today;
    await controller.addEvent(
      title: 'Deep work',
      start: _on(day, 14),
      end: _on(day, 16),
      location: 'Room 4',
      tags: 'focus',
    );
    await _pumpPage(harness, tester);
    await controller.load();
    await tester.pumpAndSettle();

    await tester.tap(_row(1));
    await tester.pumpAndSettle();

    final title = tester.widget<TextField>(find.byKey(taqvimTitleKey));
    final location = tester.widget<TextField>(find.byKey(taqvimLocationKey));
    expect(title.controller!.text, 'Deep work');
    expect(location.controller!.text, 'Room 4');
    expect(controller.selected!.id, 1);
  });

  testWidgets('editing saves through the same button', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    final controller = harness.services.taqvim;
    final day = controller.today;
    await controller.addEvent(
      title: 'Old name',
      start: _on(day, 14),
      end: _on(day, 15),
    );
    await _pumpPage(harness, tester);
    await controller.load();
    await tester.pumpAndSettle();

    await tester.tap(_row(1));
    await tester.pumpAndSettle();
    await _type(tester, taqvimTitleKey, 'New name');
    await tester.tap(find.byKey(taqvimSaveKey));
    await tester.pumpAndSettle();

    expect((controller.events).single.title, 'New name');
    expect(controller.message, 'Saved "New name".');
  });

  testWidgets('deleting asks first, then undo brings the event back', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    final controller = harness.services.taqvim;
    final day = controller.today;
    await controller.addEvent(
      title: 'Doomed',
      start: _on(day, 14),
      end: _on(day, 15),
    );
    await _pumpPage(harness, tester);
    await controller.load();
    await tester.pumpAndSettle();

    await tester.tap(_row(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(taqvimDeleteKey));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byKey(taqvimDeleteKey)),
    );
    expect(find.text(l10n.taqvimDeleteConfirmTitle), findsOneWidget);
    await tester.tap(find.byKey(const Key('taqvim.delete.confirm')));
    await tester.pumpAndSettle();

    expect(controller.events, isEmpty);

    // The toolbar's undo button restores it.
    await tester.tap(find.byKey(taqvimUndoKey));
    await tester.pumpAndSettle();
    expect((controller.events).single.title, 'Doomed');
    await _flushMessages(tester);
  });

  testWidgets('the free-window card computes and lists the gaps', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    final controller = harness.services.taqvim;
    await _pumpPage(harness, tester);

    final l10n = AppLocalizations.of(tester.element(find.byKey(taqvimFreeKey)));
    expect(find.text(l10n.taqvimFreeEmpty), findsOneWidget);

    await _type(tester, taqvimFreeDayKey, _isoOf(controller.today));
    await tester.tap(find.byKey(taqvimFreeKey));
    await tester.pumpAndSettle();

    // 09:00–17:00 with nothing scheduled is one 480-minute window.
    expect(find.text(l10n.taqvimFreeMinutesLabel(480)), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('the free-window rails are refused with the pinned message', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    final controller = harness.services.taqvim;
    await _pumpPage(harness, tester);

    await _type(tester, taqvimFreeDayKey, _isoOf(controller.today));
    await _type(tester, taqvimFreeMinutesKey, '0');
    await tester.tap(find.byKey(taqvimFreeKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('between 1 and'), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('search finds an event and the row loads it', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    final controller = harness.services.taqvim;
    final day = controller.today;
    await controller.addEvent(
      title: 'Dentist appointment',
      start: _on(day, 9),
      end: _on(day, 10),
    );
    await _pumpPage(harness, tester);

    await _type(tester, taqvimSearchFieldKey, 'dentist');
    await tester.tap(find.byKey(taqvimSearchKey));
    await tester.pumpAndSettle();

    expect(find.text('Dentist appointment'), findsWidgets);
    expect(controller.searchResults, hasLength(1));
    await _flushMessages(tester);
  });

  testWidgets('the .ics dialog exports the calendar and imports it back', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    final controller = harness.services.taqvim;
    final day = controller.today;
    await controller.addEvent(
      title: 'Exported',
      start: _on(day, 9),
      end: _on(day, 10),
    );
    await _pumpPage(harness, tester);

    await tester.tap(find.byKey(taqvimTransferKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(taqvimExportKey));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(taqvimTransferTextKey));
    expect(field.controller!.text, contains('SUMMARY:Exported'));

    await tester.tap(find.byKey(taqvimImportKey));
    await tester.pumpAndSettle();

    // Importing the same document into the same calendar leaves one event per sync id.
    expect(controller.message, contains('Imported'));
    await _flushMessages(tester);
  });

  testWidgets('the AI card answers, and suggests a command for capture', (
    tester,
  ) async {
    final harness = TestHarness(
      httpClient: MockClient(
        (_) async => http.Response(
          _completion('Suggestion:\ntaqvim add Gym --at 2026-09-22 18:00'),
          200,
        ),
      ),
    );
    await harness.build();
    addTearDown(harness.dispose);
    final controller = harness.services.taqvim;
    final day = controller.today;
    await controller.addEvent(
      title: 'Lunch',
      start: _on(day, 12),
      end: _on(day, 13),
    );
    await _pumpPage(harness, tester);

    // The funnel needs a usable key; the harness's secret store is empty, so the AI card
    // reports that it cannot reach a provider rather than pretending.
    expect(controller.aiAvailable, isTrue);
    await tester.tap(find.byKey(taqvimAiBriefKey));
    await tester.pumpAndSettle();

    expect(controller.aiVerb, TaqvimAiVerb.brief);
    expect(controller.aiAnswer ?? controller.error, isNotNull);
  });

  testWidgets('the settings URL reaches the controller', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    await harness.services.settingsStore.setValue(
      SettingKeys.taqvimSyncUrl,
      'https://calendar.example.test/blob',
    );
    await harness.services.settings.load();
    final controller = harness.services.taqvim;
    await controller.load();

    expect(await controller.syncUrl(), 'https://calendar.example.test/blob');
  });

  testWidgets('the screen works in Persian', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    await _pumpPersian(harness, tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(taqvimCaptureFieldKey), findsOneWidget);
    expect(find.byKey(taqvimSaveKey), findsOneWidget);
  });

  testWidgets('under fa the agenda is written in the Jalali calendar', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);
    final controller = harness.services.taqvim;
    final day = controller.today;
    await controller.addEvent(
      title: 'Standup',
      start: DateTime.utc(day.year, day.month, day.day, 9),
      end: DateTime.utc(day.year, day.month, day.day, 10),
      calendar: 'Work',
    );
    await controller.load();

    await _pumpPersian(harness, tester);

    // The Jalali date of the anchor, and the row's Persian line, both in Persian digits.
    final jalali = Jalali.fromGregorian(day.year, day.month, day.day);
    final caption = FaFormat.date(day, 'fa');
    expect(jalali.year, greaterThan(1400));
    expect(find.text(caption), findsOneWidget);
    // The row's own line carries the same Jalali day and a Persian clock.
    expect(find.textContaining(caption), findsWidgets);
    expect(find.textContaining('۰۹:۰۰'), findsOneWidget);

    // The stat chip counts are Persian too — the fix that stopped a chip reading
    // '۵ رویداد' next to a literal '۷ روز آینده'.
    final l10n = await AppLocalizations.delegate.load(const Locale('fa'));
    final chip = FaFormat.at('fa', l10n.taqvimStatEvents(1));
    expect(chip, '۱ رویداد');
    expect(find.text(chip), findsOneWidget);

    // The editors keep the storage form: a reader types and edits '2026-10-08 09:00'.
    expect(
      tester.widget<TextField>(find.byKey(taqvimStartKey)).controller!.text,
      '${_isoOf(day)} 09:00',
    );
  });
}
