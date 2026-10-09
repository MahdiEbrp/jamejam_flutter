/// ganjoor — see doc/ganjoor.md and AGENTS.md
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/date_only.dart';
import '../settings/setting_keys.dart';
import '../settings/settings_controller.dart';
import '../soroush/ai_funnel.dart';
import 'finance_assistant.dart';
import 'ganjoor_defaults.dart';
import 'ganjoor_service.dart';
import 'models.dart';
import 'money.dart';

class GanjoorBudgetAlert {
  /// Wraps a budget status.
  const GanjoorBudgetAlert(this.status);

  /// The status behind the alert (category, limit, spent, percent).
  final GanjoorBudgetStatus status;

  /// True once spending passed the limit.
  bool get over => status.over;

  /// True when spending reached the warn threshold but is not over yet.
  bool get close =>
      !status.over && status.percentUsed >= GanjoorDefaults.budgetWarnPercent;

  @override
  String toString() => 'GanjoorBudgetAlert(${status.category})';
}

class GanjoorController extends ChangeNotifier {
  /// Wires the service, the optional settings store (`ganjoor.currency`), and the AI funnel.
  GanjoorController({
    required GanjoorService service,
    SettingsController? settings,
    AiFunnel? funnel,
    FinanceAssistant? assistant,
    String Function(String key)? environment,
  }) : _service = service,
       _settings = settings,
       _funnel = funnel,
       _assistant = assistant ?? FinanceAssistant(service.options),
       _environment = environment ?? ((_) => '');

  final GanjoorService _service;
  final SettingsController? _settings;
  final AiFunnel? _funnel;
  final FinanceAssistant _assistant;
  final String Function(String key) _environment;

  List<GanjoorAccount> _accounts = const [];
  Map<int, Money> _balances = const {};
  List<GanjoorTransaction> _transactions = const [];
  List<GanjoorBudgetStatus> _budgets = const [];
  GanjoorCashFlow? _cashFlow;
  List<GanjoorBill> _bills = const [];
  List<GanjoorGoal> _goals = const [];
  List<GanjoorDebt> _debts = const [];
  GanjoorNetWorth? _netWorth;
  List<String> _knownCategories = const [];
  List<GanjoorBudgetAlert> _alerts = const [];

  int? _accountFilter;
  String? _categoryFilter;
  GanjoorTxKind? _kindFilter;
  DateOnly? _monthFilter;
  String _query = '';
  bool _includeArchived = true;

  String? _error;
  String? _message;
  bool _busy = false;
  bool _aiBusy = false;
  String? _aiAnswer;
  String _aiKind = '';
  String? _aiQuestion;
  String? _suggestedCategory;
  int? _suggestedFor;
  bool _undoAvailable = false;
  bool _disposed = false;

  // ── Reads ──

  /// The wallet service in use (the screen reads its options and its `today`).
  GanjoorService get service => _service;

  /// Accounts, archived ones included unless the filter says otherwise.
  List<GanjoorAccount> get accounts => _accounts;

  /// Current balance per account id.
  Map<int, Money> get balances => _balances;

  /// The ledger, newest first, as the filters leave it.
  List<GanjoorTransaction> get transactions => _transactions;

  /// Budget statuses for the selected month.
  List<GanjoorBudgetStatus> get budgets => _budgets;

  /// Budgets at or past the warn threshold (the CLI's `⚠ close` / `⚠ Over`).
  List<GanjoorBudgetAlert> get alerts => _alerts;

  /// Income/expense totals and the category breakdown for the selected month.
  GanjoorCashFlow? get cashFlow => _cashFlow;

  /// Every bill, in id order.
  List<GanjoorBill> get bills => _bills;

  /// Bills whose due date has arrived.
  List<GanjoorBill> get dueBills =>
      _bills.where((bill) => bill.nextDue <= _service.today).toList();

  /// Every goal.
  List<GanjoorGoal> get goals => _goals;

  /// Every debt, unsettled first.
  List<GanjoorDebt> get debts => _debts;

  /// Net worth in the base currency, or null before the first refresh (or when a rate is
  /// missing — the error is then on [error]).
  GanjoorNetWorth? get netWorth => _netWorth;

  /// Distinct categories: budgets first, then history (what the AI is offered).
  List<String> get knownCategories => _knownCategories;

  /// The active account filter, or null.
  int? get accountFilter => _accountFilter;

  /// The active category filter, or null.
  String? get categoryFilter => _categoryFilter;

  /// The active kind filter, or null.
  GanjoorTxKind? get kindFilter => _kindFilter;

  /// The month the reports cover (null = the current month).
  DateOnly? get monthFilter => _monthFilter;

  /// The month the reports actually use.
  DateOnly get reportMonth =>
      _monthFilter ?? DateOnly(_service.today.year, _service.today.month, 1);

  /// The search text (empty = no query).
  String get query => _query;

  /// True when archived accounts are listed too.
  bool get includeArchived => _includeArchived;

  /// True when any filter is narrowing the ledger.
  bool get hasFilters =>
      _accountFilter != null ||
      _categoryFilter != null ||
      _kindFilter != null ||
      _monthFilter != null ||
      _query.trim().isNotEmpty;

  /// True while an async action is running.
  bool get busy => _busy;

  /// True while an AI call is in flight.
  bool get aiBusy => _aiBusy;

  /// True when the AI surface is reachable at all.
  bool get aiAvailable => _funnel != null;

  /// The last error message, or null. Already human-readable and secret-free.
  String? get error => _error;

  /// The last success message, or null.
  String? get message => _message;

  /// The last AI answer, or null.
  String? get aiAnswer => _aiAnswer;

  /// Which AI action produced [aiAnswer]: `insights`, `ask`, or `categorize`.
  String get aiKind => _aiKind;

  /// The question the last `ask` used, or null.
  String? get aiQuestion => _aiQuestion;

  /// The category the last categorize call proposed, or null when it proposed none.
  String? get suggestedCategory => _suggestedCategory;

  /// The transaction the last categorize call looked at, or null.
  int? get suggestedFor => _suggestedFor;

  /// True while the wallet has a snapshot to restore.
  bool get undoAvailable => _undoAvailable;

  /// The base currency reports convert into.
  String get baseCurrency => _service.options.defaultCurrency;

  /// The account behind [id], or null.
  GanjoorAccount? accountById(int? id) {
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// The account name shown next to a transaction.
  String accountNameOf(GanjoorTransaction tx) =>
      accountById(tx.touches(tx.accountId) ? tx.accountId : null)?.name ??
      'Account ${tx.accountId}';

  /// The name of the account a transfer landed in, or null.
  String? transferTargetName(GanjoorTransaction tx) =>
      accountById(tx.transferToAccountId)?.name;

  /// The current balance of [account].
  Money balanceOf(GanjoorAccount account) =>
      _balances[account.id] ?? account.initialBalance;

  /// Total across every account, converted into the base currency.
  ///
  /// Returns null when a rate is missing — [error] then says which one.
  Money? get totalBalance => _netWorth?.accounts;

  // ── Lifecycle ──

  /// Loads the wallet for the first time (idempotent; safe from `initState`).
  Future<void> initialize() async {
    if (_accounts.isNotEmpty) return;
    await refresh();
  }

  /// Re-reads every pane: accounts and balances, the filtered ledger, budgets, reports,
  /// bills, goals, debts, known categories, and the undo depth.
  Future<void> refresh() async {
    await _guard(() async {
      _accounts = await _service.accounts(includeArchived: _includeArchived);
      _balances = {
        for (final account in _accounts)
          account.id: await _service.balanceOf(account),
      };
      _transactions = await _service.transactions(_filter());
      _budgets = await _service.budgetStatuses(reportMonth);
      _alerts = [
        for (final status in _budgets)
          if (status.over ||
              status.percentUsed >= GanjoorDefaults.budgetWarnPercent)
            GanjoorBudgetAlert(status),
      ];
      _cashFlow = await _service.cashFlow(reportMonth);
      _bills = await _service.store.listBills();
      _goals = await _service.goals();
      _debts = await _service.debts();
      _knownCategories = await _service.knownCategories();
      _undoAvailable = await _service.store.undoCount > 0;
      _netWorth = await _readNetWorth();
    });
  }

  /// Net worth, swallowing only the missing-rate case (the rest of the screen still works).
  Future<GanjoorNetWorth?> _readNetWorth() async {
    try {
      return await _service.netWorth();
    } on GanjoorException catch (failure) {
      _error = failure.message;
      return null;
    }
  }

  // ── Filters ──

  /// Filters the ledger to one account (`null` clears it).
  Future<void> setAccountFilter(int? id) async {
    _accountFilter = id;
    await refresh();
  }

  /// Filters the ledger to one category (`null` clears it).
  Future<void> setCategoryFilter(String? category) async {
    _categoryFilter = (category == null || category.trim().isEmpty)
        ? null
        : category.trim();
    await refresh();
  }

  /// Filters the ledger to one kind (`null` clears it).
  Future<void> setKindFilter(GanjoorTxKind? kind) async {
    _kindFilter = kind;
    await refresh();
  }

  /// Sets the month the reports and the ledger cover (`null` = the current month).
  Future<void> setMonthFilter(DateOnly? month) async {
    _monthFilter = month;
    await refresh();
  }

  /// Sets the ledger search text.
  Future<void> setQuery(String value) async {
    _query = value;
    await refresh();
  }

  /// Shows or hides archived accounts.
  Future<void> setIncludeArchived(bool value) async {
    _includeArchived = value;
    await refresh();
  }

  /// Clears every filter.
  Future<void> clearFilters() async {
    _accountFilter = null;
    _categoryFilter = null;
    _kindFilter = null;
    _monthFilter = null;
    _query = '';
    await refresh();
  }

  // ── Accounts ──

  /// Creates an account. An empty [currency] takes `ganjoor.currency`, else the base one.
  Future<GanjoorAccount?> addAccount(
    String name, {
    String? currency,
    String? initialBalance,
  }) async {
    GanjoorAccount? created;
    await _guard(() async {
      created = await _service.addAccount(
        name,
        await _currencyOrDefault(currency),
        initialBalance,
      );
      await refresh();
      _message = "Account '${created!.name}' created.";
    });
    return created;
  }

  /// Renames an account.
  Future<void> renameAccount(int id, String name) async {
    await _guard(() async {
      final renamed = await _service.renameAccount('$id', name);
      await refresh();
      _message = "Account renamed to '${renamed.name}'.";
    });
  }

  /// Archives or restores an account.
  Future<void> archiveAccount(int id, bool archived) async {
    await _guard(() async {
      final updated = await _service.archiveAccount('$id', archived);
      await refresh();
      _message = archived
          ? "Archived ${updated.name}."
          : "Unarchived ${updated.name}.";
    });
  }

  /// Deletes an account. Without [force] the service refuses while it holds history.
  Future<void> removeAccount(int id, {bool force = false}) async {
    await _guard(() async {
      final removed = await _service.removeAccount('$id', force: force);
      await refresh();
      _message = 'Account removed ($removed transaction(s) deleted).';
    });
  }

  /// Resolves the currency for a new account: the form's value, else the setting, else base.
  Future<String?> _currencyOrDefault(String? requested) async {
    if (requested != null && requested.trim().isNotEmpty) return requested;
    final fromSettings = (await _settings?.read(
      SettingKeys.ganjoorCurrency,
    ))?.trim();
    return (fromSettings == null || fromSettings.isEmpty) ? null : fromSettings;
  }

  // ── Transactions ──

  /// Records an expense.
  Future<GanjoorTransaction?> spend(
    String account,
    String amount,
    String category, {
    String? tags,
    String? notes,
    String? date,
  }) => _record(account, amount, category, false, tags, notes, date);

  /// Records income.
  Future<GanjoorTransaction?> earn(
    String account,
    String amount,
    String category, {
    String? tags,
    String? notes,
    String? date,
  }) => _record(account, amount, category, true, tags, notes, date);

  Future<GanjoorTransaction?> _record(
    String account,
    String amount,
    String category,
    bool income,
    String? tags,
    String? notes,
    String? date,
  ) async {
    GanjoorTransaction? created;
    await _guard(() async {
      created = await _service.record(
        account,
        amount,
        category,
        income,
        tags: tags,
        notes: notes,
        date: date,
      );
      await refresh();
      final status = _statusFor(created!.category);
      if (status != null && status.over) {
        _message =
            'Over budget: ${status.category} — ${status.spent.formatAmount()} of '
            '${status.limit.formatAmount()}.';
      } else if (status != null &&
          status.percentUsed >= GanjoorDefaults.budgetWarnPercent) {
        _message =
            'Budget check: ${status.category} at ${status.percentUsed}% — '
            '${status.remaining.formatAmount()} left this month.';
      } else {
        _message = '#${created!.id} recorded.';
      }
    });
    return created;
  }

  GanjoorBudgetStatus? _statusFor(String category) {
    for (final status in _budgets) {
      if (status.category.toLowerCase() == category.trim().toLowerCase()) {
        return status;
      }
    }
    return null;
  }

  /// Records a transfer between two accounts.
  Future<GanjoorTransaction?> transfer(
    String from,
    String to,
    String amount, {
    String? notes,
    String? date,
  }) async {
    GanjoorTransaction? created;
    await _guard(() async {
      created = await _service.transfer(
        from,
        to,
        amount,
        notes: notes,
        date: date,
      );
      await refresh();
      _message = 'Transferred ${created!.amount.formatAmount()}.';
    });
    return created;
  }

  /// Sets a new category on one transaction.
  Future<void> recategorize(int id, String category) async {
    await _guard(() async {
      final updated = await _service.recategorize('$id', category);
      await refresh();
      _message = '#${updated.id} categorized as ${updated.category}.';
    });
  }

  /// Deletes one transaction.
  Future<void> deleteTransaction(int id) async {
    await _guard(() async {
      await _service.deleteTransaction('$id');
      await refresh();
      _message = 'Transaction #$id removed.';
    });
  }

  // ── Budgets ──

  /// Sets a monthly cap for a category.
  Future<void> setBudget(String category, String limit) async {
    await _guard(() async {
      final budget = await _service.setBudget(category, limit);
      await refresh();
      _message =
          'Budget set: ${budget.category} ≤ ${budget.monthlyLimit.formatAmount()} '
          'per month.';
    });
  }

  /// Removes a budget.
  Future<void> removeBudget(String category) async {
    await _guard(() async {
      final removed = await _service.removeBudget(category);
      await refresh();
      _message = 'Budget removed: ${removed.category}.';
    });
  }

  // ── Bills ──

  /// Adds a repeating bill or income.
  Future<GanjoorBill?> addBill(
    String name,
    String amount,
    String kind,
    String category,
    String frequency, {
    String? interval,
    String? next,
    String? account,
  }) async {
    GanjoorBill? created;
    await _guard(() async {
      created = await _service.addBill(
        name,
        amount,
        kind,
        category,
        frequency,
        intervalText: interval,
        nextText: next,
        accountText: account,
      );
      await refresh();
      final bill = created!;
      _message = 'Added bill #${bill.id}: ${bill.name}.';
    });
    return created;
  }

  /// Removes a bill.
  Future<void> removeBill(int id) async {
    await _guard(() async {
      final removed = await _service.removeBill('$id');
      await refresh();
      _message = "Removed bill '${removed.name}'.";
    });
  }

  /// Records every bill that has come due and advances the schedules.
  Future<GanjoorApplyResult?> applyDueBills() async {
    GanjoorApplyResult? result;
    await _guard(() async {
      result = await _service.applyDueBills();
      await refresh();
      _message = result!.transactions.isEmpty
          ? 'Nothing was due.'
          : 'Recorded ${result!.transactions.length} bill occurrence(s).';
    });
    return result;
  }

  // ── Goals ──

  /// Creates a savings goal.
  Future<GanjoorGoal?> addGoal(
    String name,
    String target, {
    String? deadline,
  }) async {
    GanjoorGoal? created;
    await _guard(() async {
      created = await _service.addGoal(name, target, deadline);
      await refresh();
      _message = "Goal '${created!.name}' created.";
    });
    return created;
  }

  /// Moves money into a goal.
  Future<void> contribute(int id, String amount) async {
    await _guard(() async {
      final goal = await _service.contribute('$id', amount);
      await refresh();
      _message = "Goal '${goal.name}' at ${goal.percent}%.";
    });
  }

  /// Takes money back out of a goal.
  Future<void> withdraw(int id, String amount) async {
    await _guard(() async {
      final goal = await _service.withdraw('$id', amount);
      await refresh();
      _message = "Goal '${goal.name}' at ${goal.percent}%.";
    });
  }

  /// Removes a goal.
  Future<void> removeGoal(int id) async {
    await _guard(() async {
      final removed = await _service.removeGoal('$id');
      await refresh();
      _message = "Removed goal '${removed.name}'.";
    });
  }

  // ── Debts ──

  /// Records a personal debt.
  Future<GanjoorDebt?> addDebt(
    String person,
    String amount, {
    required bool owedByMe,
    String? due,
    String? notes,
  }) async {
    GanjoorDebt? created;
    await _guard(() async {
      created = await _service.addDebt(
        person,
        amount,
        owedByMe,
        due: due,
        notes: notes,
      );
      await refresh();
      final debt = created!;
      _message = debt.settledInFull
          ? 'Debt #${debt.id} (${debt.person}) fully settled.'
          : 'Debt #${debt.id} recorded.';
    });
    return created;
  }

  /// Records a (partial) repayment.
  Future<void> settleDebt(int id, String amount) async {
    await _guard(() async {
      final debt = await _service.settleDebt('$id', amount);
      await refresh();
      _message = debt.settledInFull
          ? 'Debt #${debt.id} (${debt.person}) fully settled.'
          : 'Debt #${debt.id}: ${debt.outstanding.formatAmount()} outstanding.';
    });
    return;
  }

  /// Removes a debt.
  Future<void> removeDebt(int id) async {
    await _guard(() async {
      final removed = await _service.removeDebt('$id');
      await refresh();
      _message = 'Removed debt #${removed.id} (${removed.person}).';
    });
  }

  // ── Undo, backup, CSV ──

  /// Reverts the last mutating command.
  Future<void> undo() async {
    await _guard(() async {
      final undone = await _service.undo();
      await refresh();
      _message = undone ? 'Undone.' : 'Nothing to undo.';
    });
  }

  /// Writes the whole wallet to [path] as JSON (`ganjoor export`).
  Future<void> exportJsonTo(String path) async {
    await _guard(() async {
      if (path.trim().isEmpty) {
        throw const GanjoorException('Type a file path first.');
      }
      await _service.exportToFile(path.trim());
      _message = 'Exported to ${path.trim()}.';
    });
  }

  /// Replaces the wallet from [path] (`ganjoor import`); undo reverts it.
  Future<void> importJsonFrom(String path) async {
    await _guard(() async {
      if (path.trim().isEmpty) {
        throw const GanjoorException('Type a file path first.');
      }
      await _service.importFromFile(path.trim());
      await refresh();
      _message = 'Imported ${path.trim()} — ganjoor undo reverts it.';
    });
  }

  /// Replaces the wallet from a JSON document already in hand (`ganjoor import`).
  ///
  /// The .NET service exposed `ImportJson(string)` beside the file-based verb; the migration
  /// screen pastes text rather than a path, so the controller surfaces the same entry point.
  Future<void> importJsonText(String json) async {
    await _guard(() async {
      await _service.importJson(json);
      await refresh();
      _message = 'Imported the wallet — ganjoor undo reverts it.';
    });
  }

  /// Imports a bank CSV into an account.
  ///
  /// [account] is an id or a name; [category] defaults to `imported`, exactly like the CLI.
  Future<GanjoorImportResult?> importCsvFrom(
    String path, {
    required String account,
    String? category,
    bool hasHeader = false,
    int? maxRows,
  }) async {
    GanjoorImportResult? result;
    await _guard(() async {
      if (account.trim().isEmpty) {
        throw const GanjoorException(
          'CSV imports need a target account: pick one in the form',
        );
      }
      result = await _service.importCsv(
        path.trim(),
        account,
        category ?? 'imported',
        hasHeader: hasHeader,
        maxRows: maxRows ?? _service.options.maxImportRows,
      );
      await refresh();
      _message =
          'Imported ${result!.imported} row(s), skipped ${result!.skipped}.';
    });
    return result;
  }

  /// Writes the filtered ledger to [path] as CSV. Returns the row count, or null on failure.
  Future<int?> exportCsvTo(String path) async {
    int? rows;
    await _guard(() async {
      rows = await _service.exportCsv(path.trim(), _filter());
      _message = 'Exported $rows row(s) to ${path.trim()}.';
    });
    return rows;
  }

  /// A sensible default export path inside the toolbox folder.
  Future<String> defaultExportPath(String fileName) async {
    final root = await _defaultFolder();
    return _join(root, fileName);
  }

  /// The toolbox folder, resolved without touching the platform when it is unavailable.
  Future<String> _defaultFolder() async {
    try {
      final root = await _root();
      return _join(root, 'ganjoor');
    } catch (_) {
      return Directory.systemTemp.path;
    }
  }

  // ── AI ──

  /// Asks for spending insights over [month] (null = the selected month).
  Future<void> aiInsights({DateOnly? month}) async {
    await _ai('insights', () async {
      final when = month ?? reportMonth;
      final prompt = _assistant.buildInsightsPrompt(
        (await _service.cashFlow(when)),
        await _service.budgetStatuses(when),
        await _service.transactions(GanjoorFilter(month: when)),
        baseCurrency,
      );
      return prompt;
    });
  }

  /// Asks a free-form question about the wallet.
  Future<void> aiAsk(String question) async {
    await _ai('ask', () async {
      _aiQuestion = question.trim();
      return _assistant.buildAskPrompt(
        question,
        await _service.netWorth(),
        await _service.cashFlow(),
        await _service.budgetStatuses(),
        await _service.transactions(),
        await _service.goals(),
        await _service.debts(),
      );
    });
  }

  /// Asks the model to categorize transaction [id]; with [apply] the suggestion is saved.
  Future<void> aiCategorize(int id, {bool apply = false}) async {
    await _ai('categorize', () async {
      _suggestedCategory = null;
      _suggestedFor = id;
      final tx = await _service.store.findTransaction(id);
      if (tx == null) throw GanjoorException('No transaction #$id.');

      final known = await _service.knownCategories();
      if (known.isEmpty) {
        throw const GanjoorException(
          'No categories known yet — spend something or set a budget first.',
        );
      }

      return _assistant.buildCategorizePrompt(tx, known, baseCurrency);
    });

    // The answer arrives through [aiAnswer]; apply it when the caller asked for that.
    final suggestion = _suggestedCategory;
    if (apply && suggestion != null && _suggestedFor == id) {
      await recategorize(id, suggestion);
    }
  }

  Future<void> _ai(String kind, Future<String> Function() build) async {
    final funnel = _funnel;
    _aiKind = kind;
    _aiAnswer = null;
    _error = null;

    if (funnel == null) {
      _error = 'AI is not available in this context.';
      _notify();
      return;
    }

    _aiBusy = true;
    _notify();
    try {
      final prompt = await build();
      final answer = (await funnel.completeText(prompt)).trim();
      if (kind == 'categorize') {
        final known = await _service.knownCategories();
        final suggestion = FinanceAssistant.parseCategory(answer, known);
        _suggestedCategory = suggestion;
        if (suggestion == null) {
          _error =
              'The AI suggested no known category — try renaming categories or '
              'add a budget row.';
        } else {
          _aiAnswer = 'Suggestion: $suggestion';
        }
      } else {
        _aiAnswer = answer;
      }
    } on GanjoorException catch (failure) {
      _error = failure.message;
    } catch (failure) {
      _error = '$failure';
    } finally {
      _aiBusy = false;
      _notify();
    }
  }

  // ── Internals ──

  GanjoorFilter _filter() => GanjoorFilter(
    accountId: _accountFilter,
    category: _categoryFilter,
    kind: _kindFilter,
    month: _monthFilter == null
        ? null
        : DateOnly(_monthFilter!.year, _monthFilter!.month, 1),
    query: _query.trim().isEmpty ? null : _query.trim(),
  );

  Future<void> _guard(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
    } on GanjoorException catch (failure) {
      _error = failure.message;
    } on FormatException catch (failure) {
      // Bad JSON, a broken CSV date, a non-number amount — all reported the same way.
      _error = failure.message;
    } on ArgumentError catch (failure) {
      _error = failure.message?.toString() ?? 'Invalid value.';
    } catch (failure) {
      _error = '$failure';
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// The toolbox root, overridable from the environment like every other path.
  Future<String> _root() async {
    final override = _environment('JAMEJAM_HOME').trim();
    if (override.isNotEmpty) return override;
    final home = _environment('HOME').trim();
    if (home.isNotEmpty) return _join(home, '.jamejam');
    return Directory.systemTemp.path;
  }

  static String _join(String a, String b) => a.endsWith('/') ? '$a$b' : '$a/$b';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
