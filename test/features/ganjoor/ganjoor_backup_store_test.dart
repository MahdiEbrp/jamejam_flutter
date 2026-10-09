import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/ganjoor/ganjoor_backup.dart';
import 'package:jamejam/features/ganjoor/ganjoor_options.dart';
import 'package:jamejam/features/ganjoor/ganjoor_service.dart';
import 'package:jamejam/features/ganjoor/ganjoor_store.dart';
import 'package:jamejam/features/ganjoor/models.dart';
import 'package:jamejam/features/ganjoor/money.dart';
import 'package:jamejam/features/ganjoor/sqlite_ganjoor_store.dart';

/// Port of `tests/JameJam.Tests/Ganjoor/GanjoorBackupAndStoreTests.cs` (7 cases).
void main() {
  final today = DateOnly(2026, 9, 19);
  DateTime clock() => DateTime.utc(2026, 9, 19, 10);

  group('GanjoorBackupTests', () {
    test('RoundTrip_PreservesEverything', () async {
      final service = GanjoorService(
        store: MemoryGanjoorStore(),
        clock: clock,
        options: const GanjoorOptions(),
      );
      final id = (await service.addAccount('Bank', 'USD', '500')).id;
      await service.record(
        '$id',
        '42.5',
        'food',
        false,
        tags: 'lunch',
        notes: 'soup',
      );
      await service.setBudget('food', '100');
      await service.addBill(
        'Rent',
        '950',
        'out',
        'housing',
        'monthly',
        accountText: '$id',
      );
      await service.addGoal('Laptop', '1000', '2026-12-31');
      await service.addDebt('Sara', '150', false, notes: 'concert');

      final json = await service.exportJson();
      final file = GanjoorBackup.fromJson(json);

      expect(file.version, GanjoorBackup.currentVersion);
      expect(file.accounts, hasLength(1));
      expect(file.transactions, hasLength(1));
      expect(file.budgets, hasLength(1));
      expect(file.bills, hasLength(1));
      expect(file.goals, hasLength(1));
      expect(file.debts, hasLength(1));
      expect(file.transactions[0].amount, Money.parse('42.5'));
      expect(file.transactions[0].tags[0], 'lunch');
      expect(file.accounts[0].id, 1);
    });

    for (final json in [
      '',
      '   ',
      '{broken',
      '{"version":99,"exportedAt":"x"}',
    ]) {
      test('FromJson_RejectsUnreadableOrFutureFiles($json)', () {
        // The .NET raised ArgumentException for all four; Dart splits it into
        // ArgumentError (blank input) and FormatException (unreadable/future file), which
        // the controller reports with the same message.
        expect(
          () => GanjoorBackup.fromJson(json),
          throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
        );
      });
    }

    test('FromJson_IsIndentedAndOmitsNullFields', () async {
      final service = GanjoorService(
        store: MemoryGanjoorStore(),
        clock: clock,
        options: const GanjoorOptions(),
      );
      await service.addAccount('Bank', 'USD', null);
      final json = await service.exportJson();
      expect(json, contains('\n  "version": 1'));
      expect(json, isNot(contains('transferToAccountId')));
      expect(json, contains('"currency": "USD"'));
    });
  });

  group('SqliteGanjoorStoreTests', () {
    late Directory directory;
    late String path;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('ganjoor-sqlite-test');
      path = '${directory.path}/ganjoor.db';
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    test('Persistence_RoundTrips_Everything', () async {
      late int accountId;
      late int txId;
      {
        final first = SqliteGanjoorStore(path);
        final account = await first.addAccount(
          GanjoorAccount(
            id: 0,
            name: 'Bank',
            currency: 'USD',
            initialBalance: Money.parse('250'),
            createdAt: DateTime.now().toUtc(),
          ),
        );
        accountId = account.id;
        final tx = await first.addTransaction(
          GanjoorTransaction(
            id: 0,
            kind: GanjoorTxKind.expense,
            accountId: accountId,
            amount: Money.parse('12.5'),
            category: 'food',
            date: DateOnly(2026, 9, 19),
            createdAt: DateTime.now().toUtc(),
            tags: const ['lunch', 'soup'],
            notes: 'nice',
          ),
        );
        txId = tx.id;
        await first.setBudget(GanjoorBudget('food', Money.parse('100')));
        await first.addBill(
          GanjoorBill(
            id: 0,
            name: 'Rent',
            amount: Money.parse('950'),
            kind: GanjoorTxKind.expense,
            category: 'housing',
            frequency: GanjoorFrequency.monthly,
            interval: 1,
            nextDue: DateOnly(2026, 10, 1),
            createdAt: DateTime.now().toUtc(),
            accountId: accountId,
          ),
        );
        await first.addGoal(
          GanjoorGoal(
            id: 0,
            name: 'Laptop',
            target: Money.parse('1000'),
            contributed: Money.parse('400'),
            createdAt: DateTime.now().toUtc(),
            deadline: DateOnly(2026, 12, 31),
          ),
        );
        await first.addDebt(
          GanjoorDebt(
            id: 0,
            person: 'Sara',
            amount: Money.parse('150'),
            settled: Money.zero,
            owedByMe: false,
            createdAt: DateTime.now().toUtc(),
            notes: 'concert',
          ),
        );
        await first.pushUndo('{}');
      }

      {
        final second = SqliteGanjoorStore(path);
        final account = await second.findAccount(accountId);
        expect(account, isNotNull);
        expect(account!.initialBalance, Money.parse('250'));

        final tx = await second.findTransaction(txId);
        expect(tx, isNotNull);
        expect(tx!.amount, Money.parse('12.5'));
        expect(tx.tags, ['lunch', 'soup']);
        expect(tx.notes, 'nice');

        expect((await second.listBudgets()).single.category, 'food');
        final bill = (await second.listBills()).single;
        expect(bill.accountId, accountId);
        expect(
          (await second.listGoals()).single.contributed,
          Money.parse('400'),
        );
        expect(await second.listDebts(), hasLength(1));
        expect(await second.undoCount, 1);

        expect((await second.findAccountByName('bank'))?.name, 'Bank');
      }
    });

    test('Updates_AndDeletes_Work', () async {
      final store = SqliteGanjoorStore(path);
      final account = await store.addAccount(
        GanjoorAccount(
          id: 0,
          name: 'Bank',
          currency: 'USD',
          initialBalance: Money.zero,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      final renamed = account.copyWith(
        name: 'Main',
        initialBalance: Money.parse('5'),
      );
      await store.updateAccount(renamed);
      expect((await store.findAccount(account.id))!.name, 'Main');
      expect(
        (await store.findAccount(account.id))!.initialBalance,
        Money.parse('5'),
      );
      expect(await store.removeAccount(account.id), isTrue);
      expect(await store.removeAccount(account.id), isFalse);

      final tx = await store.addTransaction(
        GanjoorTransaction(
          id: 0,
          kind: GanjoorTxKind.income,
          accountId: account.id,
          amount: Money.parse('9'),
          category: 'gift',
          date: DateOnly(2026, 9, 19),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      await store.updateTransaction(tx.copyWith(category: 'presents'));
      expect((await store.findTransaction(tx.id))!.category, 'presents');
      expect(await store.removeTransaction(tx.id), isTrue);

      await store.setBudget(GanjoorBudget('food', Money.parse('10')));
      expect(await store.removeBudget('FOOD'), isTrue);

      expect(await store.popUndo(), isNull);
      await store.pushUndo('a');
      await store.pushUndo('b');
      expect(await store.undoCount, 2);
      expect(await store.popUndo(), 'b'); // LIFO
      expect(await store.popUndo(), 'a');
    });

    test('Lists_Updates_AndRemoves_ForEveryEntity', () async {
      final store = SqliteGanjoorStore(path);
      expect(store.databasePath, path);

      final first = await store.addAccount(
        GanjoorAccount(
          id: 0,
          name: 'A',
          currency: 'USD',
          initialBalance: Money.zero,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      final second = await store.addAccount(
        GanjoorAccount(
          id: 0,
          name: 'B',
          currency: 'EUR',
          initialBalance: Money.zero,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      expect((await store.listAccounts()).map((a) => a.id), [
        first.id,
        second.id,
      ]);

      await store.addTransaction(
        GanjoorTransaction(
          id: 0,
          kind: GanjoorTxKind.expense,
          accountId: first.id,
          amount: Money.parse('5'),
          category: 'food',
          date: DateOnly(2026, 9, 1),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      final txB = await store.addTransaction(
        GanjoorTransaction(
          id: 0,
          kind: GanjoorTxKind.income,
          accountId: second.id,
          amount: Money.parse('9'),
          category: 'gift',
          date: DateOnly(2026, 9, 2),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      expect(
        (await store.listTransactions())[0].id,
        txB.id,
      ); // newest date first

      await store.setBudget(GanjoorBudget('food', Money.parse('10')));
      await store.setBudget(GanjoorBudget('fun', Money.parse('20')));
      expect((await store.listBudgets()).map((b) => b.category), [
        'food',
        'fun',
      ]);

      final bill = await store.addBill(
        GanjoorBill(
          id: 0,
          name: 'Rent',
          amount: Money.parse('950'),
          kind: GanjoorTxKind.expense,
          category: 'housing',
          frequency: GanjoorFrequency.monthly,
          interval: 1,
          nextDue: DateOnly(2026, 10, 1),
          createdAt: DateTime.now().toUtc(),
          accountId: first.id,
        ),
      );
      await store.updateBill(
        bill.copyWith(
          name: 'House',
          amount: Money.parse('900'),
          category: 'roof',
          accountId: second.id,
        ),
      );
      final updatedBill = (await store.listBills()).single;
      expect(updatedBill.name, 'House');
      expect(updatedBill.amount, Money.parse('900'));
      expect(updatedBill.category, 'roof');
      expect(updatedBill.accountId, second.id);
      expect(await store.removeBill(bill.id), isTrue);
      expect(await store.removeBill(bill.id), isFalse);
      expect(await store.listBills(), isEmpty);

      final goal = await store.addGoal(
        GanjoorGoal(
          id: 0,
          name: 'Laptop',
          target: Money.parse('1000'),
          contributed: Money.parse('100'),
          createdAt: DateTime.now().toUtc(),
          deadline: DateOnly(2026, 12, 31),
        ),
      );
      await store.updateGoal(
        goal.copyWith(
          contributed: Money.parse('250'),
          deadline: DateOnly(2027, 1, 31),
        ),
      );
      final updatedGoal = (await store.listGoals()).single;
      expect(updatedGoal.contributed, Money.parse('250'));
      expect(updatedGoal.deadline, DateOnly(2027, 1, 31));
      expect(await store.removeGoal(goal.id), isTrue);
      expect(await store.listGoals(), isEmpty);

      final debt = await store.addDebt(
        GanjoorDebt(
          id: 0,
          person: 'Sara',
          amount: Money.parse('150'),
          settled: Money.zero,
          owedByMe: false,
          createdAt: DateTime.now().toUtc(),
          notes: 'concert',
        ),
      );
      await store.updateDebt(debt.copyWith(settled: Money.parse('50')));
      expect((await store.listDebts()).single.settled, Money.parse('50'));
      expect(await store.removeDebt(debt.id), isTrue);
      expect(await store.listDebts(), isEmpty);
    });

    test('FindAccount_Misses_ReturnNull', () async {
      final store = SqliteGanjoorStore(path);
      expect(await store.findAccount(42), isNull);
      expect(await store.findAccountByName('ghost'), isNull);
      expect(await store.findTransaction(42), isNull);
    });
  });

  group('Ganjoor backup, record-level', () {
    test('accounts survive a JSON round trip with their timestamps', () async {
      final store = MemoryGanjoorStore();
      final service = GanjoorService(
        store: store,
        clock: clock,
        options: const GanjoorOptions(),
      );
      await service.addAccount('Bank', 'USD', '10');
      final json = await service.exportJson();
      final file = GanjoorBackup.fromJson(json);
      expect(file.accounts.single.createdAt, DateTime.utc(2026, 9, 19, 10));
      expect(file.exportedAt, isNotEmpty);
    });

    test('today comes from the injected clock', () {
      final service = GanjoorService(
        store: MemoryGanjoorStore(),
        clock: clock,
        options: const GanjoorOptions(),
      );
      expect(service.today, today);
    });
  });
}
