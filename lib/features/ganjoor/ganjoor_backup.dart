/// ganjoor — see doc/ganjoor.md and AGENTS.md
import 'dart:convert';

import '../../core/date_only.dart';
import 'models.dart';
import 'money.dart';

abstract final class GanjoorBackup {
  /// Current backup format version.
  static const int currentVersion = 1;

  /// Serializes the wallet state (entities in id order).
  static String toJson({
    required List<GanjoorAccount> accounts,
    required List<GanjoorTransaction> transactions,
    required List<GanjoorBudget> budgets,
    required List<GanjoorBill> bills,
    required List<GanjoorGoal> goals,
    required List<GanjoorDebt> debts,
    DateTime? exportedAt,
  }) {
    final sortedAccounts = [...accounts]..sort((a, b) => a.id.compareTo(b.id));
    final sortedTransactions = [...transactions]
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedBudgets = [...budgets]
      ..sort(
        (a, b) => a.category.toLowerCase().compareTo(b.category.toLowerCase()),
      );
    final sortedBills = [...bills]..sort((a, b) => a.id.compareTo(b.id));
    final sortedGoals = [...goals]..sort((a, b) => a.id.compareTo(b.id));
    final sortedDebts = [...debts]..sort((a, b) => a.id.compareTo(b.id));

    final document = <String, Object?>{
      'version': currentVersion,
      'exportedAt': (exportedAt ?? DateTime.now().toUtc()).toIso8601String(),
      'accounts': sortedAccounts.map(accountToJson).toList(),
      'transactions': sortedTransactions.map(transactionToJson).toList(),
      'budgets': sortedBudgets
          .map(
            (budget) => {
              'category': budget.category,
              'monthlyLimit': budget.monthlyLimit.toStorage(),
            },
          )
          .toList(),
      'bills': sortedBills.map(billToJson).toList(),
      'goals': sortedGoals.map(goalToJson).toList(),
      'debts': sortedDebts.map(debtToJson).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(document);
  }

  /// Parses and validates a backup file.
  ///
  /// Throws [ArgumentError] for an unknown version or an unreadable structure — the .NET
  /// `ArgumentException` contract, message for message.
  static GanjoorBackupFile fromJson(String json) {
    if (json.trim().isEmpty) {
      throw ArgumentError.value(json, 'json', 'Must not be empty');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const FormatException('The backup is not a valid Ganjoor file.');
    }

    if (decoded is! Map<String, Object?>) {
      throw const FormatException('The backup is not a valid Ganjoor file.');
    }

    final version = decoded['version'];
    if (version == null) {
      throw const FormatException('The backup is empty.');
    }

    if (version is! int || version != currentVersion) {
      throw FormatException(
        'Unsupported backup version $version '
        '(this Ganjoor reads version $currentVersion).',
      );
    }

    return GanjoorBackupFile.fromJson(decoded);
  }

  /// Account record inside a backup.
  static Map<String, Object?> accountToJson(GanjoorAccount account) => {
    'id': account.id,
    'name': account.name,
    'currency': account.currency,
    'initialBalance': account.initialBalance.toStorage(),
    'isArchived': account.isArchived,
    'createdAt': account.createdAt.toUtc().toIso8601String(),
  };

  /// Transaction record inside a backup.
  static Map<String, Object?> transactionToJson(GanjoorTransaction tx) => {
    'id': tx.id,
    'kind': tx.kind.index,
    'accountId': tx.accountId,
    'amount': tx.amount.toStorage(),
    'category': tx.category,
    'date': tx.date.toIso(),
    'createdAt': tx.createdAt.toUtc().toIso8601String(),
    if (tx.transferToAccountId != null)
      'transferToAccountId': tx.transferToAccountId,
    'tags': tx.tags,
    'notes': tx.notes,
    if (tx.fromBillId != null) 'fromBillId': tx.fromBillId,
  };

  /// Bill record inside a backup.
  static Map<String, Object?> billToJson(GanjoorBill bill) => {
    'id': bill.id,
    'name': bill.name,
    'amount': bill.amount.toStorage(),
    'kind': bill.kind.index,
    'category': bill.category,
    'accountId': bill.accountId,
    'frequency': bill.frequency.index,
    'interval': bill.interval,
    'nextDue': bill.nextDue.toIso(),
    'createdAt': bill.createdAt.toUtc().toIso8601String(),
  };

  /// Goal record inside a backup.
  static Map<String, Object?> goalToJson(GanjoorGoal goal) => {
    'id': goal.id,
    'name': goal.name,
    'target': goal.target.toStorage(),
    'contributed': goal.contributed.toStorage(),
    if (goal.deadline != null) 'deadline': goal.deadline!.toIso(),
    'createdAt': goal.createdAt.toUtc().toIso8601String(),
  };

  /// Debt record inside a backup.
  static Map<String, Object?> debtToJson(GanjoorDebt debt) => {
    'id': debt.id,
    'person': debt.person,
    'amount': debt.amount.toStorage(),
    'settled': debt.settled.toStorage(),
    'owedByMe': debt.owedByMe,
    if (debt.dueDate != null) 'dueDate': debt.dueDate!.toIso(),
    'notes': debt.notes,
    'createdAt': debt.createdAt.toUtc().toIso8601String(),
  };
}

class GanjoorBackupFile {
  const GanjoorBackupFile({
    required this.version,
    required this.exportedAt,
    required this.accounts,
    required this.transactions,
    required this.budgets,
    required this.bills,
    required this.goals,
    required this.debts,
  });

  /// Format version (always [GanjoorBackup.currentVersion] once parsed).
  final int version;

  /// When the file was written.
  final String exportedAt;

  /// Account records.
  final List<GanjoorAccount> accounts;

  /// Transaction records.
  final List<GanjoorTransaction> transactions;

  /// Budget records.
  final List<GanjoorBudget> budgets;

  /// Bill records.
  final List<GanjoorBill> bills;

  /// Goal records.
  final List<GanjoorGoal> goals;

  /// Debt records.
  final List<GanjoorDebt> debts;

  /// Rebuilds the document from decoded JSON, filling in defaults for absent optionals.
  factory GanjoorBackupFile.fromJson(Map<String, Object?> json) {
    List<Map<String, Object?>> list(String key) {
      final raw = json[key];
      if (raw == null) return const [];
      if (raw is! List) {
        throw FormatException('The backup is not a valid Ganjoor file ($key).');
      }
      return raw.whereType<Map<String, Object?>>().toList(growable: false);
    }

    int intOf(Map<String, Object?> row, String key, {int? fallback}) {
      final value = row[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (fallback != null) return fallback;
      throw FormatException('The backup is not a valid Ganjoor file ($key).');
    }

    String stringOf(
      Map<String, Object?> row,
      String key, [
      String fallback = '',
    ]) {
      final value = row[key];
      return value is String ? value : fallback;
    }

    num numOf(Map<String, Object?> row, String key, [num fallback = 0]) {
      final value = row[key];
      return value is num ? value : fallback;
    }

    return GanjoorBackupFile(
      version: intOf(json, 'version', fallback: GanjoorBackup.currentVersion),
      exportedAt: stringOf(json, 'exportedAt'),
      accounts: [
        for (final row in list('accounts'))
          GanjoorAccount(
            id: intOf(row, 'id'),
            name: stringOf(row, 'name'),
            currency: stringOf(row, 'currency'),
            initialBalance: Money.fromStorage(stringOf(row, 'initialBalance')),
            isArchived: row['isArchived'] == true,
            createdAt: DateTime.parse(stringOf(row, 'createdAt')).toUtc(),
          ),
      ],
      transactions: [
        for (final row in list('transactions'))
          GanjoorTransaction(
            id: intOf(row, 'id'),
            kind: GanjoorTxKind.values[intOf(row, 'kind')],
            accountId: intOf(row, 'accountId'),
            amount: Money.fromStorage(stringOf(row, 'amount')),
            category: stringOf(row, 'category'),
            date: DateOnly.parseIso(stringOf(row, 'date')),
            createdAt: DateTime.parse(stringOf(row, 'createdAt')).toUtc(),
            transferToAccountId: row['transferToAccountId'] == null
                ? null
                : (row['transferToAccountId']! as num).toInt(),
            tags: [
              for (final tag in (row['tags'] as List? ?? const []))
                if (tag is String) tag,
            ],
            notes: stringOf(row, 'notes'),
            fromBillId: row['fromBillId'] == null
                ? null
                : (row['fromBillId']! as num).toInt(),
          ),
      ],
      budgets: [
        for (final row in list('budgets'))
          GanjoorBudget(
            stringOf(row, 'category'),
            Money.fromStorage(stringOf(row, 'monthlyLimit')),
          ),
      ],
      bills: [
        for (final row in list('bills'))
          GanjoorBill(
            id: intOf(row, 'id'),
            name: stringOf(row, 'name'),
            amount: Money.fromStorage(stringOf(row, 'amount')),
            kind: GanjoorTxKind.values[intOf(row, 'kind')],
            category: stringOf(row, 'category'),
            accountId: intOf(row, 'accountId', fallback: 1),
            frequency: GanjoorFrequency.values[intOf(row, 'frequency')],
            interval: numOf(row, 'interval', 1).toInt(),
            nextDue: DateOnly.parseIso(stringOf(row, 'nextDue')),
            createdAt: DateTime.parse(stringOf(row, 'createdAt')).toUtc(),
          ),
      ],
      goals: [
        for (final row in list('goals'))
          GanjoorGoal(
            id: intOf(row, 'id'),
            name: stringOf(row, 'name'),
            target: Money.fromStorage(stringOf(row, 'target')),
            contributed: Money.fromStorage(stringOf(row, 'contributed')),
            deadline: row['deadline'] == null
                ? null
                : DateOnly.parseIso(stringOf(row, 'deadline')),
            createdAt: DateTime.parse(stringOf(row, 'createdAt')).toUtc(),
          ),
      ],
      debts: [
        for (final row in list('debts'))
          GanjoorDebt(
            id: intOf(row, 'id'),
            person: stringOf(row, 'person'),
            amount: Money.fromStorage(stringOf(row, 'amount')),
            settled: Money.fromStorage(stringOf(row, 'settled')),
            owedByMe: row['owedByMe'] == true,
            dueDate: row['dueDate'] == null
                ? null
                : DateOnly.parseIso(stringOf(row, 'dueDate')),
            notes: stringOf(row, 'notes'),
            createdAt: DateTime.parse(stringOf(row, 'createdAt')).toUtc(),
          ),
      ],
    );
  }
}
