/// ganjoor — see doc/ganjoor.md and AGENTS.md
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/date_only.dart';
import '../../core/sqlite_database.dart';
import 'ganjoor_defaults.dart';
import 'ganjoor_store.dart';
import 'models.dart';
import 'money.dart';

class SqliteGanjoorStore implements GanjoorStore {
  SqliteGanjoorStore(String databasePath)
    : _database = SqliteDatabase(databasePath);

  /// Current schema version written by this build.
  static const int currentSchemaVersion = 1;

  static const String _schemaSql = '''
CREATE TABLE IF NOT EXISTS accounts (
    id              INTEGER PRIMARY KEY,
    name            TEXT NOT NULL,
    currency        TEXT NOT NULL,
    initial_balance TEXT NOT NULL,
    is_archived     INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS transactions (
    id             INTEGER PRIMARY KEY,
    kind           INTEGER NOT NULL,
    account_id     INTEGER NOT NULL,
    amount         TEXT NOT NULL,
    category       TEXT NOT NULL,
    date           TEXT NOT NULL,
    created_at     TEXT NOT NULL,
    transfer_to_id INTEGER,
    tags           TEXT NOT NULL DEFAULT '',
    notes          TEXT NOT NULL DEFAULT '',
    from_bill_id   INTEGER
);
CREATE INDEX IF NOT EXISTS ix_tx_account_date ON transactions(account_id, date);
CREATE INDEX IF NOT EXISTS ix_tx_category ON transactions(category);
CREATE TABLE IF NOT EXISTS budgets (
    category      TEXT PRIMARY KEY,
    monthly_limit TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS bills (
    id         INTEGER PRIMARY KEY,
    name       TEXT NOT NULL,
    amount     TEXT NOT NULL,
    kind       INTEGER NOT NULL,
    category   TEXT NOT NULL,
    account_id INTEGER NOT NULL DEFAULT 1,
    frequency  INTEGER NOT NULL,
    interval   INTEGER NOT NULL,
    next_due   TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS goals (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    target      TEXT NOT NULL,
    contributed TEXT NOT NULL,
    deadline    TEXT,
    created_at  TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS debts (
    id         INTEGER PRIMARY KEY,
    person     TEXT NOT NULL,
    amount     TEXT NOT NULL,
    settled    TEXT NOT NULL,
    owed_by_me INTEGER NOT NULL,
    due_date   TEXT,
    notes      TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS undo_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    payload    TEXT NOT NULL
);
PRAGMA user_version = $currentSchemaVersion;''';

  final SqliteDatabase _database;
  int _undoDepthValue = GanjoorDefaults.undoDepth;

  /// Path of the SQLite database file.
  String get databasePath => _database.databasePath;

  /// Creates the schema (once) and reports the schema version in the file.
  Future<void> initialize() => _database.initialize([_schemaSql]);

  /// Closes the database handle.
  @override
  Future<void> close() => _database.close();

  // ── Accounts ──

  @override
  Future<GanjoorAccount> addAccount(GanjoorAccount account) async {
    final db = await _open();
    final id = await _nextId(db, 'accounts');
    await db.insert('accounts', {
      'id': id,
      'name': account.name,
      'currency': account.currency,
      'initial_balance': account.initialBalance.toStorage(),
      'is_archived': account.isArchived ? 1 : 0,
      'created_at': _stamp(account.createdAt),
    });
    return account.copyWith(id: id);
  }

  @override
  Future<void> updateAccount(GanjoorAccount account) async {
    final db = await _open();
    await db.update(
      'accounts',
      {
        'name': account.name,
        'currency': account.currency,
        'initial_balance': account.initialBalance.toStorage(),
        'is_archived': account.isArchived ? 1 : 0,
        'created_at': _stamp(account.createdAt),
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  @override
  Future<bool> removeAccount(int id) async {
    final db = await _open();
    final removed = await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    return removed > 0;
  }

  @override
  Future<GanjoorAccount?> findAccount(int id) async {
    final db = await _open();
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _account(rows.single);
  }

  @override
  Future<GanjoorAccount?> findAccountByName(String name) async {
    final db = await _open();
    final rows = await db.query(
      'accounts',
      where: 'lower(name) = lower(?)',
      whereArgs: [name],
    );
    return rows.isEmpty ? null : _account(rows.single);
  }

  @override
  Future<List<GanjoorAccount>> listAccounts() async {
    final db = await _open();
    final rows = await db.query('accounts', orderBy: 'id');
    return rows.map(_account).toList(growable: false);
  }

  // ── Transactions ──

  @override
  Future<GanjoorTransaction> addTransaction(
    GanjoorTransaction transaction,
  ) async {
    final db = await _open();
    final id = await _nextId(db, 'transactions');
    await db.insert('transactions', {
      'id': id,
      'kind': transaction.kind.index,
      'account_id': transaction.accountId,
      'amount': transaction.amount.toStorage(),
      'category': transaction.category,
      'date': transaction.date.toIso(),
      'created_at': _stamp(transaction.createdAt),
      'transfer_to_id': transaction.transferToAccountId,
      'tags': transaction.tags.join(','),
      'notes': transaction.notes,
      'from_bill_id': transaction.fromBillId,
    });
    return transaction.copyWith(id: id);
  }

  @override
  Future<void> updateTransaction(GanjoorTransaction transaction) async {
    final db = await _open();
    await db.update(
      'transactions',
      {
        'kind': transaction.kind.index,
        'account_id': transaction.accountId,
        'amount': transaction.amount.toStorage(),
        'category': transaction.category,
        'date': transaction.date.toIso(),
        'created_at': _stamp(transaction.createdAt),
        'transfer_to_id': transaction.transferToAccountId,
        'tags': transaction.tags.join(','),
        'notes': transaction.notes,
        'from_bill_id': transaction.fromBillId,
      },
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  @override
  Future<bool> removeTransaction(int id) async {
    final db = await _open();
    final removed = await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return removed > 0;
  }

  @override
  Future<GanjoorTransaction?> findTransaction(int id) async {
    final db = await _open();
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _transaction(rows.single);
  }

  @override
  Future<List<GanjoorTransaction>> listTransactions() async {
    final db = await _open();
    final rows = await db.query('transactions', orderBy: 'date DESC, id DESC');
    return rows.map(_transaction).toList(growable: false);
  }

  // ── Budgets ──

  @override
  Future<void> setBudget(GanjoorBudget budget) async {
    final db = await _open();
    await db.insert('budgets', {
      'category': budget.category,
      'monthly_limit': budget.monthlyLimit.toStorage(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> removeBudget(String category) async {
    final db = await _open();
    final removed = await db.delete(
      'budgets',
      where: 'lower(category) = lower(?)',
      whereArgs: [category],
    );
    return removed > 0;
  }

  @override
  Future<List<GanjoorBudget>> listBudgets() async {
    final db = await _open();
    final rows = await db.query('budgets', orderBy: 'category');
    return rows
        .map(
          (row) => GanjoorBudget(
            row['category']! as String,
            Money.fromStorage(row['monthly_limit']! as String),
          ),
        )
        .toList(growable: false);
  }

  // ── Bills ──

  @override
  Future<GanjoorBill> addBill(GanjoorBill bill) async {
    final db = await _open();
    final id = await _nextId(db, 'bills');
    await db.insert('bills', {
      'id': id,
      'name': bill.name,
      'amount': bill.amount.toStorage(),
      'kind': bill.kind.index,
      'category': bill.category,
      'account_id': bill.accountId,
      'frequency': bill.frequency.index,
      'interval': bill.interval,
      'next_due': bill.nextDue.toIso(),
      'created_at': _stamp(bill.createdAt),
    });
    return bill.copyWith(id: id);
  }

  @override
  Future<void> updateBill(GanjoorBill bill) async {
    final db = await _open();
    await db.update(
      'bills',
      {
        'name': bill.name,
        'amount': bill.amount.toStorage(),
        'kind': bill.kind.index,
        'category': bill.category,
        'account_id': bill.accountId,
        'frequency': bill.frequency.index,
        'interval': bill.interval,
        'next_due': bill.nextDue.toIso(),
        'created_at': _stamp(bill.createdAt),
      },
      where: 'id = ?',
      whereArgs: [bill.id],
    );
  }

  @override
  Future<bool> removeBill(int id) async {
    final db = await _open();
    final removed = await db.delete('bills', where: 'id = ?', whereArgs: [id]);
    return removed > 0;
  }

  @override
  Future<List<GanjoorBill>> listBills() async {
    final db = await _open();
    final rows = await db.query('bills', orderBy: 'next_due, id');
    return rows
        .map(
          (row) => GanjoorBill(
            id: row['id']! as int,
            name: row['name']! as String,
            amount: Money.fromStorage(row['amount']! as String),
            kind: GanjoorTxKind.values[row['kind']! as int],
            category: row['category']! as String,
            accountId: row['account_id']! as int,
            frequency: GanjoorFrequency.values[row['frequency']! as int],
            interval: row['interval']! as int,
            nextDue: DateOnly.parseIso(row['next_due']! as String),
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        )
        .toList(growable: false);
  }

  // ── Goals ──

  @override
  Future<GanjoorGoal> addGoal(GanjoorGoal goal) async {
    final db = await _open();
    final id = await _nextId(db, 'goals');
    await db.insert('goals', {
      'id': id,
      'name': goal.name,
      'target': goal.target.toStorage(),
      'contributed': goal.contributed.toStorage(),
      'deadline': goal.deadline?.toIso(),
      'created_at': _stamp(goal.createdAt),
    });
    return goal.copyWith(id: id);
  }

  @override
  Future<void> updateGoal(GanjoorGoal goal) async {
    final db = await _open();
    await db.update(
      'goals',
      {
        'name': goal.name,
        'target': goal.target.toStorage(),
        'contributed': goal.contributed.toStorage(),
        'deadline': goal.deadline?.toIso(),
        'created_at': _stamp(goal.createdAt),
      },
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  @override
  Future<bool> removeGoal(int id) async {
    final db = await _open();
    final removed = await db.delete('goals', where: 'id = ?', whereArgs: [id]);
    return removed > 0;
  }

  @override
  Future<List<GanjoorGoal>> listGoals() async {
    final db = await _open();
    final rows = await db.query('goals', orderBy: 'id');
    return rows
        .map(
          (row) => GanjoorGoal(
            id: row['id']! as int,
            name: row['name']! as String,
            target: Money.fromStorage(row['target']! as String),
            contributed: Money.fromStorage(row['contributed']! as String),
            deadline: row['deadline'] == null
                ? null
                : DateOnly.parseIso(row['deadline']! as String),
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        )
        .toList(growable: false);
  }

  // ── Debts ──

  @override
  Future<GanjoorDebt> addDebt(GanjoorDebt debt) async {
    final db = await _open();
    final id = await _nextId(db, 'debts');
    await db.insert('debts', {
      'id': id,
      'person': debt.person,
      'amount': debt.amount.toStorage(),
      'settled': debt.settled.toStorage(),
      'owed_by_me': debt.owedByMe ? 1 : 0,
      'due_date': debt.dueDate?.toIso(),
      'notes': debt.notes,
      'created_at': _stamp(debt.createdAt),
    });
    return debt.copyWith(id: id);
  }

  @override
  Future<void> updateDebt(GanjoorDebt debt) async {
    final db = await _open();
    await db.update(
      'debts',
      {
        'person': debt.person,
        'amount': debt.amount.toStorage(),
        'settled': debt.settled.toStorage(),
        'owed_by_me': debt.owedByMe ? 1 : 0,
        'due_date': debt.dueDate?.toIso(),
        'notes': debt.notes,
        'created_at': _stamp(debt.createdAt),
      },
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  @override
  Future<bool> removeDebt(int id) async {
    final db = await _open();
    final removed = await db.delete('debts', where: 'id = ?', whereArgs: [id]);
    return removed > 0;
  }

  @override
  Future<List<GanjoorDebt>> listDebts() async {
    final db = await _open();
    final rows = await db.query('debts', orderBy: 'id');
    return rows
        .map(
          (row) => GanjoorDebt(
            id: row['id']! as int,
            person: row['person']! as String,
            amount: Money.fromStorage(row['amount']! as String),
            settled: Money.fromStorage(row['settled']! as String),
            owedByMe: (row['owed_by_me']! as int) != 0,
            dueDate: row['due_date'] == null
                ? null
                : DateOnly.parseIso(row['due_date']! as String),
            notes: row['notes']! as String,
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        )
        .toList(growable: false);
  }

  // ── Undo stack ──

  @override
  Future<void> pushUndo(String payload) async {
    if (payload.isEmpty) {
      throw ArgumentError.value(payload, 'payload', 'Must not be empty');
    }
    final db = await _open();
    await db.insert('undo_log', {
      'created_at': _stamp(DateTime.now().toUtc()),
      'payload': payload,
    });
    await _trimUndo(db);
  }

  Future<void> _trimUndo(Database db) async {
    if (_undoDepthValue == 0) {
      await db.delete('undo_log');
      return;
    }
    await db.rawDelete(
      'DELETE FROM undo_log WHERE id < '
      '(SELECT MIN(id) FROM (SELECT id FROM undo_log ORDER BY id DESC LIMIT ?))',
      [_undoDepthValue],
    );
  }

  @override
  Future<String?> popUndo() async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT id, payload FROM undo_log ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) return null;
    await db.delete(
      'undo_log',
      where: 'id = ?',
      whereArgs: [rows.single['id']],
    );
    return rows.single['payload']! as String;
  }

  @override
  Future<int> get undoCount async {
    final db = await _open();
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM undo_log');
    return rows.single['n']! as int;
  }

  @override
  set undoDepth(int value) {
    if (value < 0) {
      throw RangeError.value(value, 'undoDepth', 'Must not be negative');
    }
    _undoDepthValue = value;
  }

  @override
  int get undoDepth => _undoDepthValue;

  // ── helpers ──

  Future<Database> _open() async {
    await initialize();
    return _database.open();
  }

  Future<int> _nextId(Database db, String table) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(id), 0) + 1 AS next FROM $table',
    );
    return rows.single['next']! as int;
  }

  GanjoorAccount _account(Map<String, Object?> row) => GanjoorAccount(
    id: row['id']! as int,
    name: row['name']! as String,
    currency: row['currency']! as String,
    initialBalance: Money.fromStorage(row['initial_balance']! as String),
    isArchived: (row['is_archived']! as int) != 0,
    createdAt: DateTime.parse(row['created_at']! as String),
  );

  GanjoorTransaction _transaction(Map<String, Object?> row) {
    final tags = row['tags']! as String;
    return GanjoorTransaction(
      id: row['id']! as int,
      kind: GanjoorTxKind.values[row['kind']! as int],
      accountId: row['account_id']! as int,
      amount: Money.fromStorage(row['amount']! as String),
      category: row['category']! as String,
      date: DateOnly.parseIso(row['date']! as String),
      createdAt: DateTime.parse(row['created_at']! as String),
      transferToAccountId: row['transfer_to_id'] as int?,
      tags: tags.isEmpty ? const [] : tags.split(','),
      notes: row['notes']! as String,
      fromBillId: row['from_bill_id'] as int?,
    );
  }

  /// Stores an instant as a round-trip ISO-8601 string in UTC.
  static String _stamp(DateTime value) => value.toUtc().toIso8601String();
}
