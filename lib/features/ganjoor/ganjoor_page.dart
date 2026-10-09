/// ganjoor — see doc/ganjoor.md and AGENTS.md
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_only.dart';
import '../../core/fa_format.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/adaptive_layout.dart';
import 'ganjoor_controller.dart';
import 'ganjoor_defaults.dart';
import 'models.dart';
import 'money.dart';

const Key ganjoorQuickAccountKey = Key('ganjoor.quick.account');

const Key ganjoorQuickAmountKey = Key('ganjoor.quick.amount');

const Key ganjoorQuickCategoryKey = Key('ganjoor.quick.category');

const Key ganjoorQuickNotesKey = Key('ganjoor.quick.notes');

const Key ganjoorQuickTagsKey = Key('ganjoor.quick.tags');

const Key ganjoorQuickDateKey = Key('ganjoor.quick.date');

const Key ganjoorQuickTargetKey = Key('ganjoor.quick.target');

const Key ganjoorQuickKindKey = Key('ganjoor.quick.kind');

const Key ganjoorQuickAddKey = Key('ganjoor.quick.add');

const Key ganjoorAddAccountKey = Key('ganjoor.account.add');

const Key ganjoorAccountNameKey = Key('ganjoor.account.name');

const Key ganjoorAccountCurrencyKey = Key('ganjoor.account.currency');

const Key ganjoorAccountStartKey = Key('ganjoor.account.start');

const Key ganjoorAccountSaveKey = Key('ganjoor.account.save');

const Key ganjoorUndoKey = Key('ganjoor.undo');

const Key ganjoorRefreshKey = Key('ganjoor.refresh');

const Key ganjoorTransferKey = Key('ganjoor.transfer');

const Key ganjoorTransferPathKey = Key('ganjoor.transfer.path');

const Key ganjoorExportJsonKey = Key('ganjoor.transfer.export');

const Key ganjoorImportJsonKey = Key('ganjoor.transfer.import');

const Key ganjoorExportCsvKey = Key('ganjoor.transfer.exportCsv');

const Key ganjoorImportCsvKey = Key('ganjoor.transfer.importCsv');

const Key ganjoorCsvAccountKey = Key('ganjoor.transfer.csvAccount');

const Key ganjoorSearchKey = Key('ganjoor.filter.query');

const Key ganjoorAccountFilterKey = Key('ganjoor.filter.account');

const Key ganjoorKindFilterKey = Key('ganjoor.filter.kind');

const Key ganjoorCategoryFilterKey = Key('ganjoor.filter.category');

const Key ganjoorPrevMonthKey = Key('ganjoor.month.prev');

const Key ganjoorNextMonthKey = Key('ganjoor.month.next');

const Key ganjoorClearFiltersKey = Key('ganjoor.filter.clear');

const Key ganjoorBudgetCategoryKey = Key('ganjoor.budget.category');

const Key ganjoorBudgetLimitKey = Key('ganjoor.budget.limit');

const Key ganjoorBudgetSaveKey = Key('ganjoor.budget.save');

const Key ganjoorAskFieldKey = Key('ganjoor.ai.question');

const Key ganjoorAskButtonKey = Key('ganjoor.ai.ask');

const Key ganjoorInsightsKey = Key('ganjoor.ai.insights');

const Key ganjoorAiClearKey = Key('ganjoor.ai.clear');

Key ganjoorAccountTileKey(int id) => Key('ganjoor.account.$id');

Key ganjoorAccountMenuKey(int id) => Key('ganjoor.account.menu.$id');

Key ganjoorTransactionTileKey(int id) => Key('ganjoor.tx.$id');

Key ganjoorTransactionDeleteKey(int id) => Key('ganjoor.tx.delete.$id');

Key ganjoorTransactionAiKey(int id) => Key('ganjoor.tx.ai.$id');

Key ganjoorBudgetTileKey(String category) => Key('ganjoor.budget.$category');

Key ganjoorBudgetRemoveKey(String category) =>
    Key('ganjoor.budget.remove.$category');

Key ganjoorBillTileKey(int id) => Key('ganjoor.bill.$id');

Key ganjoorGoalTileKey(int id) => Key('ganjoor.goal.$id');

Key ganjoorDebtTileKey(int id) => Key('ganjoor.debt.$id');

String ganjoorMoneyRun(BuildContext context, String text) {
  final localised = FaFormat.at(
    Localizations.localeOf(context).toLanguageTag(),
    text,
  );
  return Directionality.of(context) == TextDirection.rtl
      ? '\u2066$localised\u2069'
      : localised;
}

String ganjoorDigits(BuildContext context, String text) =>
    FaFormat.at(Localizations.localeOf(context).toLanguageTag(), text);

class GanjoorPage extends StatefulWidget {
  /// Creates the screen; the controller comes from the provider graph.
  const GanjoorPage({super.key});

  @override
  State<GanjoorPage> createState() => _GanjoorPageState();
}

class _GanjoorPageState extends State<GanjoorPage> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _date = TextEditingController();
  final TextEditingController _accountName = TextEditingController();
  final TextEditingController _currency = TextEditingController();
  final TextEditingController _start = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _filterCategory = TextEditingController();
  final TextEditingController _budgetCategory = TextEditingController();
  final TextEditingController _budgetLimit = TextEditingController();
  final TextEditingController _ask = TextEditingController();
  final TextEditingController _path = TextEditingController();
  final TextEditingController _csvAccount = TextEditingController();

  GanjoorController? _wallet;
  GanjoorTxKind _kind = GanjoorTxKind.expense;
  int? _fromId;
  int? _toId;
  String _folder = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<GanjoorController>();
      _wallet = controller;
      controller.addListener(_onControllerChanged);
      await controller.initialize();
      // The form's pickers start on the wallet's own accounts.
      if (mounted) setState(_onControllerChanged);
      await _loadDefaultPaths();
    });
  }

  /// Keeps the form's account pickers valid as accounts come and go.
  void _onControllerChanged() {
    if (!mounted) return;
    final controller = _wallet;
    if (controller == null) return;
    final accounts = controller.accounts;
    if (accounts.isEmpty) {
      _fromId = null;
      _toId = null;
      return;
    }
    if (_fromId == null || !accounts.any((a) => a.id == _fromId)) {
      _fromId = accounts.first.id;
    }
    if (_toId == null || !accounts.any((a) => a.id == _toId)) {
      _toId = accounts.length > 1 ? accounts[1].id : null;
    }
  }

  Future<void> _loadDefaultPaths() async {
    final controller = _wallet;
    if (controller == null) return;
    final export = await controller.defaultExportPath('wallet.json');
    final csv = await controller.defaultExportPath('ledger.csv');
    if (!mounted) return;
    setState(() {
      _folder = export;
      if (_path.text.trim().isEmpty) _path.text = export;
      if (_csvDefault.isEmpty) _csvDefault = csv;
    });
  }

  String _csvDefault = '';

  @override
  void dispose() {
    _wallet?.removeListener(_onControllerChanged);
    for (final field in [
      _amount,
      _category,
      _notes,
      _tags,
      _date,
      _accountName,
      _currency,
      _start,
      _search,
      _filterCategory,
      _budgetCategory,
      _budgetLimit,
      _ask,
      _path,
      _csvAccount,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<GanjoorController>();
    final l10n = AppLocalizations.of(context);
    final panes = <Widget>[
      _AccountsPane(
        wallet: wallet,
        l10n: l10n,
        onAdd: _addAccountDialog,
        onFlash: _flash,
      ),
      _LedgerPane(
        wallet: wallet,
        l10n: l10n,
        amount: _amount,
        category: _category,
        notes: _notes,
        tags: _tags,
        date: _date,
        kind: _kind,
        fromId: _fromId,
        toId: _toId,
        onKind: (value) => setState(() => _kind = value),
        onFrom: (value) => setState(() => _fromId = value),
        onTo: (value) => setState(() => _toId = value),
        onAdd: _submit,
        onFlash: _flash,
      ),
      _ToolsPane(
        wallet: wallet,
        l10n: l10n,
        ask: _ask,
        budgetCategory: _budgetCategory,
        budgetLimit: _budgetLimit,
        path: _path,
        csvAccount: _csvAccount,
        csvDefault: _csvDefault,
        onFlash: _flash,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        return AdaptivePageBody(
          chrome: [
            _Header(
              wallet: wallet,
              l10n: l10n,
              onFlash: _flash,
              onTransfer: _openTransferDialog,
            ),
            _Toolbar(
              wallet: wallet,
              l10n: l10n,
              search: _search,
              category: _filterCategory,
              onFlash: _flash,
            ),
            if (wallet.error != null)
              _ErrorCard(message: wallet.error!, l10n: l10n),
          ],
          body: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: panes[0]),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 4, child: panes[1]),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 4, child: panes[2]),
                  ],
                )
              : DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: l10n.ganjoorTabAccounts),
                          Tab(text: l10n.ganjoorTabLedger),
                          Tab(text: l10n.ganjoorTabTools),
                        ],
                      ),
                      Expanded(child: TabBarView(children: panes)),
                    ],
                  ),
                ),
        );
      },
    );
  }

  /// Records whatever the quick-add form holds.
  Future<void> _submit() async {
    final wallet = context.read<GanjoorController>();
    // A picker the listener has not filled in yet still resolves to the first account.
    final from = _fromId ?? wallet.accounts.firstOrNull?.id;
    if (from == null) return;

    await _flash(() async {
      switch (_kind) {
        case GanjoorTxKind.expense:
          await wallet.spend(
            '$from',
            _amount.text,
            _category.text,
            tags: _tags.text,
            notes: _notes.text,
            date: _blank(_date.text),
          );
        case GanjoorTxKind.income:
          await wallet.earn(
            '$from',
            _amount.text,
            _category.text,
            tags: _tags.text,
            notes: _notes.text,
            date: _blank(_date.text),
          );
        case GanjoorTxKind.transfer:
          final to = _toId;
          if (to == null) return;
          await wallet.transfer(
            '$from',
            '$to',
            _amount.text,
            notes: _notes.text,
            date: _blank(_date.text),
          );
      }
    });

    if (wallet.error != null && mounted) return;
    _amount.clear();
    _notes.clear();
    _tags.clear();
    _date.clear();
  }

  static String? _blank(String text) =>
      text.trim().isEmpty ? null : text.trim();

  Future<void> _addAccountDialog() async {
    final wallet = context.read<GanjoorController>();
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ganjoorAccountAdd),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: ganjoorAccountNameKey,
                controller: _accountName,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.ganjoorAccountName),
              ),
              TextField(
                key: ganjoorAccountCurrencyKey,
                controller: _currency,
                decoration: InputDecoration(
                  labelText: l10n.ganjoorAccountCurrency,
                  hintText: wallet.baseCurrency,
                ),
              ),
              TextField(
                key: ganjoorAccountStartKey,
                controller: _start,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.ganjoorAccountStart,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.ganjoorCancel),
          ),
          FilledButton(
            key: ganjoorAccountSaveKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.ganjoorSave),
          ),
        ],
      ),
    );
    if (saved != true) return;

    await wallet.addAccount(
      _accountName.text,
      currency: _blank(_currency.text),
      initialBalance: _blank(_start.text),
    );
    if (wallet.error == null) {
      _accountName.clear();
      _currency.clear();
      _start.clear();
      if (mounted) _flashMessage(wallet.message, l10n);
    }
  }

  void _flashMessage(String? message, AppLocalizations l10n) {
    if (message == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The backup / CSV dialog: the CLI's `export`, `import`, `import-csv` verbs, with the
  /// paths typed in (the app has no `argv`, so the fields are prefilled and editable).
  ///
  /// The dialog closes on the chosen verb and the outcome lands in the usual snack bar, so a
  /// long import never leaves a modal sitting over a finished job.
  Future<void> _openTransferDialog() async {
    final wallet = context.read<GanjoorController>();
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ganjoorTransfer),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: ganjoorTransferPathKey,
                  controller: _path,
                  decoration: InputDecoration(
                    labelText: l10n.ganjoorTransferPath,
                    hintText: _folder,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: ganjoorCsvAccountKey,
                  controller: _csvAccount,
                  decoration: InputDecoration(
                    labelText: l10n.ganjoorCsvAccount,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: ganjoorExportJsonKey,
            onPressed: () => Navigator.of(context).pop('exportJson'),
            child: Text(l10n.ganjoorExportJson),
          ),
          TextButton(
            key: ganjoorImportJsonKey,
            onPressed: () => Navigator.of(context).pop('importJson'),
            child: Text(l10n.ganjoorImportJson),
          ),
          TextButton(
            key: ganjoorExportCsvKey,
            onPressed: () => Navigator.of(context).pop('exportCsv'),
            child: Text(l10n.ganjoorExportCsv),
          ),
          TextButton(
            key: ganjoorImportCsvKey,
            onPressed: () => Navigator.of(context).pop('importCsv'),
            child: Text(l10n.ganjoorImportCsv),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ganjoorCancel),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;

    final path = _path.text.trim();
    await _flash(() async {
      switch (choice) {
        case 'exportJson':
          await wallet.exportJsonTo(path);
        case 'importJson':
          await wallet.importJsonFrom(path);
        case 'exportCsv':
          await wallet.exportCsvTo(path.isEmpty ? _csvDefault : path);
        case 'importCsv':
          await wallet.importCsvFrom(
            path,
            account: _csvAccount.text,
            hasHeader: true,
          );
      }
    });
  }

  /// Runs an action and surfaces the controller's message when it succeeded.
  Future<void> _flash(Future<void> Function() action) async {
    final wallet = context.read<GanjoorController>();
    final messenger = ScaffoldMessenger.of(context);
    await action();
    if (!mounted) return;
    final message = wallet.error ?? wallet.message;
    if (message == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Header ──

class _Header extends StatelessWidget {
  const _Header({
    required this.wallet,
    required this.l10n,
    required this.onFlash,
    required this.onTransfer,
  });

  final GanjoorController wallet;
  final AppLocalizations l10n;
  final Future<void> Function(Future<void> Function()) onFlash;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = wallet.totalBalance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The reference CLI printed one line of header; a window has to fit the title and
          // every action beside it, which a phone at a large text scale cannot do. Wrapping
          // keeps all four reachable instead of clipping the last button.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160, maxWidth: 520),
                child: Text(
                  l10n.ganjoorTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              TextButton.icon(
                key: ganjoorRefreshKey,
                onPressed: () => onFlash(wallet.refresh),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.ganjoorRefresh),
              ),
              TextButton.icon(
                key: ganjoorTransferKey,
                onPressed: onTransfer,
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.ganjoorTransfer),
              ),
              FilledButton.tonalIcon(
                key: ganjoorUndoKey,
                onPressed: wallet.undoAvailable
                    ? () => onFlash(wallet.undo)
                    : null,
                icon: const Icon(Icons.undo),
                label: Text(l10n.ganjoorUndo),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.ganjoorTotal}: '
            '${total == null ? '—' : ganjoorMoneyRun(context, total.formatWith(wallet.baseCurrency))}',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

// ── Toolbar ──

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.wallet,
    required this.l10n,
    required this.search,
    required this.category,
    required this.onFlash,
  });

  final GanjoorController wallet;
  final AppLocalizations l10n;
  final TextEditingController search;
  final TextEditingController category;
  final Future<void> Function(Future<void> Function()) onFlash;

  @override
  Widget build(BuildContext context) {
    final month = wallet.reportMonth;
    final accounts = wallet.accounts;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            key: ganjoorPrevMonthKey,
            tooltip: l10n.ganjoorPrevMonth,
            onPressed: () => wallet.setMonthFilter(
              month.month == 1
                  ? DateOnly(month.year - 1, 12, 1)
                  : DateOnly(month.year, month.month - 1, 1),
            ),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            ganjoorDigits(
              context,
              '${month.year}-${month.month.toString().padLeft(2, '0')}',
            ),
          ),
          IconButton(
            key: ganjoorNextMonthKey,
            tooltip: l10n.ganjoorNextMonth,
            onPressed: () => wallet.setMonthFilter(
              month.month == 12
                  ? DateOnly(month.year + 1, 1, 1)
                  : DateOnly(month.year, month.month + 1, 1),
            ),
            icon: const Icon(Icons.chevron_right),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<int?>(
              key: ganjoorAccountFilterKey,
              initialValue: accounts.any((a) => a.id == wallet.accountFilter)
                  ? wallet.accountFilter
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.ganjoorFilterAccount,
                isDense: true,
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n.ganjoorFilterAll),
                ),
                for (final account in accounts)
                  DropdownMenuItem<int?>(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (value) =>
                  onFlash(() => wallet.setAccountFilter(value)),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<GanjoorTxKind?>(
              key: ganjoorKindFilterKey,
              initialValue: wallet.kindFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.ganjoorFilterKind,
                isDense: true,
              ),
              items: [
                DropdownMenuItem<GanjoorTxKind?>(
                  value: null,
                  child: Text(l10n.ganjoorFilterAll),
                ),
                DropdownMenuItem<GanjoorTxKind?>(
                  value: GanjoorTxKind.expense,
                  child: Text(l10n.ganjoorKindSpend),
                ),
                DropdownMenuItem<GanjoorTxKind?>(
                  value: GanjoorTxKind.income,
                  child: Text(l10n.ganjoorKindEarn),
                ),
                DropdownMenuItem<GanjoorTxKind?>(
                  value: GanjoorTxKind.transfer,
                  child: Text(l10n.ganjoorKindTransfer),
                ),
              ],
              onChanged: (value) => onFlash(() => wallet.setKindFilter(value)),
            ),
          ),
          SizedBox(
            width: 170,
            child: TextField(
              key: ganjoorCategoryFilterKey,
              controller: category,
              decoration: InputDecoration(
                labelText: l10n.ganjoorFilterCategory,
                isDense: true,
              ),
              onSubmitted: (value) => onFlash(
                () => wallet.setCategoryFilter(
                  value.trim().isEmpty ? null : value,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              key: ganjoorSearchKey,
              controller: search,
              decoration: InputDecoration(
                labelText: l10n.ganjoorFilterQuery,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => wallet.setQuery(value),
            ),
          ),
          TextButton(
            key: ganjoorClearFiltersKey,
            onPressed: wallet.hasFilters
                ? () => onFlash(wallet.clearFilters)
                : null,
            child: Text(l10n.ganjoorFilterClear),
          ),
        ],
      ),
    );
  }
}

// ── Error card ──

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.l10n});

  final String message;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        color: colors.errorContainer,
        child: ListTile(
          leading: Icon(Icons.error_outline, color: colors.onErrorContainer),
          title: Text(
            message,
            style: TextStyle(color: colors.onErrorContainer),
          ),
        ),
      ),
    );
  }
}

// ── Accounts pane ──

class _AccountsPane extends StatelessWidget {
  const _AccountsPane({
    required this.wallet,
    required this.l10n,
    required this.onAdd,
    required this.onFlash,
  });

  final GanjoorController wallet;
  final AppLocalizations l10n;
  final Future<void> Function() onAdd;
  final Future<void> Function(Future<void> Function()) onFlash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = wallet.accounts;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.ganjoorAccounts,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: ganjoorAddAccountKey,
              tooltip: l10n.ganjoorAccountAdd,
              onPressed: () => onAdd(),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        SwitchListTile(
          dense: true,
          value: wallet.includeArchived,
          onChanged: wallet.setIncludeArchived,
          title: Text(l10n.ganjoorShowArchived),
        ),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l10n.ganjoorNoAccounts),
          ),
        for (final account in accounts)
          ListTile(
            key: ganjoorAccountTileKey(account.id),
            title: Text(account.name),
            subtitle: Text(
              account.isArchived
                  ? l10n.ganjoorAccountArchived
                  : account.currency,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ganjoorMoneyRun(
                    context,
                    wallet.balanceOf(account).formatWith(account.currency),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                PopupMenuButton<String>(
                  key: ganjoorAccountMenuKey(account.id),
                  onSelected: (value) async {
                    switch (value) {
                      case 'rename':
                        await _rename(context, account);
                      case 'archive':
                        await onFlash(
                          () => wallet.archiveAccount(account.id, true),
                        );
                      case 'unarchive':
                        await onFlash(
                          () => wallet.archiveAccount(account.id, false),
                        );
                      case 'remove':
                        await _remove(context, account);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(l10n.ganjoorAccountRename),
                    ),
                    PopupMenuItem(
                      value: account.isArchived ? 'unarchive' : 'archive',
                      child: Text(
                        account.isArchived
                            ? l10n.ganjoorAccountUnarchive
                            : l10n.ganjoorAccountArchive,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(l10n.ganjoorAccountRemove),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, GanjoorAccount account) async {
    final field = TextEditingController(text: account.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ganjoorAccountRename),
        content: TextField(
          controller: field,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.ganjoorAccountName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ganjoorCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(field.text),
            child: Text(l10n.ganjoorSave),
          ),
        ],
      ),
    );
    field.dispose();
    if (name == null || name.trim().isEmpty) return;
    await onFlash(() => wallet.renameAccount(account.id, name));
  }

  Future<void> _remove(BuildContext context, GanjoorAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ganjoorAccountRemove),
        content: Text('${l10n.ganjoorAccountRemoveConfirm}\n${account.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.ganjoorCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.ganjoorConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // The .NET verb needed `--force` to sweep a non-empty account; the dialog asks for the
    // same sweep once the service refuses.
    await onFlash(() => wallet.removeAccount(account.id));
    if (wallet.error == null || !context.mounted) return;
    final forced = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ganjoorAccountRemoveForce),
        content: Text(wallet.error ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.ganjoorCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.ganjoorConfirm),
          ),
        ],
      ),
    );
    if (forced != true) return;
    await onFlash(() => wallet.removeAccount(account.id, force: true));
  }
}

// ── Ledger pane ──

class _LedgerPane extends StatelessWidget {
  const _LedgerPane({
    required this.wallet,
    required this.l10n,
    required this.amount,
    required this.category,
    required this.notes,
    required this.tags,
    required this.date,
    required this.kind,
    required this.fromId,
    required this.toId,
    required this.onKind,
    required this.onFrom,
    required this.onTo,
    required this.onAdd,
    required this.onFlash,
  });

  final GanjoorController wallet;
  final AppLocalizations l10n;
  final TextEditingController amount;
  final TextEditingController category;
  final TextEditingController notes;
  final TextEditingController tags;
  final TextEditingController date;
  final GanjoorTxKind kind;
  final int? fromId;
  final int? toId;
  final ValueChanged<GanjoorTxKind> onKind;
  final ValueChanged<int?> onFrom;
  final ValueChanged<int?> onTo;
  final Future<void> Function() onAdd;
  final Future<void> Function(Future<void> Function()) onFlash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = wallet.transactions;
    final accounts = wallet.accounts;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.ganjoorQuickAdd, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<GanjoorTxKind>(
          key: ganjoorQuickKindKey,
          segments: [
            ButtonSegment(
              value: GanjoorTxKind.expense,
              label: Text(l10n.ganjoorKindSpend),
            ),
            ButtonSegment(
              value: GanjoorTxKind.income,
              label: Text(l10n.ganjoorKindEarn),
            ),
            ButtonSegment(
              value: GanjoorTxKind.transfer,
              label: Text(l10n.ganjoorKindTransfer),
            ),
          ],
          selected: {kind},
          onSelectionChanged: (values) => onKind(values.first),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int>(
            key: ganjoorQuickAccountKey,
            initialValue: accounts.any((a) => a.id == fromId) ? fromId : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: kind == GanjoorTxKind.transfer
                  ? l10n.ganjoorFrom
                  : l10n.ganjoorAccountName,
              isDense: true,
            ),
            items: [
              for (final account in accounts)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
            ],
            onChanged: onFrom,
          ),
        ),
        if (kind == GanjoorTxKind.transfer) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int>(
              key: ganjoorQuickTargetKey,
              initialValue: accounts.any((a) => a.id == toId) ? toId : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.ganjoorTo,
                isDense: true,
              ),
              items: [
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: onTo,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ganjoorQuickAmountKey,
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.ganjoorAmount,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: kind == GanjoorTxKind.transfer
                  ? const SizedBox.shrink()
                  : TextField(
                      key: ganjoorQuickCategoryKey,
                      controller: category,
                      decoration: InputDecoration(
                        labelText: l10n.ganjoorCategory,
                        isDense: true,
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ganjoorQuickNotesKey,
                controller: notes,
                decoration: InputDecoration(
                  labelText: l10n.ganjoorNotes,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: ganjoorQuickTagsKey,
                controller: tags,
                decoration: InputDecoration(
                  labelText: l10n.ganjoorTags,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 170,
              child: TextField(
                key: ganjoorQuickDateKey,
                controller: date,
                decoration: InputDecoration(
                  labelText: l10n.ganjoorDate,
                  hintText: wallet.service.today.toIso(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: ganjoorQuickAddKey,
              onPressed: accounts.isEmpty ? null : () => onAdd(),
              icon: const Icon(Icons.add),
              label: Text(l10n.ganjoorAdd),
            ),
          ],
        ),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.ganjoorLedger,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(ganjoorDigits(context, l10n.ganjoorCount(rows.length))),
          ],
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l10n.ganjoorLedgerEmpty),
          ),
        for (final tx in rows)
          _TransactionTile(
            wallet: wallet,
            l10n: l10n,
            tx: tx,
            onFlash: onFlash,
          ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.wallet,
    required this.l10n,
    required this.tx,
    required this.onFlash,
  });

  final GanjoorController wallet;
  final AppLocalizations l10n;
  final GanjoorTransaction tx;
  final Future<void> Function(Future<void> Function()) onFlash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sign = switch (tx.kind) {
      GanjoorTxKind.income => '+',
      GanjoorTxKind.expense => '−',
      GanjoorTxKind.transfer => '⇄',
    };
    final detail = switch (tx.kind) {
      GanjoorTxKind.transfer =>
        '${wallet.transferTargetName(tx) ?? tx.transferToAccountId}',
      _ => tx.category,
    };

    return ListTile(
      key: ganjoorTransactionTileKey(tx.id),
      dense: true,
      leading: Text(sign, style: theme.textTheme.titleMedium),
      title: Text(
        '${ganjoorMoneyRun(context, '$sign${tx.amount.formatAmount()}')} · $detail',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          tx.date.format(locale: l10n.localeName),
          wallet.accountNameOf(tx),
          if (tx.tags.isNotEmpty) tx.tags.join(', '),
          if (tx.notes.isNotEmpty) tx.notes,
          if (tx.fromBillId != null) l10n.ganjoorFromBill(tx.fromBillId!),
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ganjoorTransactionAiKey(tx.id),
            tooltip: l10n.ganjoorAiCategorize,
            onPressed: wallet.aiAvailable
                ? () => onFlash(() => wallet.aiCategorize(tx.id))
                : null,
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            key: ganjoorTransactionDeleteKey(tx.id),
            tooltip: l10n.ganjoorRemoveTransaction,
            onPressed: () => onFlash(() => wallet.deleteTransaction(tx.id)),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

// ── Tools pane: budgets, bills, goals, debts, reports, AI ──

class _ToolsPane extends StatefulWidget {
  const _ToolsPane({
    required this.wallet,
    required this.l10n,
    required this.ask,
    required this.budgetCategory,
    required this.budgetLimit,
    required this.path,
    required this.csvAccount,
    required this.csvDefault,
    required this.onFlash,
  });

  final GanjoorController wallet;
  final AppLocalizations l10n;
  final TextEditingController ask;
  final TextEditingController budgetCategory;
  final TextEditingController budgetLimit;
  final TextEditingController path;
  final TextEditingController csvAccount;
  final String csvDefault;
  final Future<void> Function(Future<void> Function()) onFlash;

  @override
  State<_ToolsPane> createState() => _ToolsPaneState();
}

class _ToolsPaneState extends State<_ToolsPane> {
  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final flow = wallet.cashFlow;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.ganjoorReports, style: theme.textTheme.titleMedium),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ganjoorDigits(
                    context,
                    '${l10n.ganjoorIncome}: '
                    '${flow?.income.formatWith(wallet.baseCurrency) ?? '—'}',
                  ),
                ),
                Text(
                  ganjoorDigits(
                    context,
                    '${l10n.ganjoorExpenses}: '
                    '${flow?.expenses.formatWith(wallet.baseCurrency) ?? '—'}',
                  ),
                ),
                Text(
                  ganjoorDigits(
                    context,
                    '${l10n.ganjoorNet}: '
                    '${flow?.net.formatWith(wallet.baseCurrency) ?? '—'}',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (wallet.netWorth != null) ...[
                  const Divider(),
                  Text(
                    ganjoorDigits(
                      context,
                      l10n.ganjoorNetWorth(
                        wallet.netWorth!.total.formatWith(wallet.baseCurrency),
                      ),
                    ),
                  ),
                  Text(
                    ganjoorDigits(
                      context,
                      l10n.ganjoorNetWorthBreakdown(
                        wallet.netWorth!.accounts.formatAmount(),
                        wallet.netWorth!.receivable.formatAmount(),
                        wallet.netWorth!.payable.formatAmount(),
                      ),
                    ),
                  ),
                ],
                if (flow != null && flow.byCategory.isNotEmpty) ...[
                  const Divider(),
                  Text(l10n.ganjoorTopCategories),
                  for (final row in flow.byCategory.take(
                    GanjoorDefaults.topCategories,
                  ))
                    _CategoryBar(
                      row: row,
                      largest: flow.byCategory.first.amount,
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(l10n.ganjoorBudgets, style: theme.textTheme.titleMedium),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ganjoorBudgetCategoryKey,
                controller: widget.budgetCategory,
                decoration: InputDecoration(
                  labelText: l10n.ganjoorCategory,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: ganjoorBudgetLimitKey,
                controller: widget.budgetLimit,
                decoration: InputDecoration(
                  labelText: l10n.ganjoorBudgetLimit,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              key: ganjoorBudgetSaveKey,
              tooltip: l10n.ganjoorBudgetSet,
              onPressed: () => widget.onFlash(
                () => wallet.setBudget(
                  widget.budgetCategory.text,
                  widget.budgetLimit.text,
                ),
              ),
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        if (wallet.budgets.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.ganjoorBudgetEmpty),
          ),
        for (final budget in wallet.budgets)
          ListTile(
            key: ganjoorBudgetTileKey(budget.category),
            dense: true,
            leading: _BudgetRing(status: budget),
            title: Text(budget.category),
            subtitle: Text(
              ganjoorDigits(
                context,
                '${budget.spent.formatAmount()} / ${budget.limit.formatAmount()} · '
                '${budget.percentUsed}%'
                '${budget.over ? ' · ${l10n.ganjoorBudgetOver}' : ''}'
                '${!budget.over && budget.percentUsed >= GanjoorDefaults.budgetWarnPercent ? ' · ${l10n.ganjoorBudgetClose}' : ''}',
              ),
            ),
            trailing: IconButton(
              key: ganjoorBudgetRemoveKey(budget.category),
              tooltip: l10n.ganjoorBudgetRemove,
              onPressed: () =>
                  widget.onFlash(() => wallet.removeBudget(budget.category)),
              icon: const Icon(Icons.close),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.ganjoorBills,
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => widget.onFlash(wallet.applyDueBills),
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.ganjoorBillApply),
            ),
          ],
        ),
        if (wallet.bills.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.ganjoorBillEmpty),
          ),
        for (final bill in wallet.bills)
          ListTile(
            key: ganjoorBillTileKey(bill.id),
            dense: true,
            title: Text(ganjoorDigits(context, '#${bill.id} ${bill.name}')),
            subtitle: Text(
              ganjoorDigits(
                context,
                '${bill.amount.formatWith(wallet.baseCurrency)} · '
                '${l10n.ganjoorBillNext(bill.nextDue.format(locale: l10n.localeName))}'
                '${bill.nextDue <= wallet.service.today ? ' · ${l10n.ganjoorBillDue}' : ''}',
              ),
            ),
            trailing: IconButton(
              tooltip: l10n.ganjoorBillRemove,
              onPressed: () => widget.onFlash(() => wallet.removeBill(bill.id)),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        const SizedBox(height: 12),
        Text(l10n.ganjoorGoals, style: theme.textTheme.titleMedium),
        if (wallet.goals.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.ganjoorGoalEmpty),
          ),
        for (final goal in wallet.goals)
          ListTile(
            key: ganjoorGoalTileKey(goal.id),
            dense: true,
            leading: _BudgetRing(
              percent: goal.percent,
              warn: goal.percent >= GanjoorDefaults.goalNearlyDonePercent,
            ),
            title: Text(goal.name),
            subtitle: Text(
              ganjoorDigits(
                context,
                '${goal.contributed.formatAmount()} / ${goal.target.formatAmount()} · '
                '${goal.percent}%'
                '${goal.percent >= GanjoorDefaults.goalNearlyDonePercent ? ' · ${l10n.ganjoorGoalNearlyDone}' : ''}'
                '${goal.deadline == null ? '' : ' · ${l10n.ganjoorGoalDeadline(goal.deadline!.format(locale: l10n.localeName))}'}',
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l10n.ganjoorGoalContribute,
                  onPressed: () => _amountDialog(
                    title: l10n.ganjoorGoalContribute,
                    onValue: (value) =>
                        widget.onFlash(() => wallet.contribute(goal.id, value)),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  tooltip: l10n.ganjoorGoalWithdraw,
                  onPressed: () => _amountDialog(
                    title: l10n.ganjoorGoalWithdraw,
                    onValue: (value) =>
                        widget.onFlash(() => wallet.withdraw(goal.id, value)),
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(l10n.ganjoorDebts, style: theme.textTheme.titleMedium),
        if (wallet.debts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.ganjoorDebtEmpty),
          ),
        for (final debt in wallet.debts)
          ListTile(
            key: ganjoorDebtTileKey(debt.id),
            dense: true,
            title: Text(
              ganjoorDigits(
                context,
                '#${debt.id} ${debt.owedByMe ? l10n.ganjoorDebtOwedByMe : l10n.ganjoorDebtOwedToMe} '
                '${debt.person}',
              ),
            ),
            subtitle: Text(
              ganjoorDigits(
                context,
                '${l10n.ganjoorDebtOutstanding}: '
                '${debt.outstanding.formatWith(wallet.baseCurrency)}'
                '${debt.settled.isZero ? '' : ' · ${l10n.ganjoorDebtSettled(debt.settled.formatAmount())}'}'
                '${debt.settledInFull ? ' · ${l10n.ganjoorDebtFullySettled}' : ''}',
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l10n.ganjoorDebtSettle,
                  onPressed: () => _amountDialog(
                    title: l10n.ganjoorDebtSettle,
                    onValue: (value) =>
                        widget.onFlash(() => wallet.settleDebt(debt.id, value)),
                  ),
                  icon: const Icon(Icons.handshake_outlined),
                ),
                IconButton(
                  tooltip: l10n.ganjoorDebtRemove,
                  onPressed: () =>
                      widget.onFlash(() => wallet.removeDebt(debt.id)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        const Divider(height: 32),
        Text(l10n.ganjoorAi, style: theme.textTheme.titleMedium),
        Row(
          children: [
            FilledButton.tonalIcon(
              key: ganjoorInsightsKey,
              onPressed: wallet.aiAvailable && !wallet.aiBusy
                  ? () => widget.onFlash(wallet.aiInsights)
                  : null,
              icon: const Icon(Icons.insights),
              label: Text(l10n.ganjoorAiInsights),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: ganjoorAskFieldKey,
          controller: widget.ask,
          decoration: InputDecoration(
            labelText: l10n.ganjoorAiQuestion,
            isDense: true,
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              key: ganjoorAskButtonKey,
              onPressed: wallet.aiAvailable && !wallet.aiBusy
                  ? () => widget.onFlash(() => wallet.aiAsk(widget.ask.text))
                  : null,
              icon: const Icon(Icons.question_answer_outlined),
              label: Text(l10n.ganjoorAiAsk),
            ),
            TextButton.icon(
              key: ganjoorAiClearKey,
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.clear),
              label: Text(l10n.ganjoorAiClear),
            ),
          ],
        ),
        if (!wallet.aiAvailable)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.ganjoorAiUnavailable),
          ),
        if (wallet.aiAnswer != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(l10n.ganjoorAiAnswer),
              subtitle: Text(wallet.aiAnswer!),
            ),
          ),
        if (wallet.aiBusy)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Future<void> _amountDialog({
    required String title,
    required Future<void> Function(String value) onValue,
  }) async {
    final field = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: widget.l10n.ganjoorAmount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.l10n.ganjoorCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(field.text),
            child: Text(widget.l10n.ganjoorSave),
          ),
        ],
      ),
    );
    field.dispose();
    if (value == null || value.trim().isEmpty) return;
    await onValue(value);
  }
}

class _BudgetRing extends StatelessWidget {
  const _BudgetRing({this.status, this.percent, this.warn = false});

  final GanjoorBudgetStatus? status;
  final int? percent;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final used = status?.percentUsed ?? percent ?? 0;
    final over = status?.over ?? false;
    final color = over
        ? colors.error
        : (status?.percentUsed ?? percent ?? 0) >=
                  GanjoorDefaults.budgetWarnPercent ||
              warn
        ? colors.tertiary
        : colors.primary;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: (used.clamp(0, 100)) / 100,
            color: color,
            backgroundColor: colors.surfaceContainerHighest,
            strokeWidth: 4,
          ),
          Text(
            ganjoorDigits(context, '$used%'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.row, required this.largest});

  final GanjoorCategoryTotal row;
  final Money largest;

  @override
  Widget build(BuildContext context) {
    final share = largest.isZero ? 0 : row.amount.percentOf(largest);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(row.category, overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(value: (share.clamp(0, 100)) / 100),
          ),
          const SizedBox(width: 8),
          Text(ganjoorDigits(context, row.amount.formatAmount())),
        ],
      ),
    );
  }
}
