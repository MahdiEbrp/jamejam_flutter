import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/ganjoor/ganjoor_defaults.dart';
import 'package:jamejam/features/ganjoor/ganjoor_options.dart';
import 'package:jamejam/features/ganjoor/ganjoor_service.dart';
import 'package:jamejam/features/ganjoor/ganjoor_store.dart';
import 'package:jamejam/features/ganjoor/models.dart';
import 'package:jamejam/features/ganjoor/money.dart';

/// Port of `tests/JameJam.Tests/Ganjoor/GanjoorBranchGapTests.cs` and the service-level
/// cases of `GanjoorCoverageTests.cs` (bill intervals, report summaries, bare-verb
/// defaults, the defaults rails, the month filter, and the CSV pipeline).
///
/// The CLI-shaped half of those files lives on the screen now: usage text and exit codes
/// became the controller's messages (`ganjoor_controller_test.dart`) and the page's dialogs
/// (`ganjoor_page_test.dart`).
void main() {
  DateTime clock() => DateTime.utc(2026, 9, 19, 10);

  GanjoorService newService([
    GanjoorOptions options = const GanjoorOptions(),
  ]) => GanjoorService(
    store: MemoryGanjoorStore(),
    clock: clock,
    options: options,
  );

  // ── Bill intervals ──

  test('BillInterval_MustBeBetweenOneAnd365', () async {
    final service = newService();
    await service.addAccount('Bank', 'USD');

    expect(
      (await service.addBill(
        'Water',
        '10',
        'out',
        'utilities',
        'weekly',
        intervalText: '2',
      )).interval,
      2,
    );
    for (final interval in ['0', '366', 'soon']) {
      expect(
        () => service.addBill(
          'X',
          '10',
          'out',
          'c',
          'weekly',
          intervalText: interval,
        ),
        throwsArgumentError,
        reason: 'interval $interval is outside the rail',
      );
    }
  });

  test('BillInterval advances the schedule by the interval', () async {
    final service = newService();
    final id = (await service.addAccount('Bank', 'USD', '5000')).id;
    await service.addBill(
      'Water',
      '10',
      'out',
      'utilities',
      'weekly',
      intervalText: '2',
      nextText: '2026-09-01',
      accountText: '$id',
    );

    final result = await service.applyDueBills();
    expect(result.transactions.map((t) => t.date), [
      DateOnly(2026, 9, 1),
      DateOnly(2026, 9, 15),
    ]);
    expect(result.transactions.map((t) => t.amount.formatAmount()), [
      '10.00',
      '10.00',
    ]);
    expect(result.transactions.first.category, 'utilities');

    final bill = (await service.store.listBills()).single;
    expect(bill.nextDue, DateOnly(2026, 9, 29)); // 15 → +2 weeks
    expect(bill.frequency, GanjoorFrequency.weekly);
    expect(bill.interval, 2);
  });

  // ── Report summaries ──

  test('Report_ShowsOverBudget_AndBillsAwaitingApply', () async {
    final service = newService();
    final id = (await service.addAccount('Bank', 'USD', '5000')).id;
    await service.setBudget('food', '50');
    await service.record('$id', '60', 'food', false);
    await service.addBill(
      'Rent',
      '950',
      'out',
      'housing',
      'monthly',
      nextText: '2026-09-01',
    );

    final statuses = await service.budgetStatuses();
    final over = [
      for (final status in statuses)
        if (status.over) status,
    ];
    expect(over.single.category, 'food');
    expect(over.single.spent, Money.parse('60'));
    expect(over.single.limit, Money.parse('50'));

    expect(await service.dueBills(), hasLength(1));
  });

  test('budget warn threshold is the documented percent', () async {
    expect(GanjoorDefaults.budgetWarnPercent, 80);
    final service = newService();
    final id = (await service.addAccount('Bank', 'USD')).id;
    await service.setBudget('food', '100');
    await service.record('$id', '79', 'food', false);
    expect((await service.budgetStatuses()).single.percentUsed, 79);
    expect((await service.budgetStatuses()).single.over, isFalse);

    await service.record('$id', '1', 'food', false);
    expect((await service.budgetStatuses()).single.percentUsed, 80);
  });

  // ── Bare verbs default to list ──

  test('BareVerbs_DefaultToList', () async {
    final service = newService();
    expect(await service.accounts(), isEmpty);
    expect(await service.transactions(), isEmpty);
    expect(await service.store.listBudgets(), isEmpty);
    expect(await service.store.listBills(), isEmpty);
    expect(await service.goals(), isEmpty);
    expect(await service.debts(), isEmpty);
  });

  // ── Defaults sanity (executes the constant rail initializer) ──

  test('Defaults_ExposeSaneRails', () {
    expect(GanjoorDefaults.minAmount, Money.parse('0.01'));
    expect(GanjoorDefaults.maxAmount, Money.parse('1000000000'));
    expect(GanjoorDefaults.undoDepth, 20);
    expect(GanjoorDefaults.undoDepthBound, 100);
    expect(GanjoorDefaults.minAmount < GanjoorDefaults.maxAmount, isTrue);
    expect(GanjoorDefaults.billMaxCatchUp, 100);
    expect(GanjoorDefaults.goalNearlyDonePercent, 90);
    expect(GanjoorDefaults.topCategories, 8);
    expect(GanjoorDefaults.billHorizonDays, 7);
  });

  // ── List month filter ──

  test('List_MonthFilter_NarrowsToTheMonth', () async {
    final service = newService();
    await service.addAccount('Bank', 'USD');
    await service.record('Bank', '5', 'food', false, date: '2026-08-02');
    await service.record('Bank', '7', 'food', false);

    final august = await service.transactions(
      const GanjoorFilter(month: DateOnly(2026, 8, 1)),
    );
    expect(august, hasLength(1));
    expect(august.single.date.toIso(), '2026-08-02');
  });

  test('filters compose: account, kind, category, tag, and text', () async {
    final service = newService();
    final a = (await service.addAccount('Bank', 'USD')).id;
    final b = (await service.addAccount('Cash', 'USD')).id;
    await service.record('$a', '5', 'food', false, tags: 'lunch');
    await service.record(
      '$b',
      '7',
      'food',
      false,
      tags: 'dinner',
      notes: 'kebab',
    );
    await service.record('$b', '9', 'salary', true);

    expect(
      await service.transactions(GanjoorFilter(accountId: b)),
      hasLength(2),
    );
    expect(
      await service.transactions(
        GanjoorFilter(accountId: b, kind: GanjoorTxKind.expense),
      ),
      hasLength(1),
    );
    expect(
      await service.transactions(const GanjoorFilter(tag: 'dinner')),
      hasLength(1),
    );
    expect(
      await service.transactions(const GanjoorFilter(query: 'kebab')),
      hasLength(1),
    );
    expect(
      await service.transactions(const GanjoorFilter(category: 'NOTHING')),
      isEmpty,
    );
  });

  test('transfers touch both accounts in a filtered listing', () async {
    final service = newService();
    final a = (await service.addAccount('A', 'USD', '100')).id;
    final b = (await service.addAccount('B', 'USD')).id;
    await service.transfer('$a', '$b', '40');

    expect(
      await service.transactions(GanjoorFilter(accountId: a)),
      hasLength(1),
    );
    expect(
      await service.transactions(GanjoorFilter(accountId: b)),
      hasLength(1),
    );
  });

  // ── CSV pipeline ──

  test('CsvImport_EndToEnd_WithUndo', () async {
    final directory = Directory.systemTemp.createTempSync('ganjoor-csv-e2e');
    try {
      final path = '${directory.path}/statement.csv';
      File(path).writeAsStringSync(
        [
          'Date,Description,Amount',
          '2026-09-02,Coffee,-4.80',
          '2026-09-03,Gig,450',
          'broken,row',
        ].join('\n'),
      );

      final service = newService();
      await service.addAccount('Bank', 'USD');
      final result = await service.importCsv(
        path,
        'bank',
        'imported',
        hasHeader: true,
        maxRows: 100,
      );
      expect(result.imported, 2);
      expect(result.skipped, 1);

      expect((await service.transactions()).map((t) => t.category).toSet(), {
        'imported',
      });

      expect(await service.undo(), isTrue);
      expect(await service.transactions(), isEmpty);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('CSV dates accept the three bank shapes and reject the rest', () async {
    final directory = Directory.systemTemp.createTempSync('ganjoor-csv-dates');
    try {
      final path = '${directory.path}/dates.csv';
      File(path).writeAsStringSync(
        [
          '2026-09-02,ISO,-1',
          '02/09/2026,DayFirst,-1',
          '09/02/2026,MonthFirst,-1',
          '2026-9-2,Short,-1',
          'not-a-date,Nope,-1',
        ].join('\n'),
      );

      final service = newService();
      await service.addAccount('Bank', 'USD');
      final result = await service.importCsv(
        path,
        'Bank',
        'imported',
        hasHeader: false,
        maxRows: 100,
      );
      // `yyyy-MM-dd` must be zero-padded and the slashed shapes must be exactly
      // `dd/MM/yyyy` or `MM/dd/yyyy` — `2026-9-2` is skipped, like the .NET `TryParseExact`.
      expect(result.imported, 3);
      expect(result.skipped, 2);
      final dates = (await service.transactions())
          .map((t) => t.date.toIso())
          .toSet();
      expect(dates, {'2026-09-02', '2026-02-09'});
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('CSV import stops past the row rail', () async {
    final directory = Directory.systemTemp.createTempSync('ganjoor-csv-rail');
    try {
      final path = '${directory.path}/many.csv';
      File(path).writeAsStringSync(
        [for (var i = 1; i <= 5; i++) '2026-09-0$i,Row $i,-1'].join('\n'),
      );

      final service = newService();
      await service.addAccount('Bank', 'USD');
      await expectLater(
        service.importCsv(
          path,
          'Bank',
          'imported',
          hasHeader: false,
          maxRows: 3,
        ),
        throwsA(
          isA<GanjoorException>().having(
            (e) => e.message,
            'message',
            contains('More than 3 importable rows'),
          ),
        ),
      );
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  // ── Store failures ──

  test('StoreFailures_SurfaceTheirMessage', () async {
    final store = _BrokenTransactionStore();
    final service = GanjoorService(
      store: store,
      clock: clock,
      options: const GanjoorOptions(),
    );
    await service.addAccount('Bank', 'USD');

    await expectLater(
      () => service.record('Bank', '5', 'food', false),
      throwsA(isA<StateError>()),
    );
  });

  test('KnownCategories respect the AI category rail', () async {
    final service = newService(const GanjoorOptions(aiMaxCategories: 2));
    final id = (await service.addAccount('A', 'USD')).id;
    await service.setBudget('groceries', '100');
    await service.setBudget('coffee', '10');
    await service.record('$id', '5', 'rent', false);
    final categories = await service.knownCategories();
    // Both stores list budgets by category (`ORDER BY category`), so the two caps that fit
    // inside the rail are coffee and groceries — the ledger's `rent` is cut off.
    expect(categories, ['coffee', 'groceries']);
  });
}

/// A store whose transaction writes always fail — the .NET `ThrowingStore`.
class _BrokenTransactionStore extends MemoryGanjoorStore {
  @override
  Future<GanjoorTransaction> addTransaction(
    GanjoorTransaction transaction,
  ) async => throw StateError('store is broken');
}
