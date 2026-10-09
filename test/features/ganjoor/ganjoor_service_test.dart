import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/ganjoor/ganjoor_options.dart';
import 'package:jamejam/features/ganjoor/ganjoor_service.dart';
import 'package:jamejam/features/ganjoor/ganjoor_store.dart';
import 'package:jamejam/features/ganjoor/models.dart';
import 'package:jamejam/features/ganjoor/money.dart';

/// Port of `tests/JameJam.Tests/Ganjoor/GanjoorServiceTests.cs` (20 cases).
void main() {
  final today = DateOnly(2026, 9, 19);
  late MemoryGanjoorStore store;
  late GanjoorService service;

  setUp(() {
    store = MemoryGanjoorStore();
    service = GanjoorService(
      store: store,
      clock: () => DateTime.utc(today.year, today.month, today.day, 10),
      options: const GanjoorOptions(),
    );
  });

  Future<int> newAccount({
    String name = 'Bank',
    String currency = 'USD',
    String? start,
  }) async => (await service.addAccount(name, currency, start)).id;

  String idText(int id) => id.toString();

  test('Accounts_Balances_WalkTheLedger', () async {
    final bank = await newAccount(start: '100');
    await service.record(idText(bank), '50', 'salary', true);
    await service.record(idText(bank), '20', 'food', false);
    expect(await service.balance(idText(bank)), Money.parse('130'));
  });

  test('AccountNames_AreUnique_AndResolvable', () async {
    await newAccount(name: 'Cash');
    final exception = await _throwsGanjoor(
      () => service.addAccount('CASH', null, null),
    );
    expect(exception.message, contains('already exists'));
    await service.record('cash', '10', 'food', false);
    expect(await service.balance('CASH'), Money.parse('-10'));
  });

  test('Transfers_MoveMoney_WithoutTouchingIncomeOrSpending', () async {
    final from = await newAccount(name: 'A', start: '500');
    final to = await newAccount(name: 'B');
    await service.transfer(idText(from), idText(to), '120');

    expect(await service.balance('A'), Money.parse('380'));
    expect(await service.balance('B'), Money.parse('120'));
    final flow = await service.cashFlow();
    expect(flow.income, Money.zero);
    expect(flow.expenses, Money.zero);
  });

  test('Transfers_NeedTwoAccounts_OfOneCurrency', () async {
    await newAccount(name: 'A', start: '10');
    await newAccount(name: 'B');
    await _throwsGanjoor(() => service.transfer('A', 'A', '5'));
    await newAccount(name: 'Euro', currency: 'EUR');
    final exception = await _throwsGanjoor(
      () => service.transfer('A', 'Euro', '5'),
    );
    expect(exception.message, contains('matching currencies'));
  });

  test('RemoveAccount_IsGatedByForce_ThenCascades', () async {
    final id = await newAccount(name: 'Card');
    await service.record(idText(id), '9', 'food', false);
    final exception = await _throwsGanjoor(
      () => service.removeAccount(idText(id), force: false),
    );
    expect(exception.message, contains('--force'));

    expect(await service.removeAccount(idText(id), force: true), 1);
    expect(await service.transactions(), isEmpty);
    expect((await service.accounts()).where((a) => a.id == id), isEmpty);
  });

  test('Filters_NarrowTheLedger', () async {
    final a = await newAccount(name: 'A');
    final b = await newAccount(name: 'B');
    await service.record(
      idText(a),
      '10',
      'food',
      false,
      tags: 'lunch',
      notes: 'soup',
    );
    await service.record(idText(a), '100', 'rent', false, date: '2026-08-01');
    await service.record(idText(b), '500', 'salary', true);

    expect(
      await service.transactions(const GanjoorFilter(category: 'FOOD')),
      hasLength(1),
    );
    expect(
      await service.transactions(const GanjoorFilter(tag: 'lunch')),
      hasLength(1),
    );
    expect(
      await service.transactions(
        const GanjoorFilter(kind: GanjoorTxKind.income),
      ),
      hasLength(1),
    );
    expect(
      await service.transactions(
        const GanjoorFilter(month: DateOnly(2026, 8, 1)),
      ),
      hasLength(1),
    );
    expect(
      await service.transactions(const GanjoorFilter(query: 'oo')),
      hasLength(1),
    );
    expect(await service.transactions(), hasLength(3));
  });

  test('Budgets_TrackSpending_AndWarnThresholds', () async {
    final id = await newAccount(name: 'A', start: '1000');
    await service.setBudget('food', '100');
    await service.record(idText(id), '90', 'food', false);
    await service.record(idText(id), '20', 'food', false);

    final status = (await service.budgetStatuses()).single;
    expect(status.spent, Money.parse('110'));
    expect(status.over, isTrue);
    expect(status.percentUsed, 110);

    // Budgets ignore other months and non-expenses.
    for (final other in await service.budgetStatuses(DateOnly(2026, 8, 1))) {
      expect(other.spent, Money.zero);
    }
    final flow = await service.cashFlow();
    expect(flow.expenses, Money.parse('110'));
  });

  test('BudgetSet_IsIdempotent_AndRemovalFailsFriendly', () async {
    await service.setBudget('food', '100');
    await service.setBudget('FOOD', '200');
    final status = (await service.budgetStatuses()).single;
    expect(status.limit, Money.parse('200'));

    final removed = await service.removeBudget('food');
    expect(removed.category, 'FOOD');
    final exception = await _throwsGanjoor(() => service.removeBudget('food'));
    expect(exception.message, contains('No budget'));
  });

  test('CashFlow_SumsTheMonth_ByCategory', () async {
    final id = await newAccount(name: 'A');
    await service.record(idText(id), '2000', 'salary', true);
    await service.record(idText(id), '300', 'rent', false);
    await service.record(idText(id), '120', 'food', false);
    await service.record(idText(id), '80', 'food', false);

    final flow = await service.cashFlow(DateOnly(2026, 9, 1));
    expect(flow.income, Money.parse('2000'));
    expect(flow.expenses, Money.parse('500'));
    expect(flow.net, Money.parse('1500'));
    expect(flow.byCategory[0].category, 'rent');
    expect(flow.byCategory[0].amount, Money.parse('300'));
    expect(flow.byCategory[1].category, 'food');
    expect(flow.byCategory[1].count, 2);
  });

  test('Bills_AddAdvanceAndCatchUp', () async {
    final id = await newAccount(name: 'A', start: '5000');
    await service.addBill(
      'Rent',
      '950',
      'out',
      'housing',
      'monthly',
      nextText: '2026-09-01',
      accountText: idText(id),
    );

    final due = (await service.dueBills()).single;
    expect(due.name, 'Rent');

    final result = await service.applyDueBills();
    final tx = result.transactions.single;
    expect(tx.amount, Money.parse('950'));
    expect(tx.date, DateOnly(2026, 9, 1));
    expect(tx.kind, GanjoorTxKind.expense);
    expect(tx.fromBillId, due.id);

    final advanced = result.bills.single;
    expect(advanced.nextDue, DateOnly(2026, 10, 1));
    expect(await service.dueBills(), isEmpty);

    // Bills always land in their own account.
    expect(await service.balance(idText(id)), Money.parse('4050'));
  });

  test('Bills_SupportYearly_AndWeeklyMath', () {
    expect(
      GanjoorService.nextDue(GanjoorFrequency.yearly, 1, DateOnly(2026, 2, 28)),
      DateOnly(2027, 2, 28),
    );
    expect(
      GanjoorService.nextDue(GanjoorFrequency.weekly, 2, DateOnly(2026, 9, 19)),
      DateOnly(2026, 10, 3),
    );
    expect(
      GanjoorService.nextDue(
        GanjoorFrequency.monthly,
        1,
        DateOnly(2026, 1, 31),
      ),
      DateOnly(2026, 2, 28), // clamps
    );
    expect(
      GanjoorService.nextDue(GanjoorFrequency.daily, 10, DateOnly(2026, 9, 19)),
      DateOnly(2026, 9, 29),
    );
  });

  test('Bills_RejectTransfers_AndUnknowableKinds', () async {
    await newAccount(name: 'A');
    final exception = await _throwsGanjoor(
      () => service.addBill('Move', '10', 'transfer', 'moving', 'monthly'),
    );
    expect(exception.message, contains('not a transfer'));
  });

  test('Goals_TrackProgress_AndGuardTheEdges', () async {
    final goal = await service.addGoal('Laptop', '1000', '2026-12-31');
    await service.contribute(idText(goal.id), '400');
    await service.contribute(idText(goal.id), '600');

    final done = (await service.goals()).single;
    expect(done.contributed, Money.parse('1000'));

    final over = await _throwsGanjoor(
      () => service.contribute(idText(goal.id), '1'),
    );
    expect(over.message, contains('only needs 0.00 more'));

    await service.withdraw(idText(goal.id), '250');
    expect((await service.goals()).single.contributed, Money.parse('750'));

    final under = await _throwsGanjoor(
      () => service.withdraw(idText(goal.id), '1000'),
    );
    expect(under.message, contains('holds only 750.00'));

    await service.removeGoal(idText(goal.id));
    expect(await service.goals(), isEmpty);
  });

  test('Debts_TrackBothDirections_AndSettlePartially', () async {
    await service.addDebt('Sara', '150', false, due: '2026-10-01');
    await service.addDebt('Landlord', '600', true);

    await service.settleDebt('2', '250');
    final landlord = (await service.debts()).singleWhere(
      (d) => d.person == 'Landlord',
    );
    expect(landlord.settled, Money.parse('250'));

    final over = await _throwsGanjoor(() => service.settleDebt('2', '1000'));
    expect(over.message, contains('only 350.00 outstanding'));

    await service.settleDebt('2', '350');
    expect(
      (await service.debts()).singleWhere((d) => d.id == 2).settled,
      Money.parse('600'),
    );
  });

  test('NetWorth_ConvertsAccounts_AndCountsDebts', () async {
    await service.addAccount('Cash', 'USD', '1000');
    await service.addAccount('Euro', 'EUR', '1000');
    await service.addDebt('Sara', '300', false);
    await service.addDebt('Landlord', '100', true);

    final withoutRates = await _throwsGanjoor(service.netWorth);
    expect(withoutRates.message, contains('No exchange rate for EUR'));

    final converted = GanjoorService(
      store: store,
      clock: () => DateTime.utc(today.year, today.month, today.day, 10),
      options: GanjoorOptions(rates: {'EUR': Money.parse('2')}),
    );
    final worth = await converted.netWorth();
    expect(worth.baseCurrency, 'USD');
    expect(worth.accounts, Money.parse('3000')); // 1000 + 1000×2
    expect(worth.receivable, Money.parse('300'));
    expect(worth.payable, Money.parse('100'));
    expect(worth.total, Money.parse('3200'));
  });

  test('Undo_RevertsOneWholeCommand_AtATime', () async {
    final id = await newAccount(name: 'A', start: '100');
    await service.record(idText(id), '30', 'food', false);
    expect(
      await store.undoCount,
      2,
    ); // one for the account, one for the expense

    expect(await service.undo(), isTrue); // expense reverted
    expect(await service.balance('A'), Money.parse('100'));
    expect(await service.transactions(), isEmpty);

    expect(await service.undo(), isTrue); // account creation reverted
    expect(await service.accounts(), isEmpty);

    expect(await service.undo(), isFalse); // nothing left
  });

  test('ExportImport_RoundTripsTheWholeWallet_WithIdenticalIds', () async {
    final id = await newAccount(start: '500');
    final other = await newAccount(name: 'Cash');
    await service.record(
      idText(id),
      '42',
      'food',
      false,
      tags: 'lunch',
      notes: 'soup',
    );
    await service.transfer(idText(id), idText(other), '25');
    await service.setBudget('food', '100');
    await service.addBill(
      'Rent',
      '950',
      'out',
      'housing',
      'monthly',
      accountText: idText(id),
    );
    await service.addGoal('Laptop', '1000');
    await service.addDebt('Sara', '150', false);

    final json = await service.exportJson();
    final fresh = GanjoorService(
      store: MemoryGanjoorStore(),
      clock: () => DateTime.utc(today.year, today.month, today.day, 10),
      options: const GanjoorOptions(),
    );
    await fresh.importJson(json);

    expect(await fresh.balance('Bank'), await service.balance('Bank'));
    expect(
      (await fresh.transactions()).map((t) => (t.id, t.category)),
      (await service.transactions()).map((t) => (t.id, t.category)),
    );
    expect(
      (await fresh.knownCategories()).length,
      (await service.knownCategories()).length,
    );
    expect(await fresh.goals(), hasLength(1));
    expect(await fresh.debts(), hasLength(1));
    expect(await fresh.budgetStatuses(), hasLength(1));
    expect(
      (await fresh.accounts()).singleWhere((a) => a.name == 'Cash').id,
      other,
    );
  });

  test('CsvImport_DetectsSigns_SkipsJunk_AndUndoRevertsItAll', () async {
    final id = await newAccount();
    final directory = Directory.systemTemp.createTempSync('ganjoor_csv_');
    final file = File('${directory.path}/statement.csv')
      ..writeAsStringSync(
        [
          'Date,Description,Amount',
          '2026-09-02,Coffee,-4.80',
          '2026-09-03,Gig,450',
          'nonsense,row,here',
          '2026-09-04,Zero,0',
        ].join('\n'),
      );
    try {
      final result = await service.importCsv(
        file.path,
        idText(id),
        'imported',
        hasHeader: true,
        maxRows: 100,
      );
      expect(result.imported, 2);
      expect(result.skipped, 2);

      final rows = await service.transactions(
        const GanjoorFilter(category: 'imported'),
      );
      expect(
        rows.singleWhere((t) => t.kind == GanjoorTxKind.income).amount,
        Money.parse('450'),
      );
      expect(
        rows.singleWhere((t) => t.kind == GanjoorTxKind.expense).amount,
        Money.parse('4.80'),
      );
      expect(
        rows.singleWhere((t) => t.kind == GanjoorTxKind.expense).notes,
        'Coffee',
      );

      expect(await service.undo(), isTrue);
      expect(await service.transactions(), isEmpty);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('CsvImport_RespectsTheRowRail', () async {
    final id = await newAccount();
    final exception = await _throwsGanjoor(
      () => service.importCsv(
        'whatever.csv',
        idText(id),
        'x',
        hasHeader: false,
        maxRows: 0,
      ),
    );
    expect(exception.message, contains('between 1 and'));
  });

  test('KnownCategories_UnifyBudgetsAndHistory', () async {
    final id = await newAccount(name: 'A');
    await service.setBudget('groceries', '100');
    await service.record(idText(id), '5', 'coffee', false);
    final categories = await service.knownCategories();
    expect(categories, ['groceries', 'coffee']);
  });
}

/// Runs [action] and returns the [GanjoorException] it must throw.
Future<GanjoorException> _throwsGanjoor(Future<void> Function() action) async {
  try {
    await action();
  } on GanjoorException catch (error) {
    return error;
  }
  fail('Expected a GanjoorException.');
}
