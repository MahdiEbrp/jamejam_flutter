/// ganjoor — see doc/ganjoor.md and AGENTS.md
import 'ganjoor_defaults.dart';
import 'models.dart';

abstract interface class GanjoorStore {
  /// Inserts an account and returns it with its assigned id.
  Future<GanjoorAccount> addAccount(GanjoorAccount account);

  /// Overwrites an existing account (same id).
  Future<void> updateAccount(GanjoorAccount account);

  /// Removes an account. Returns true when it existed.
  Future<bool> removeAccount(int id);

  /// Gets an account by id, or null.
  Future<GanjoorAccount?> findAccount(int id);

  /// Gets an account by name (case-insensitive), or null.
  Future<GanjoorAccount?> findAccountByName(String name);

  /// Lists all accounts ordered by id.
  Future<List<GanjoorAccount>> listAccounts();

  /// Inserts a transaction and returns it with its assigned id.
  Future<GanjoorTransaction> addTransaction(GanjoorTransaction transaction);

  /// Removes a transaction. Returns true when it existed.
  Future<bool> removeTransaction(int id);

  /// Overwrites an existing transaction (same id).
  Future<void> updateTransaction(GanjoorTransaction transaction);

  /// Gets a transaction by id, or null.
  Future<GanjoorTransaction?> findTransaction(int id);

  /// Lists all transactions, newest record first.
  Future<List<GanjoorTransaction>> listTransactions();

  /// Creates or overwrites the budget for a category.
  Future<void> setBudget(GanjoorBudget budget);

  /// Removes the budget for a category. Returns true when it existed.
  Future<bool> removeBudget(String category);

  /// Lists all budgets ordered by category.
  Future<List<GanjoorBudget>> listBudgets();

  /// Inserts a bill and returns it with its assigned id.
  Future<GanjoorBill> addBill(GanjoorBill bill);

  /// Overwrites an existing bill (same id).
  Future<void> updateBill(GanjoorBill bill);

  /// Removes a bill. Returns true when it existed.
  Future<bool> removeBill(int id);

  /// Lists all bills ordered by next due date.
  Future<List<GanjoorBill>> listBills();

  /// Inserts a goal and returns it with its assigned id.
  Future<GanjoorGoal> addGoal(GanjoorGoal goal);

  /// Overwrites an existing goal (same id).
  Future<void> updateGoal(GanjoorGoal goal);

  /// Removes a goal. Returns true when it existed.
  Future<bool> removeGoal(int id);

  /// Lists all goals ordered by id.
  Future<List<GanjoorGoal>> listGoals();

  /// Inserts a debt and returns it with its assigned id.
  Future<GanjoorDebt> addDebt(GanjoorDebt debt);

  /// Overwrites an existing debt (same id).
  Future<void> updateDebt(GanjoorDebt debt);

  /// Removes a debt. Returns true when it existed.
  Future<bool> removeDebt(int id);

  /// Lists all debts ordered by id.
  Future<List<GanjoorDebt>> listDebts();

  /// Pushes an undo snapshot (the service serializes the state before mutating).
  Future<void> pushUndo(String payload);

  /// Pops the most recent undo snapshot, or null when the stack is empty.
  Future<String?> popUndo();

  /// How many undo snapshots are currently stacked.
  Future<int> get undoCount;

  /// Maximum number of undo snapshots kept.
  ///
  /// Pushing beyond the depth drops the oldest snapshot; values below zero are rejected.
  /// How many snapshots the store keeps (`0` disables undo).
  int get undoDepth;

  set undoDepth(int value);

  /// Closes the underlying store (a no-op for the memory implementation).
  Future<void> close();
}

class MemoryGanjoorStore implements GanjoorStore {
  final List<GanjoorAccount> _accounts = [];
  final List<GanjoorTransaction> _transactions = [];
  final List<GanjoorBudget> _budgets = [];
  final List<GanjoorBill> _bills = [];
  final List<GanjoorGoal> _goals = [];
  final List<GanjoorDebt> _debts = [];
  final List<String> _undo = [];

  int _undoDepthValue = GanjoorDefaults.undoDepth;

  /// The next id for a row list: one past the highest in use, exactly like the SQLite's
  /// `SELECT COALESCE(MAX(id), 0) + 1`.
  ///
  /// The .NET memory store used forward-only counters (`++_accountId`), which meant an
  /// undo re-created every record under a *fresh* id and any id written inside the restored
  /// payload — a transaction's `accountId`, say — dangled. The app ships on SQLite, where a
  /// restore reproduces ids because the id is recomputed from the table, so the port gives
  /// the memory store the same rule and undo restores the wallet exactly in both. See
  /// `docs/TEST_PARITY.md` §5.
  static int _nextId<T>(List<T> rows, int Function(T row) idOf) {
    var highest = 0;
    for (final row in rows) {
      final id = idOf(row);
      if (id > highest) highest = id;
    }
    return highest + 1;
  }

  @override
  Future<GanjoorAccount> addAccount(GanjoorAccount account) async {
    final stored = account.copyWith(id: _nextId(_accounts, (row) => row.id));
    _accounts.add(stored);
    return stored;
  }

  @override
  Future<void> updateAccount(GanjoorAccount account) async {
    _replace(
      _accounts,
      account,
      (existing) => existing.id == account.id,
      account.id,
    );
  }

  @override
  Future<bool> removeAccount(int id) async {
    final before = _accounts.length;
    _accounts.removeWhere((account) => account.id == id);
    return _accounts.length != before;
  }

  @override
  Future<GanjoorAccount?> findAccount(int id) async =>
      _accounts.where((account) => account.id == id).firstOrNull;

  @override
  Future<GanjoorAccount?> findAccountByName(String name) async => _accounts
      .where((account) => account.name.toLowerCase() == name.toLowerCase())
      .firstOrNull;

  @override
  Future<List<GanjoorAccount>> listAccounts() async {
    final result = [..._accounts]..sort((a, b) => a.id.compareTo(b.id));
    return result;
  }

  @override
  Future<GanjoorTransaction> addTransaction(
    GanjoorTransaction transaction,
  ) async {
    final stored = transaction.copyWith(
      id: _nextId(_transactions, (row) => row.id),
    );
    _transactions.add(stored);
    return stored;
  }

  @override
  Future<bool> removeTransaction(int id) async {
    final before = _transactions.length;
    _transactions.removeWhere((transaction) => transaction.id == id);
    return _transactions.length != before;
  }

  @override
  Future<void> updateTransaction(GanjoorTransaction transaction) async {
    _replace(
      _transactions,
      transaction,
      (existing) => existing.id == transaction.id,
      transaction.id,
    );
  }

  @override
  Future<GanjoorTransaction?> findTransaction(int id) async =>
      _transactions.where((transaction) => transaction.id == id).firstOrNull;

  @override
  Future<List<GanjoorTransaction>> listTransactions() async {
    final result = [..._transactions]
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    return result;
  }

  @override
  Future<void> setBudget(GanjoorBudget budget) async {
    _budgets
      ..removeWhere(
        (existing) =>
            existing.category.toLowerCase() == budget.category.toLowerCase(),
      )
      ..add(budget);
  }

  @override
  Future<bool> removeBudget(String category) async {
    final before = _budgets.length;
    _budgets.removeWhere(
      (existing) => existing.category.toLowerCase() == category.toLowerCase(),
    );
    return _budgets.length != before;
  }

  @override
  Future<List<GanjoorBudget>> listBudgets() async {
    final result = [..._budgets]
      ..sort(
        (a, b) => a.category.toLowerCase().compareTo(b.category.toLowerCase()),
      );
    return result;
  }

  @override
  Future<GanjoorBill> addBill(GanjoorBill bill) async {
    final stored = bill.copyWith(id: _nextId(_bills, (row) => row.id));
    _bills.add(stored);
    return stored;
  }

  @override
  Future<void> updateBill(GanjoorBill bill) async {
    _replace(_bills, bill, (existing) => existing.id == bill.id, bill.id);
  }

  @override
  Future<bool> removeBill(int id) async {
    final before = _bills.length;
    _bills.removeWhere((bill) => bill.id == id);
    return _bills.length != before;
  }

  @override
  Future<List<GanjoorBill>> listBills() async {
    final result = [..._bills]
      ..sort((a, b) {
        final byDue = a.nextDue.compareTo(b.nextDue);
        return byDue != 0 ? byDue : a.id.compareTo(b.id);
      });
    return result;
  }

  @override
  Future<GanjoorGoal> addGoal(GanjoorGoal goal) async {
    final stored = goal.copyWith(id: _nextId(_goals, (row) => row.id));
    _goals.add(stored);
    return stored;
  }

  @override
  Future<void> updateGoal(GanjoorGoal goal) async {
    _replace(_goals, goal, (existing) => existing.id == goal.id, goal.id);
  }

  @override
  Future<bool> removeGoal(int id) async {
    final before = _goals.length;
    _goals.removeWhere((goal) => goal.id == id);
    return _goals.length != before;
  }

  @override
  Future<List<GanjoorGoal>> listGoals() async {
    final result = [..._goals]..sort((a, b) => a.id.compareTo(b.id));
    return result;
  }

  @override
  Future<GanjoorDebt> addDebt(GanjoorDebt debt) async {
    final stored = debt.copyWith(id: _nextId(_debts, (row) => row.id));
    _debts.add(stored);
    return stored;
  }

  @override
  Future<void> updateDebt(GanjoorDebt debt) async {
    _replace(_debts, debt, (existing) => existing.id == debt.id, debt.id);
  }

  @override
  Future<bool> removeDebt(int id) async {
    final before = _debts.length;
    _debts.removeWhere((debt) => debt.id == id);
    return _debts.length != before;
  }

  @override
  Future<List<GanjoorDebt>> listDebts() async {
    final result = [..._debts]..sort((a, b) => a.id.compareTo(b.id));
    return result;
  }

  @override
  Future<void> pushUndo(String payload) async {
    if (payload.isEmpty) {
      throw ArgumentError.value(payload, 'payload', 'Must not be empty');
    }
    _undo.add(payload);

    if (_undoDepthValue == 0) {
      _undo.clear();
      return;
    }
    while (_undo.length > _undoDepthValue) {
      _undo.removeAt(0);
    }
  }

  @override
  Future<String?> popUndo() async {
    if (_undo.isEmpty) return null;
    return _undo.removeLast();
  }

  @override
  Future<int> get undoCount async => _undo.length;

  @override
  set undoDepth(int value) {
    if (value < 0) {
      throw RangeError.value(value, 'undoDepth', 'Must not be negative');
    }
    _undoDepthValue = value;
  }

  @override
  int get undoDepth => _undoDepthValue;

  @override
  Future<void> close() async {}

  /// Replaces the record with the same id, or throws (the .NET `Replace` contract).
  void _replace<T>(
    List<T> list,
    T value,
    bool Function(T existing) matches,
    int id,
  ) {
    final index = list.indexWhere(matches);
    if (index < 0) {
      throw StateError('No record with id $id to update.');
    }
    list[index] = value;
  }
}
