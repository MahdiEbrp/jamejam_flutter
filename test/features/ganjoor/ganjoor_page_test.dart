// The wallet screen end to end: the three panes, the quick-add form, the account dialogs,
// the budget rings, undo, the backup/CSV dialog, and the AI card — driven through the real
// composition root with an in-memory wallet store.
//
// `ganjoor account|spend|earn|transfer|list|budget|bill|goal|debt|undo|export|import|ai` are
// the CLI verbs this screen stands in for; the assertions below are their GUI equivalents.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/ganjoor/ganjoor_page.dart';
import 'package:jamejam/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../helpers/test_harness.dart';

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
  Size size = const Size(1500, 1400),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(harness.wrap(const GanjoorPage()));
  await tester.pumpAndSettle();
}

/// Pumps the screen in Persian, to prove the wallet is RTL-ready.
Future<void> _pumpPersian(TestHarness harness, WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1500, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: harness.services.providers(),
      child: const MaterialApp(
        locale: Locale('fa'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: GanjoorPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the header, the empty states, and the AI card', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();

    await _pumpPage(harness, tester);

    expect(find.text('Ganjoor — wallet'), findsOneWidget);
    expect(find.text('Total: 0.00 USD'), findsOneWidget);
    expect(find.text('No accounts yet — add one to start.'), findsOneWidget);
    expect(find.text('No transactions match.'), findsOneWidget);
    expect(find.text('No budgets set.'), findsOneWidget);
    expect(find.text('No goals yet.'), findsOneWidget);
    expect(find.text('No debts tracked.'), findsOneWidget);
    expect(find.text('Finance assistant'), findsOneWidget);
    expect(find.byKey(ganjoorQuickAddKey), findsOneWidget);
  });

  testWidgets('lists accounts, balances, and ledger rows', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final wallet = harness.services.ganjoor;
    await wallet.addAccount('Bank', initialBalance: '100');
    await wallet.spend('Bank', '30', 'food', notes: 'soup');

    await _pumpPage(harness, tester);

    expect(find.text('Bank'), findsWidgets);
    expect(find.text('70.00 USD'), findsOneWidget);
    expect(find.text('Total: 70.00 USD'), findsOneWidget);
    expect(find.byKey(ganjoorTransactionTileKey(1)), findsOneWidget);
    expect(find.textContaining('−30.00 · food'), findsOneWidget);
    expect(find.textContaining('soup'), findsOneWidget);
    expect(find.text('1 shown'), findsOneWidget);
  });

  testWidgets('the quick-add form records a spend', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final wallet = harness.services.ganjoor;
    await wallet.addAccount('Bank', initialBalance: '100');

    await _pumpPage(harness, tester);

    await tester.enterText(find.byKey(ganjoorQuickAmountKey), '12.50');
    await tester.enterText(find.byKey(ganjoorQuickCategoryKey), 'coffee');
    await tester.enterText(find.byKey(ganjoorQuickNotesKey), 'espresso');
    await tester.tap(find.byKey(ganjoorQuickAddKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('−12.50 · coffee'), findsOneWidget);
    expect(find.text('87.50 USD'), findsOneWidget);
    // The form clears after a successful add.
    expect(
      tester
          .widget<TextField>(find.byKey(ganjoorQuickAmountKey))
          .controller!
          .text,
      isEmpty,
    );
    await _flushMessages(tester);
  });

  testWidgets('a budgeted spend warns in the ledger message', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final wallet = harness.services.ganjoor;
    await wallet.addAccount('Bank', initialBalance: '100');
    await wallet.setBudget('food', '50');

    await _pumpPage(harness, tester);
    await tester.enterText(find.byKey(ganjoorQuickAmountKey), '45');
    await tester.enterText(find.byKey(ganjoorQuickCategoryKey), 'food');
    await tester.tap(find.byKey(ganjoorQuickAddKey));
    await tester.pumpAndSettle();

    // 90% — the CLI printed `⚠ Budget check`, the ring shows the same threshold.
    expect(find.text('90%'), findsWidgets);
    expect(find.textContaining('close to the limit'), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('the account dialog creates an account', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();

    await _pumpPage(harness, tester);

    await tester.tap(find.byKey(ganjoorAddAccountKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ganjoorAccountNameKey), 'Cash');
    await tester.enterText(find.byKey(ganjoorAccountCurrencyKey), 'eur');
    await tester.enterText(find.byKey(ganjoorAccountStartKey), '25');
    await tester.tap(find.byKey(ganjoorAccountSaveKey));
    await tester.pumpAndSettle();

    expect(find.byKey(ganjoorAccountTileKey(1)), findsOneWidget);
    expect(find.text('EUR'), findsWidgets);
    // EUR cannot be totalled without a rate, exactly as `ganjoor networth` refused to.
    expect(find.text('Total: —'), findsOneWidget);
    expect(find.textContaining('No exchange rate for EUR'), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('the account menu renames and force-removes', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final wallet = harness.services.ganjoor;
    await wallet.addAccount('Card');
    await wallet.spend('Card', '9', 'food');

    await _pumpPage(harness, tester);

    // A non-empty account is guarded: the first attempt explains, the second sweeps.
    await tester.tap(find.byKey(ganjoorAccountMenuKey(1)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await _flushMessages(tester);

    expect(find.byKey(ganjoorAccountTileKey(1)), findsOneWidget);
    expect(find.textContaining('--force'), findsWidgets);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await _flushMessages(tester);

    expect(find.byKey(ganjoorAccountTileKey(1)), findsNothing);
    expect(find.text('No accounts yet — add one to start.'), findsOneWidget);
  });

  testWidgets('undo is off until there is something to undo', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();

    await _pumpPage(harness, tester);
    expect(
      tester.widget<FilledButton>(find.byKey(ganjoorUndoKey)).onPressed,
      isNull,
    );

    final wallet = harness.services.ganjoor;
    await wallet.addAccount('Bank');
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(ganjoorUndoKey)).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(ganjoorUndoKey));
    await tester.pumpAndSettle();
    await _flushMessages(tester);

    expect(find.text('No accounts yet — add one to start.'), findsOneWidget);
  });

  testWidgets('the backup dialog exports JSON and CSV to typed paths', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('ganjoor-page-io');
    addTearDown(() => directory.deleteSync(recursive: true));
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final wallet = harness.services.ganjoor;
    await wallet.addAccount('Bank', initialBalance: '100');
    await wallet.spend('Bank', '10', 'food', notes: 'soup');

    await _pumpPage(harness, tester);

    final jsonPath = '${directory.path}/wallet.json';
    await tester.tap(find.byKey(ganjoorTransferKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ganjoorTransferPathKey), jsonPath);
    await tester.tap(find.byKey(ganjoorExportJsonKey));
    await tester.pumpAndSettle();

    expect(File(jsonPath).readAsStringSync(), contains('"version": 1'));
    expect(find.textContaining('Exported to $jsonPath'), findsOneWidget);
    await _flushMessages(tester);

    final csvPath = '${directory.path}/ledger.csv';
    await tester.tap(find.byKey(ganjoorTransferKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ganjoorTransferPathKey), csvPath);
    await tester.tap(find.byKey(ganjoorExportCsvKey));
    await tester.pumpAndSettle();

    expect(File(csvPath).readAsStringSync(), contains('soup,-10.00'));
    expect(
      find.textContaining('Exported 1 row(s) to $csvPath'),
      findsOneWidget,
    );
    await _flushMessages(tester);
  });

  testWidgets('the CSV import needs an account picked in the dialog', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('ganjoor-page-csv');
    addTearDown(() => directory.deleteSync(recursive: true));
    final statement = File('${directory.path}/statement.csv')
      ..writeAsStringSync(
        ['Date,Description,Amount', '2026-09-02,Coffee,-4.80'].join('\n'),
      );
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    await harness.services.ganjoor.addAccount('Bank');

    await _pumpPage(harness, tester);

    // Without a target account the import is refused before the file is even read.
    await tester.tap(find.byKey(ganjoorTransferKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ganjoorTransferPathKey), statement.path);
    await tester.tap(find.byKey(ganjoorImportCsvKey));
    await tester.pumpAndSettle();

    // The error card and the snack bar both carry it.
    expect(find.textContaining('target account'), findsWidgets);
    expect(harness.services.ganjoor.transactions, isEmpty);
    await _flushMessages(tester);

    // With one, the same file lands in the ledger.
    await tester.tap(find.byKey(ganjoorTransferKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ganjoorTransferPathKey), statement.path);
    await tester.enterText(find.byKey(ganjoorCsvAccountKey), 'Bank');
    await tester.tap(find.byKey(ganjoorImportCsvKey));
    await tester.pumpAndSettle();

    expect(find.text('Imported 1 row(s), skipped 0.'), findsOneWidget);
    expect(find.textContaining('−4.80 · imported'), findsOneWidget);
    await _flushMessages(tester);
  });

  testWidgets('deleting a transaction from its row leaves the ledger empty', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final wallet = harness.services.ganjoor;
    await wallet.addAccount('Bank');
    await wallet.spend('Bank', '5', 'food');

    await _pumpPage(harness, tester);

    await tester.tap(find.byKey(ganjoorTransactionDeleteKey(1)));
    await tester.pumpAndSettle();
    await _flushMessages(tester);

    expect(find.byKey(ganjoorTransactionTileKey(1)), findsNothing);
    expect(find.text('No transactions match.'), findsOneWidget);
  });

  testWidgets('a goal inside the rail shows the nearly-done flag', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final wallet = harness.services.ganjoor;
    await wallet.addGoal('Laptop', '100', deadline: '2026-12-31');
    await wallet.contribute(1, '95');

    await _pumpPage(harness, tester);

    expect(find.byKey(ganjoorGoalTileKey(1)), findsOneWidget);
    expect(find.textContaining('95%'), findsWidgets);
    expect(find.textContaining('almost there'), findsOneWidget);
    // The wallet writes dates the way the reader's locale does, like every other surface in
    // the port: `31 Dec 2026` in English, `۱۰ دی ۱۴۰۵` in Persian.
    expect(find.textContaining('by 31 Dec 2026'), findsOneWidget);
  });

  testWidgets('the wallet renders in Persian', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    await harness.services.ganjoor.addAccount('بانک', initialBalance: '10');

    await _pumpPersian(harness, tester);

    expect(find.text('گنجور — کیف پول'), findsOneWidget);
    expect(find.textContaining('مجموع'), findsOneWidget);
    expect(find.text('بودجه‌ها'), findsWidgets);
    expect(find.byKey(ganjoorAccountTileKey(1)), findsOneWidget);
  });
}
