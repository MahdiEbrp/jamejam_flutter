/// ganjoor — see doc/ganjoor.md and AGENTS.md
import '../../core/date_only.dart';
import 'money.dart';

class GanjoorException implements Exception {
  const GanjoorException(this.message);

  /// Safe description of the failure.
  final String message;

  @override
  String toString() => 'GanjoorException: $message';
}

enum GanjoorTxKind {
  /// Money added to an account.
  income,

  /// Money removed from an account.
  expense,

  /// Money moved between two accounts (never counted as income or spending).
  transfer,
}

enum GanjoorFrequency {
  /// Every N days.
  daily,

  /// Every N weeks.
  weekly,

  /// Every N months (clamps to month length).
  monthly,

  /// Every N years.
  yearly,
}

class GanjoorAccount {
  const GanjoorAccount({
    required this.id,
    required this.name,
    required this.currency,
    required this.initialBalance,
    required this.createdAt,
    this.isArchived = false,
  });

  /// Stable identifier used by the CLI.
  final int id;

  /// Display name (sanitized, unique case-insensitively).
  final String name;

  /// ISO-style currency code (3 letters).
  final String currency;

  /// Balance before any recorded transaction.
  final Money initialBalance;

  /// When the account was created (UTC).
  final DateTime createdAt;

  /// Archived accounts are hidden from listings but keep their history.
  final bool isArchived;

  GanjoorAccount copyWith({
    int? id,
    String? name,
    String? currency,
    Money? initialBalance,
    DateTime? createdAt,
    bool? isArchived,
  }) => GanjoorAccount(
    id: id ?? this.id,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    initialBalance: initialBalance ?? this.initialBalance,
    createdAt: createdAt ?? this.createdAt,
    isArchived: isArchived ?? this.isArchived,
  );

  @override
  String toString() =>
      'GanjoorAccount(#$id $name $currency ${initialBalance.formatAmount()})';
}

class GanjoorTransaction {
  const GanjoorTransaction({
    required this.id,
    required this.kind,
    required this.accountId,
    required this.amount,
    required this.category,
    required this.date,
    required this.createdAt,
    this.transferToAccountId,
    this.tags = const [],
    this.notes = '',
    this.fromBillId,
  });

  /// Stable identifier used by the CLI.
  final int id;

  /// Income, expense, or transfer.
  final GanjoorTxKind kind;

  /// The account money moved out of (or into, for income).
  final int accountId;

  /// Always positive — the kind carries the direction.
  final Money amount;

  /// Spending/income category (sanitized).
  final String category;

  /// When the movement happened (day precision).
  final DateOnly date;

  /// When the record was created (UTC).
  final DateTime createdAt;

  /// Destination account for transfers; null otherwise.
  final int? transferToAccountId;

  /// Free-form tags (never null).
  final List<String> tags;

  /// Optional details (empty when absent).
  final String notes;

  /// Bill that produced this transaction, when it did.
  final int? fromBillId;

  GanjoorTransaction copyWith({
    int? id,
    GanjoorTxKind? kind,
    int? accountId,
    Money? amount,
    String? category,
    DateOnly? date,
    DateTime? createdAt,
    int? transferToAccountId,
    List<String>? tags,
    String? notes,
    int? fromBillId,
  }) => GanjoorTransaction(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    accountId: accountId ?? this.accountId,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    date: date ?? this.date,
    createdAt: createdAt ?? this.createdAt,
    transferToAccountId: transferToAccountId ?? this.transferToAccountId,
    tags: tags ?? this.tags,
    notes: notes ?? this.notes,
    fromBillId: fromBillId ?? this.fromBillId,
  );

  /// True when the movement touches [accountId] on either side.
  bool touches(int accountId) =>
      this.accountId == accountId || transferToAccountId == accountId;

  @override
  String toString() =>
      'GanjoorTransaction(#$id ${kind.name} ${amount.formatAmount()} $category)';
}

class GanjoorBudget {
  const GanjoorBudget(this.category, this.monthlyLimit);

  /// The capped category.
  final String category;

  /// Maximum planned spending per month.
  final Money monthlyLimit;

  @override
  String toString() =>
      'GanjoorBudget($category ${monthlyLimit.formatAmount()})';
}

class GanjoorBill {
  const GanjoorBill({
    required this.id,
    required this.name,
    required this.amount,
    required this.kind,
    required this.category,
    required this.frequency,
    required this.interval,
    required this.nextDue,
    required this.createdAt,
    this.accountId = 0,
  });

  /// Stable identifier used by the CLI.
  final int id;

  /// Display name (e.g. "Rent", "Payday").
  final String name;

  /// Always positive.
  final Money amount;

  /// Income or expense (transfers cannot repeat).
  final GanjoorTxKind kind;

  /// Applied category.
  final String category;

  /// Repeat schedule.
  final GanjoorFrequency frequency;

  /// Every N days/weeks/months/years (≥ 1).
  final int interval;

  /// The next unrecorded occurrence.
  final DateOnly nextDue;

  /// When the bill was created (UTC).
  final DateTime createdAt;

  /// Account the bill records against.
  final int accountId;

  GanjoorBill copyWith({
    int? id,
    String? name,
    Money? amount,
    GanjoorTxKind? kind,
    String? category,
    GanjoorFrequency? frequency,
    int? interval,
    DateOnly? nextDue,
    DateTime? createdAt,
    int? accountId,
  }) => GanjoorBill(
    id: id ?? this.id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    kind: kind ?? this.kind,
    category: category ?? this.category,
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    nextDue: nextDue ?? this.nextDue,
    createdAt: createdAt ?? this.createdAt,
    accountId: accountId ?? this.accountId,
  );

  @override
  String toString() => 'GanjoorBill(#$id $name ${amount.formatAmount()})';
}

class GanjoorGoal {
  const GanjoorGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.contributed,
    required this.createdAt,
    this.deadline,
  });

  /// Stable identifier used by the CLI.
  final int id;

  /// Display name (e.g. "New laptop").
  final String name;

  /// Amount to reach.
  final Money target;

  /// Amount set aside so far.
  final Money contributed;

  /// Optional target date.
  final DateOnly? deadline;

  /// When the goal was created (UTC).
  final DateTime createdAt;

  /// Completion percent, rounded half away from zero (0 when the target is zero).
  int get percent => contributed.percentOf(target);

  /// True once the goal is at or above the "nearly done" rail.
  bool get nearlyDone => percent >= 90;

  /// True once the target is reached.
  bool get complete => contributed.minorUnits >= target.minorUnits;

  GanjoorGoal copyWith({
    int? id,
    String? name,
    Money? target,
    Money? contributed,
    DateOnly? deadline,
    DateTime? createdAt,
  }) => GanjoorGoal(
    id: id ?? this.id,
    name: name ?? this.name,
    target: target ?? this.target,
    contributed: contributed ?? this.contributed,
    deadline: deadline ?? this.deadline,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  String toString() => 'GanjoorGoal(#$id $name $percent%)';
}

class GanjoorDebt {
  const GanjoorDebt({
    required this.id,
    required this.person,
    required this.amount,
    required this.settled,
    required this.owedByMe,
    required this.createdAt,
    this.dueDate,
    this.notes = '',
  });

  /// Stable identifier used by the CLI.
  final int id;

  /// Counterparty name (sanitized).
  final String person;

  /// Total amount in the base currency.
  final Money amount;

  /// Amount already repaid.
  final Money settled;

  /// True when the user owes the person; false when they owe the user.
  final bool owedByMe;

  /// Optional repayment deadline.
  final DateOnly? dueDate;

  /// Optional details.
  final String notes;

  /// When the debt was recorded (UTC).
  final DateTime createdAt;

  /// Amount still outstanding.
  Money get outstanding => amount - settled;

  /// True once nothing is left to repay.
  bool get settledInFull => settled.minorUnits >= amount.minorUnits;

  GanjoorDebt copyWith({
    int? id,
    String? person,
    Money? amount,
    Money? settled,
    bool? owedByMe,
    DateOnly? dueDate,
    String? notes,
    DateTime? createdAt,
  }) => GanjoorDebt(
    id: id ?? this.id,
    person: person ?? this.person,
    amount: amount ?? this.amount,
    settled: settled ?? this.settled,
    owedByMe: owedByMe ?? this.owedByMe,
    dueDate: dueDate ?? this.dueDate,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  String toString() =>
      'GanjoorDebt(#$id $person ${outstanding.formatAmount()})';
}

class GanjoorCategoryTotal {
  const GanjoorCategoryTotal(this.category, this.amount, this.count);

  /// The category.
  final String category;

  /// Total across the period.
  final Money amount;

  /// Number of transactions.
  final int count;

  @override
  String toString() =>
      'GanjoorCategoryTotal($category ${amount.formatAmount()} ×$count)';
}

class GanjoorCashFlow {
  const GanjoorCashFlow({
    required this.month,
    required this.income,
    required this.expenses,
    required this.byCategory,
  });

  /// The reported month (its first day).
  final DateOnly month;

  /// Total income.
  final Money income;

  /// Total expenses (transfers excluded).
  final Money expenses;

  /// Expense totals per category, largest first.
  final List<GanjoorCategoryTotal> byCategory;

  /// Income minus expenses for the month.
  Money get net => income - expenses;

  @override
  String toString() =>
      'GanjoorCashFlow(${month.toIso()} ${net.formatAmount()})';
}

class GanjoorBudgetStatus {
  const GanjoorBudgetStatus(this.category, this.limit, this.spent);

  /// The capped category.
  final String category;

  /// Monthly limit.
  final Money limit;

  /// Actual spending in the month.
  final Money spent;

  /// Limit minus spent; negative once over budget.
  Money get remaining => limit - spent;

  /// True when spending passed the limit.
  bool get over => spent > limit;

  /// Spending as percent of the limit (0 when the limit is zero).
  int get percentUsed => spent.percentOf(limit);

  @override
  String toString() =>
      'GanjoorBudgetStatus($category ${spent.formatAmount()}/${limit.formatAmount()})';
}

class GanjoorNetWorth {
  const GanjoorNetWorth({
    required this.baseCurrency,
    required this.accounts,
    required this.receivable,
    required this.payable,
  });

  /// Currency all values were converted into.
  final String baseCurrency;

  /// Sum of every account balance.
  final Money accounts;

  /// Outstanding debts owed to the user.
  final Money receivable;

  /// Outstanding debts the user owes.
  final Money payable;

  /// Accounts plus receivable minus payable.
  Money get total => accounts + receivable - payable;

  @override
  String toString() => 'GanjoorNetWorth(${total.formatAmount()} $baseCurrency)';
}

class GanjoorFilter {
  const GanjoorFilter({
    this.accountId,
    this.category,
    this.tag,
    this.month,
    this.kind,
    this.query,
  });

  /// Only this account (either side of a transfer).
  final int? accountId;

  /// Only this category (case-insensitive).
  final String? category;

  /// Only transactions carrying this tag.
  final String? tag;

  /// Only this month.
  final DateOnly? month;

  /// Only this kind.
  final GanjoorTxKind? kind;

  /// Substring match over category, notes, and tags.
  final String? query;

  /// True when nothing is narrowing the ledger.
  bool get isEmpty =>
      accountId == null &&
      category == null &&
      tag == null &&
      month == null &&
      kind == null &&
      (query == null || query!.trim().isEmpty);

  @override
  String toString() => 'GanjoorFilter(account: $accountId, tag: $tag)';
}

class GanjoorApplyResult {
  const GanjoorApplyResult({required this.transactions, required this.bills});

  /// The transactions just recorded.
  final List<GanjoorTransaction> transactions;

  /// The bills that were applied (with advanced due dates).
  final List<GanjoorBill> bills;

  @override
  String toString() =>
      'GanjoorApplyResult(${transactions.length} tx, ${bills.length} bills)';
}

class GanjoorImportResult {
  const GanjoorImportResult({required this.imported, required this.skipped});

  /// Rows recorded.
  final int imported;

  /// Rows skipped (unreadable date or amount).
  final int skipped;

  @override
  String toString() =>
      'GanjoorImportResult($imported imported, $skipped skipped)';
}
