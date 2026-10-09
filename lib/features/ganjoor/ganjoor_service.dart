/// ganjoor — see doc/ganjoor.md and AGENTS.md
import 'dart:io';

import '../../core/date_only.dart';
import 'ganjoor_backup.dart';
import 'ganjoor_defaults.dart';
import 'ganjoor_options.dart';
import 'ganjoor_store.dart';
import 'models.dart';
import 'money.dart';
import 'money_guard.dart';

class GanjoorService {
  GanjoorService({
    required GanjoorStore store,
    required DateTime Function() clock,
    GanjoorOptions options = const GanjoorOptions(),
  }) : _store = store,
       _clock = clock,
       _options = options {
    _options.validate();
    store.undoDepth = _options.undoDepth;
  }

  final GanjoorStore _store;
  final DateTime Function() _clock;
  final GanjoorOptions _options;

  /// The validated options in effect.
  GanjoorOptions get options => _options;

  /// The store this service writes to.
  GanjoorStore get store => _store;

  /// Today according to the injected clock (UTC, like the .NET `TimeProvider`).
  DateOnly get today => DateOnly.fromDateTime(_clock().toUtc());

  // ── Accounts ──

  /// Creates an account; names are unique case-insensitively.
  Future<GanjoorAccount> addAccount(
    String? name, [
    String? currency,
    String? initialBalance,
  ]) async {
    final clean = MoneyGuard.name(name, GanjoorDefaults.maxNameLength);
    if (await _store.findAccountByName(clean) != null) {
      throw GanjoorException("An account named '$clean' already exists.");
    }

    final accounts = await _store.listAccounts();
    if (accounts.length >= _options.maxAccounts) {
      throw GanjoorException(
        'At most ${_options.maxAccounts} accounts are allowed.',
      );
    }

    await _pushSnapshot();
    final code = MoneyGuard.currency(
      currency == null || currency.trim().isEmpty
          ? _options.defaultCurrency
          : currency,
    );
    final start = initialBalance == null
        ? Money.zero
        : MoneyGuard.amount(initialBalance, _options.maxAmount);

    return _store.addAccount(
      GanjoorAccount(
        id: 0,
        name: clean,
        currency: code,
        initialBalance: start,
        createdAt: _clock().toUtc(),
      ),
    );
  }

  /// Renames an account.
  Future<GanjoorAccount> renameAccount(String? idText, String? newName) async {
    final account = await _account(idText);
    final clean = MoneyGuard.name(newName, GanjoorDefaults.maxNameLength);
    final other = await _store.findAccountByName(clean);
    if (other != null && other.id != account.id) {
      throw GanjoorException("An account named '$clean' already exists.");
    }

    await _pushSnapshot();
    final renamed = account.copyWith(name: clean);
    await _store.updateAccount(renamed);
    return renamed;
  }

  /// Archives or unarchives an account.
  Future<GanjoorAccount> archiveAccount(String? idText, bool archived) async {
    final account = await _account(idText);
    await _pushSnapshot();
    final updated = account.copyWith(isArchived: archived);
    await _store.updateAccount(updated);
    return updated;
  }

  /// Removes an account and its history.
  ///
  /// Refuses while transactions exist unless [force] is set — the safety gate against
  /// accidental wipe-outs.
  Future<int> removeAccount(String? idText, {required bool force}) async {
    final account = await _account(idText);
    final history = (await _store.listTransactions())
        .where((tx) => tx.touches(account.id))
        .toList();

    if (history.isNotEmpty && !force) {
      throw GanjoorException(
        "Account '${account.name}' holds ${history.length} transaction(s). "
        'Remove them first, or pass --force to delete the account with its history.',
      );
    }

    await _pushSnapshot();
    for (final tx in history) {
      await _store.removeTransaction(tx.id);
    }
    await _store.removeAccount(account.id);
    return history.length;
  }

  /// Lists accounts, optionally including archived ones.
  Future<List<GanjoorAccount>> accounts({bool includeArchived = true}) async {
    final all = await _store.listAccounts();
    return all
        .where((account) => includeArchived || !account.isArchived)
        .toList(growable: false);
  }

  /// Current balance of an account (id or name).
  Future<Money> balance(String? accountText) async =>
      balanceOf(await _account(accountText));

  /// Current balance of a resolved account.
  Future<Money> balanceOf(GanjoorAccount account) async {
    var balance = account.initialBalance;
    for (final tx in await _store.listTransactions()) {
      if (tx.kind == GanjoorTxKind.income && tx.accountId == account.id) {
        balance += tx.amount;
      } else if (tx.kind == GanjoorTxKind.expense &&
          tx.accountId == account.id) {
        balance -= tx.amount;
      } else if (tx.kind == GanjoorTxKind.transfer) {
        if (tx.accountId == account.id) balance -= tx.amount;
        if (tx.transferToAccountId == account.id) balance += tx.amount;
      }
    }
    return balance;
  }

  // ── Transactions ──

  /// Records an expense (or income when [income] is set).
  Future<GanjoorTransaction> record(
    String? accountText,
    String? amountText,
    String? category,
    bool income, {
    String? tags,
    String? notes,
    String? date,
  }) async {
    final account = await _account(accountText);
    final amount = MoneyGuard.amount(amountText, _options.maxAmount);
    final cleanCategory = MoneyGuard.category(category);
    final cleanTags = MoneyGuard.tags(tags, GanjoorDefaults.maxTags);
    final cleanNotes = MoneyGuard.notes(notes, GanjoorDefaults.maxNotesLength);
    final when = date == null ? today : MoneyGuard.date(date);

    await _pushSnapshot();
    return _store.addTransaction(
      GanjoorTransaction(
        id: 0,
        kind: income ? GanjoorTxKind.income : GanjoorTxKind.expense,
        accountId: account.id,
        amount: amount,
        category: cleanCategory,
        date: when,
        createdAt: _clock().toUtc(),
        tags: cleanTags,
        notes: cleanNotes,
      ),
    );
  }

  /// Records a transfer between two accounts (same currency required).
  Future<GanjoorTransaction> transfer(
    String? fromText,
    String? toText,
    String? amountText, {
    String? notes,
    String? date,
  }) async {
    final from = await _account(fromText);
    final to = await _account(toText);
    if (from.id == to.id) {
      throw const GanjoorException('A transfer needs two different accounts.');
    }

    if (from.currency.toUpperCase() != to.currency.toUpperCase()) {
      throw GanjoorException(
        'Transfers need matching currencies (${from.currency} → ${to.currency}). '
        'Record the move as separate transactions instead.',
      );
    }

    final amount = MoneyGuard.amount(amountText, _options.maxAmount);
    final cleanNotes = MoneyGuard.notes(notes, GanjoorDefaults.maxNotesLength);
    final when = date == null ? today : MoneyGuard.date(date);

    await _pushSnapshot();
    return _store.addTransaction(
      GanjoorTransaction(
        id: 0,
        kind: GanjoorTxKind.transfer,
        accountId: from.id,
        amount: amount,
        category: 'transfer',
        date: when,
        createdAt: _clock().toUtc(),
        transferToAccountId: to.id,
        notes: cleanNotes,
      ),
    );
  }

  /// Sets a new category on one transaction.
  Future<GanjoorTransaction> recategorize(
    String? idText,
    String? category,
  ) async {
    final tx = await _transaction(idText);
    final clean = MoneyGuard.category(category);
    await _pushSnapshot();
    final updated = tx.copyWith(category: clean);
    await _store.updateTransaction(updated);
    return updated;
  }

  /// Deletes one transaction.
  Future<GanjoorTransaction> deleteTransaction(String? idText) async {
    final tx = await _transaction(idText);
    await _pushSnapshot();
    await _store.removeTransaction(tx.id);
    return tx;
  }

  /// Lists transactions newest-first, optionally filtered.
  Future<List<GanjoorTransaction>> transactions([
    GanjoorFilter filter = const GanjoorFilter(),
  ]) async {
    final all = await _store.listTransactions();
    final category = filter.category;
    final tag = filter.tag;
    final month = filter.month;
    final kind = filter.kind;
    final query = filter.query;

    return all
        .where((tx) {
          if (filter.accountId != null && !tx.touches(filter.accountId!)) {
            return false;
          }
          if (category != null &&
              tx.category.toLowerCase() != category.trim().toLowerCase()) {
            return false;
          }
          if (tag != null &&
              !tx.tags.any(
                (existing) =>
                    existing.toLowerCase() == tag.trim().toLowerCase(),
              )) {
            return false;
          }
          if (month != null &&
              (tx.date.year != month.year || tx.date.month != month.month)) {
            return false;
          }
          if (kind != null && tx.kind != kind) return false;
          if (query != null && query.trim().isNotEmpty) {
            final needle = query.trim().toLowerCase();
            final matches =
                tx.category.toLowerCase().contains(needle) ||
                tx.notes.toLowerCase().contains(needle) ||
                tx.tags.any((value) => value.toLowerCase().contains(needle));
            if (!matches) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Distinct known categories: budgets first, then transaction history.
  Future<List<String>> knownCategories() async {
    final seen = <String>{};
    final categories = <String>[];

    for (final budget in await _store.listBudgets()) {
      if (seen.add(budget.category.toLowerCase())) {
        categories.add(budget.category);
      }
    }
    for (final tx in await _store.listTransactions()) {
      if (seen.add(tx.category.toLowerCase())) categories.add(tx.category);
    }

    return categories.take(_options.aiMaxCategories).toList(growable: false);
  }

  // ── Budgets ──

  /// Sets a monthly cap for a category.
  Future<GanjoorBudget> setBudget(String? category, String? limitText) async {
    final clean = MoneyGuard.category(category);
    final limit = MoneyGuard.amount(limitText, _options.maxAmount);
    if ((await _store.listBudgets()).length >=
        GanjoorDefaults.maxBudgetsBound) {
      throw GanjoorException(
        'At most ${GanjoorDefaults.maxBudgetsBound} budgets are allowed.',
      );
    }

    await _pushSnapshot();
    final budget = GanjoorBudget(clean, limit);
    await _store.setBudget(budget);
    return budget;
  }

  /// Removes a budget.
  Future<GanjoorBudget> removeBudget(String? category) async {
    final clean = MoneyGuard.category(category);
    final existing = (await _store.listBudgets())
        .where((budget) => budget.category.toLowerCase() == clean.toLowerCase())
        .firstOrNull;
    if (existing == null) {
      throw GanjoorException("No budget for '$clean'.");
    }

    await _pushSnapshot();
    await _store.removeBudget(existing.category);
    return existing;
  }

  /// Budget statuses (spent versus limit) for a month.
  Future<List<GanjoorBudgetStatus>> budgetStatuses([DateOnly? month]) async {
    final when = month ?? _firstOfMonth(today);
    final budgets = await _store.listBudgets();
    final spentByCategory = <String, Money>{};

    for (final tx in await _store.listTransactions()) {
      if (tx.kind != GanjoorTxKind.expense) continue;
      if (tx.date.year != when.year || tx.date.month != when.month) continue;
      final key = tx.category.toLowerCase();
      spentByCategory[key] = (spentByCategory[key] ?? Money.zero) + tx.amount;
    }

    final statuses =
        [
          for (final budget in budgets)
            GanjoorBudgetStatus(
              budget.category,
              budget.monthlyLimit,
              spentByCategory[budget.category.toLowerCase()] ?? Money.zero,
            ),
        ]..sort(
          (a, b) =>
              a.category.toLowerCase().compareTo(b.category.toLowerCase()),
        );
    return statuses;
  }

  /// Cash flow (income vs expenses by category) for a month.
  Future<GanjoorCashFlow> cashFlow([DateOnly? month]) async {
    final when = month ?? _firstOfMonth(today);
    final inMonth = (await _store.listTransactions())
        .where((tx) => tx.date.year == when.year && tx.date.month == when.month)
        .toList();

    var income = Money.zero;
    var expenses = Money.zero;
    final totals = <String, ({String category, Money amount, int count})>{};

    for (final tx in inMonth) {
      if (tx.kind == GanjoorTxKind.income) {
        income += tx.amount;
      } else if (tx.kind == GanjoorTxKind.expense) {
        expenses += tx.amount;
        final key = tx.category.toLowerCase();
        final current = totals[key];
        totals[key] = current == null
            ? (category: tx.category, amount: tx.amount, count: 1)
            : (
                category: current.category,
                amount: current.amount + tx.amount,
                count: current.count + 1,
              );
      }
    }

    final byCategory =
        [
          for (final row in totals.values)
            GanjoorCategoryTotal(row.category, row.amount, row.count),
        ]..sort((a, b) {
          final byAmount = b.amount.compareTo(a.amount);
          // LINQ's OrderByDescending is stable; a Dart sort is not, so ties fall back to the
          // category name and the report stays reproducible.
          return byAmount != 0
              ? byAmount
              : a.category.toLowerCase().compareTo(b.category.toLowerCase());
        });

    return GanjoorCashFlow(
      month: when,
      income: income,
      expenses: expenses,
      byCategory: byCategory,
    );
  }

  // ── Bills (recurring) ──

  /// Adds a repeating bill or income.
  Future<GanjoorBill> addBill(
    String? name,
    String? amountText,
    String? kindText,
    String? category,
    String? frequencyText, {
    String? intervalText,
    String? nextText,
    String? accountText,
  }) async {
    final kind = MoneyGuard.kind(kindText);
    if (kind == GanjoorTxKind.transfer) {
      throw const GanjoorException(
        'Bills can be income or expense — not a transfer.',
      );
    }

    final clean = MoneyGuard.name(name, GanjoorDefaults.maxNameLength);
    final amount = MoneyGuard.amount(amountText, _options.maxAmount);
    final cleanCategory = MoneyGuard.category(category);
    final frequency = MoneyGuard.frequency(frequencyText);
    final interval = intervalText == null ? 1 : _parseInterval(intervalText);
    final next = nextText == null ? today : MoneyGuard.date(nextText);
    final accountId = accountText == null
        ? await _firstAccountId()
        : (await _account(accountText)).id;
    if ((await _store.listBills()).length >= GanjoorDefaults.maxBillsBound) {
      throw GanjoorException(
        'At most ${GanjoorDefaults.maxBillsBound} bills are allowed.',
      );
    }

    await _pushSnapshot();
    return _store.addBill(
      GanjoorBill(
        id: 0,
        name: clean,
        amount: amount,
        kind: kind,
        category: cleanCategory,
        frequency: frequency,
        interval: interval,
        nextDue: next,
        createdAt: _clock().toUtc(),
        accountId: accountId,
      ),
    );
  }

  /// Removes a bill.
  Future<GanjoorBill> removeBill(String? idText) async {
    final id = MoneyGuard.id(idText, 'Bill id');
    final bill = (await _store.listBills())
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (bill == null) throw GanjoorException('No bill #$id.');

    await _pushSnapshot();
    await _store.removeBill(bill.id);
    return bill;
  }

  /// Bills due on or before the given day.
  Future<List<GanjoorBill>> dueBills([DateOnly? asOf]) async {
    final when = asOf ?? today;
    final bills = await _store.listBills();
    return bills.where((bill) => bill.nextDue <= when).toList(growable: false);
  }

  /// Records every bill occurrence that has come due and advances the schedules.
  Future<GanjoorApplyResult> applyDueBills([DateOnly? asOf]) async {
    final when = asOf ?? today;
    await _pushSnapshot();

    final recorded = <GanjoorTransaction>[];
    final applied = <GanjoorBill>[];

    for (final bill in await _store.listBills()) {
      var due = bill.nextDue;
      var cycles = 0;
      while (due <= when && cycles < GanjoorDefaults.billMaxCatchUp) {
        recorded.add(
          await _store.addTransaction(
            GanjoorTransaction(
              id: 0,
              kind: bill.kind,
              accountId: bill.accountId,
              amount: bill.amount,
              category: bill.category,
              date: due,
              createdAt: _clock().toUtc(),
              notes: bill.name,
              fromBillId: bill.id,
            ),
          ),
        );
        due = nextDue(bill.frequency, bill.interval, due);
        cycles++;
      }

      if (cycles > 0) {
        final updated = bill.copyWith(nextDue: due);
        await _store.updateBill(updated);
        applied.add(updated);
      }
    }

    return GanjoorApplyResult(transactions: recorded, bills: applied);
  }

  /// Next occurrence of a bill schedule (pure date math).
  static DateOnly nextDue(
    GanjoorFrequency frequency,
    int interval,
    DateOnly current,
  ) {
    switch (frequency) {
      case GanjoorFrequency.daily:
        return current.addDays(interval);
      case GanjoorFrequency.weekly:
        return current.addDays(7 * interval);
      case GanjoorFrequency.monthly:
        return current.addMonths(interval);
      case GanjoorFrequency.yearly:
        // `DateOnly.AddYears` clamps 29 February to the 28th in a common year.
        final year = current.year + interval;
        final day = current.day > DateOnly.daysInMonth(year, current.month)
            ? DateOnly.daysInMonth(year, current.month)
            : current.day;
        return DateOnly(year, current.month, day);
    }
  }

  // ── Goals ──

  /// Creates a savings goal.
  Future<GanjoorGoal> addGoal(
    String? name,
    String? targetText, [
    String? deadline,
  ]) async {
    final clean = MoneyGuard.name(name, GanjoorDefaults.maxNameLength);
    final target = MoneyGuard.amount(targetText, _options.maxAmount);
    final by = deadline == null ? null : MoneyGuard.date(deadline);
    if ((await _store.listGoals()).length >= GanjoorDefaults.maxGoalsBound) {
      throw GanjoorException(
        'At most ${GanjoorDefaults.maxGoalsBound} goals are allowed.',
      );
    }

    await _pushSnapshot();
    return _store.addGoal(
      GanjoorGoal(
        id: 0,
        name: clean,
        target: target,
        contributed: Money.zero,
        createdAt: _clock().toUtc(),
        deadline: by,
      ),
    );
  }

  /// Moves money into a goal (never past the target).
  Future<GanjoorGoal> contribute(String? idText, String? amountText) async {
    final goal = await _goal(idText);
    final amount = MoneyGuard.amount(amountText, _options.maxAmount);
    if (goal.contributed + amount > goal.target) {
      throw GanjoorException(
        "Goal '${goal.name}' only needs "
        '${(goal.target - goal.contributed).formatAmount()} more — contribute '
        'that or raise the target.',
      );
    }

    await _pushSnapshot();
    final updated = goal.copyWith(contributed: goal.contributed + amount);
    await _store.updateGoal(updated);
    return updated;
  }

  /// Takes money back out of a goal.
  Future<GanjoorGoal> withdraw(String? idText, String? amountText) async {
    final goal = await _goal(idText);
    final amount = MoneyGuard.amount(amountText, _options.maxAmount);
    if (amount > goal.contributed) {
      throw GanjoorException(
        "Goal '${goal.name}' holds only ${goal.contributed.formatAmount()}.",
      );
    }

    await _pushSnapshot();
    final updated = goal.copyWith(contributed: goal.contributed - amount);
    await _store.updateGoal(updated);
    return updated;
  }

  /// Removes a goal.
  Future<GanjoorGoal> removeGoal(String? idText) async {
    final goal = await _goal(idText);
    await _pushSnapshot();
    await _store.removeGoal(goal.id);
    return goal;
  }

  /// All goals with completion percent.
  Future<List<GanjoorGoal>> goals() => _store.listGoals();

  // ── Debts ──

  /// Records a personal debt.
  Future<GanjoorDebt> addDebt(
    String? person,
    String? amountText,
    bool owedByMe, {
    String? due,
    String? notes,
  }) async {
    final clean = MoneyGuard.name(person, GanjoorDefaults.maxNameLength);
    final amount = MoneyGuard.amount(amountText, _options.maxAmount);
    final cleanNotes = MoneyGuard.notes(notes, GanjoorDefaults.maxNotesLength);
    final by = due == null ? null : MoneyGuard.date(due);
    if ((await _store.listDebts()).length >= GanjoorDefaults.maxDebtsBound) {
      throw GanjoorException(
        'At most ${GanjoorDefaults.maxDebtsBound} debts are allowed.',
      );
    }

    await _pushSnapshot();
    return _store.addDebt(
      GanjoorDebt(
        id: 0,
        person: clean,
        amount: amount,
        settled: Money.zero,
        owedByMe: owedByMe,
        createdAt: _clock().toUtc(),
        dueDate: by,
        notes: cleanNotes,
      ),
    );
  }

  /// Records a (partial) repayment.
  Future<GanjoorDebt> settleDebt(String? idText, String? amountText) async {
    final debt = await _debt(idText);
    final amount = MoneyGuard.amount(amountText, _options.maxAmount);
    final outstanding = debt.outstanding;
    if (amount > outstanding) {
      throw GanjoorException(
        'Debt #${debt.id} has only ${outstanding.formatAmount()} outstanding.',
      );
    }

    await _pushSnapshot();
    final updated = debt.copyWith(settled: debt.settled + amount);
    await _store.updateDebt(updated);
    return updated;
  }

  /// Removes a debt.
  Future<GanjoorDebt> removeDebt(String? idText) async {
    final debt = await _debt(idText);
    await _pushSnapshot();
    await _store.removeDebt(debt.id);
    return debt;
  }

  /// All debts, outstanding first.
  Future<List<GanjoorDebt>> debts() async {
    final all = await _store.listDebts();
    return all..sort((a, b) {
      final bySettled = (a.settledInFull ? 1 : 0) - (b.settledInFull ? 1 : 0);
      return bySettled != 0 ? bySettled : a.id.compareTo(b.id);
    });
  }

  /// Net worth: account balances plus receivable minus payable, in base currency.
  Future<GanjoorNetWorth> netWorth() async {
    var accounts = Money.zero;
    for (final account in await _store.listAccounts()) {
      accounts += convertToBase(await balanceOf(account), account.currency);
    }

    var receivable = Money.zero;
    var payable = Money.zero;
    for (final debt in await _store.listDebts()) {
      final outstanding = debt.outstanding;
      if (debt.owedByMe) {
        payable += outstanding;
      } else {
        receivable += outstanding;
      }
    }

    return GanjoorNetWorth(
      baseCurrency: _options.defaultCurrency,
      accounts: accounts,
      receivable: receivable,
      payable: payable,
    );
  }

  /// Converts an amount into the base currency using the rate table.
  Money convertToBase(Money amount, String currency) {
    if (currency.toUpperCase() == _options.defaultCurrency.toUpperCase()) {
      return amount;
    }

    final rate = _options.rateFor(currency);
    if (rate != null) return amount.scaledBy(rate);

    throw GanjoorException(
      'No exchange rate for ${currency.toUpperCase()} — add it to '
      'GanjoorOptions.Rates or keep accounts in ${_options.defaultCurrency}.',
    );
  }

  // ── Undo, backup, CSV ──

  /// Reverts the last mutating command. Returns false when there is nothing to undo.
  Future<bool> undo() async {
    final snapshot = await _store.popUndo();
    if (snapshot == null) return false;

    await importJson(snapshot);
    return true;
  }

  /// Serializes the whole wallet (export and undo payloads).
  Future<String> exportJson() async => GanjoorBackup.toJson(
    accounts: await _store.listAccounts(),
    transactions: await _store.listTransactions(),
    budgets: await _store.listBudgets(),
    bills: await _store.listBills(),
    goals: await _store.listGoals(),
    debts: await _store.listDebts(),
  );

  /// Replaces the wallet with a backup (this is what undo restores).
  Future<void> importJson(String json) async {
    final file = GanjoorBackup.fromJson(json);
    await _clearAll();

    for (final dto in file.accounts) {
      await _store.addAccount(
        GanjoorAccount(
          id: 0,
          name: dto.name,
          currency: dto.currency,
          initialBalance: dto.initialBalance,
          createdAt: dto.createdAt,
          isArchived: dto.isArchived,
        ),
      );
    }

    for (final dto in file.transactions) {
      await _store.addTransaction(
        GanjoorTransaction(
          id: 0,
          kind: dto.kind,
          accountId: dto.accountId,
          amount: dto.amount,
          category: dto.category,
          date: dto.date,
          createdAt: dto.createdAt,
          transferToAccountId: dto.transferToAccountId,
          tags: dto.tags,
          notes: dto.notes,
          fromBillId: dto.fromBillId,
        ),
      );
    }

    for (final dto in file.budgets) {
      await _store.setBudget(GanjoorBudget(dto.category, dto.monthlyLimit));
    }

    for (final dto in file.bills) {
      await _store.addBill(
        GanjoorBill(
          id: 0,
          name: dto.name,
          amount: dto.amount,
          kind: dto.kind,
          category: dto.category,
          frequency: dto.frequency,
          interval: dto.interval,
          nextDue: dto.nextDue,
          createdAt: dto.createdAt,
          accountId: dto.accountId,
        ),
      );
    }

    for (final dto in file.goals) {
      await _store.addGoal(
        GanjoorGoal(
          id: 0,
          name: dto.name,
          target: dto.target,
          contributed: dto.contributed,
          createdAt: dto.createdAt,
          deadline: dto.deadline,
        ),
      );
    }

    for (final dto in file.debts) {
      await _store.addDebt(
        GanjoorDebt(
          id: 0,
          person: dto.person,
          amount: dto.amount,
          settled: dto.settled,
          owedByMe: dto.owedByMe,
          createdAt: dto.createdAt,
          dueDate: dto.dueDate,
          notes: dto.notes,
        ),
      );
    }
  }

  /// Writes the whole wallet to [path] as JSON (`ganjoor export`).
  ///
  /// The write is synchronous, like the .NET `File.WriteAllText` — which also keeps the
  /// call usable from a widget test, where real async I/O never gets a turn.
  Future<void> exportToFile(String path) async {
    File(path).writeAsStringSync(await exportJson());
  }

  /// Replaces the wallet from [path] after taking a snapshot (`ganjoor import`).
  Future<void> importFromFile(String path) async {
    await pushUndoSnapshot();
    await importJson(File(path).readAsStringSync());
  }

  /// Imports a bank-style CSV (`date,description,amount`; negative = debit) into an account.
  ///
  /// Unreadable rows are skipped and counted, never fatal.
  Future<GanjoorImportResult> importCsv(
    String path,
    String? accountText,
    String? category, {
    required bool hasHeader,
    required int maxRows,
  }) async {
    if (path.trim().isEmpty) {
      throw ArgumentError.value(path, 'path', 'Must not be blank');
    }
    final account = await _account(accountText);
    final cleanCategory = MoneyGuard.category(category);
    if (maxRows < 1 || maxRows > _options.maxImportRows) {
      throw GanjoorException(
        'Import rows must be between 1 and ${_options.maxImportRows}.',
      );
    }

    final lines = File(path).readAsLinesSync();
    await _pushSnapshot();

    var imported = 0;
    var skipped = 0;
    for (final raw in lines.skip(hasHeader ? 1 : 0)) {
      if (raw.trim().isEmpty) continue;

      if (imported >= maxRows) {
        throw GanjoorException(
          'More than $maxRows importable rows — raise the limit or split the '
          'file.',
        );
      }

      final parts = _splitCsv(raw);
      final Money signed;
      final DateOnly? when;
      try {
        when = parts.length == 3 ? _parseCsvDate(parts[0].trim()) : null;
        signed = parts.length == 3 ? Money.parse(parts[2].trim()) : Money.zero;
      } on FormatException {
        skipped++;
        continue;
      }

      if (parts.length != 3 || when == null || signed.isZero) {
        skipped++;
        continue;
      }

      await _store.addTransaction(
        GanjoorTransaction(
          id: 0,
          kind: signed.isPositive
              ? GanjoorTxKind.income
              : GanjoorTxKind.expense,
          accountId: account.id,
          amount: Money.fromMinor(signed.minorUnits.abs()),
          category: cleanCategory,
          date: when,
          createdAt: _clock().toUtc(),
          notes: MoneyGuard.notes(
            parts[1].trim(),
            GanjoorDefaults.maxNotesLength,
          ),
        ),
      );
      imported++;
    }

    return GanjoorImportResult(imported: imported, skipped: skipped);
  }

  /// Writes every transaction as CSV (`date,description,amount`, negative = debit).
  ///
  /// The plan asks the wallet for CSV export; the .NET CLI only had the import side, so this
  /// is the port's addition — same three columns, so a file it writes imports back.
  Future<int> exportCsv(
    String path, [
    GanjoorFilter filter = const GanjoorFilter(),
  ]) async {
    final rows = await transactions(filter);
    final buffer = StringBuffer('Date,Description,Amount\n');
    for (final tx in rows.reversed) {
      final signed = tx.kind == GanjoorTxKind.income
          ? tx.amount
          : Money.fromMinor(-tx.amount.minorUnits);
      final description = tx.notes.isEmpty ? tx.category : tx.notes;
      buffer
        ..write(tx.date.toIso())
        ..write(',')
        ..write(description.replaceAll(',', ' '))
        ..write(',')
        ..write(signed.toStorage())
        ..write('\n');
    }
    File(path).writeAsStringSync(buffer.toString());
    return rows.length;
  }

  /// Snapshots the wallet so the next change can be undone.
  Future<void> pushUndoSnapshot() => _pushSnapshot();

  /// How many snapshots are stacked.
  Future<int> get undoCount => _store.undoCount;

  // ── internals ──

  Future<void> _pushSnapshot() async => _store.pushUndo(await exportJson());

  Future<void> _clearAll() async {
    for (final tx in await _store.listTransactions()) {
      await _store.removeTransaction(tx.id);
    }
    for (final account in await _store.listAccounts()) {
      await _store.removeAccount(account.id);
    }
    for (final budget in await _store.listBudgets()) {
      await _store.removeBudget(budget.category);
    }
    for (final bill in await _store.listBills()) {
      await _store.removeBill(bill.id);
    }
    for (final goal in await _store.listGoals()) {
      await _store.removeGoal(goal.id);
    }
    for (final debt in await _store.listDebts()) {
      await _store.removeDebt(debt.id);
    }
  }

  Future<GanjoorAccount> _account(String? text) async {
    if (text == null || text.trim().isEmpty) {
      throw ArgumentError.value(text, 'account', 'Must not be blank');
    }
    if (RegExp(r'^[0-9]+$').hasMatch(text)) {
      final id = MoneyGuard.id(text, 'Account');
      final found = await _store.findAccount(id);
      if (found == null) throw GanjoorException('No account #$id.');
      return found;
    }

    final found = await _store.findAccountByName(text);
    if (found == null) {
      throw GanjoorException(
        "No account named '$text'. Create one: "
        'JameJam ganjoor account add $text',
      );
    }
    return found;
  }

  Future<GanjoorTransaction> _transaction(String? idText) async {
    final id = MoneyGuard.id(idText, 'Transaction id');
    final found = await _store.findTransaction(id);
    if (found == null) throw GanjoorException('No transaction #$id.');
    return found;
  }

  Future<GanjoorGoal> _goal(String? idText) async {
    final id = MoneyGuard.id(idText, 'Goal id');
    final found = (await _store.listGoals())
        .where((goal) => goal.id == id)
        .firstOrNull;
    if (found == null) throw GanjoorException('No goal #$id.');
    return found;
  }

  Future<GanjoorDebt> _debt(String? idText) async {
    final id = MoneyGuard.id(idText, 'Debt id');
    final found = (await _store.listDebts())
        .where((debt) => debt.id == id)
        .firstOrNull;
    if (found == null) throw GanjoorException('No debt #$id.');
    return found;
  }

  Future<int> _firstAccountId() async {
    final accounts = await _store.listAccounts();
    if (accounts.isEmpty) {
      throw const GanjoorException(
        'Create an account first: JameJam ganjoor account add <name>',
      );
    }
    return accounts.first.id;
  }

  static int _parseInterval(String text) {
    final parsed = int.tryParse(text.trim());
    if (parsed == null || parsed < 1 || parsed > 365) {
      throw ArgumentError.value(
        text,
        'interval',
        'Interval must be between 1 and 365.',
      );
    }
    return parsed;
  }

  static DateOnly _firstOfMonth(DateOnly date) =>
      DateOnly(date.year, date.month, 1);

  /// Splits a CSV row into at most three parts (`raw.Split(',', 3)`).
  static List<String> _splitCsv(String raw) {
    final parts = <String>[];
    var start = 0;
    for (var i = 0; i < raw.length && parts.length < 2; i++) {
      if (raw[i] == ',') {
        parts.add(raw.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(raw.substring(start));
    return parts;
  }

  /// The three exact date shapes the .NET importer accepted, in its order.
  static DateOnly? _parseCsvDate(String text) {
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (iso != null) {
      return _date(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final slashed = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
    if (slashed == null) return null;
    final first = int.parse(slashed.group(1)!);
    final second = int.parse(slashed.group(2)!);
    final year = int.parse(slashed.group(3)!);

    // `dd/MM/yyyy` first, then `MM/dd/yyyy` — exactly the .NET fallback order.
    return _date(year, second, first) ?? _date(year, first, second);
  }

  static DateOnly? _date(int year, int month, int day) =>
      DateOnly.isValid(year, month, day) ? DateOnly(year, month, day) : null;
}
