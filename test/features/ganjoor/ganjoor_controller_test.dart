// The wallet screen's state machine: the CLI's verbs as callable state. Everything the
// `ganjoor` command line did — account lifecycle, spend/earn/transfer, budgets with their
// warn thresholds, bills, goals, debts, undo, export/import/CSV, and the AI verbs — is a
// method here, so the CLI's exit codes and printed lines are covered by assertions on the
// controller's messages and its data instead.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/ganjoor/ganjoor_controller.dart';
import 'package:jamejam/features/ganjoor/ganjoor_defaults.dart';
import 'package:jamejam/features/ganjoor/ganjoor_options.dart';
import 'package:jamejam/features/ganjoor/ganjoor_service.dart';
import 'package:jamejam/features/ganjoor/ganjoor_store.dart';
import 'package:jamejam/features/ganjoor/models.dart';
import 'package:jamejam/features/ganjoor/money.dart';
import 'package:jamejam/features/settings/memory_settings_store.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/settings/settings_controller.dart';
import 'package:jamejam/features/soroush/ai_funnel.dart';

final DateTime _clock = DateTime.utc(2026, 9, 19, 10);

String _completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

Future<
  ({
    GanjoorController controller,
    GanjoorService service,
    MemoryGanjoorStore store,
    SettingsController settings,
  })
>
_build({
  GanjoorOptions options = const GanjoorOptions(),
  SettingsController? settings,
  http.Client? httpClient,
  bool withFunnel = true,
  String Function(String key)? environment,
}) async {
  final settingsController =
      settings ?? SettingsController(MemorySettingsStore());
  if (settings == null) await settingsController.load();

  final store = MemoryGanjoorStore();
  final service = GanjoorService(
    store: store,
    clock: () => _clock,
    options: options,
  );
  final controller = GanjoorController(
    service: service,
    settings: settingsController,
    funnel: withFunnel
        ? AiFunnel(
            settings: settingsController,
            secrets: await _seededSecrets(),
            httpClient:
                httpClient ??
                MockClient(
                  (_) async => http.Response(_completion('coffee'), 200),
                ),
          )
        : null,
    environment: environment,
  );
  await controller.initialize();
  return (
    controller: controller,
    service: service,
    store: store,
    settings: settingsController,
  );
}

void main() {
  group('GanjoorController — loading', () {
    test('initialize loads accounts, balances, and the ledger', () async {
      final built = await _build();
      await built.controller.addAccount('Bank', initialBalance: '100');
      await built.controller.spend('Bank', '30', 'food');

      await built.controller.refresh();

      expect(built.controller.accounts.single.name, 'Bank');
      expect(
        built.controller.balanceOf(built.controller.accounts.single),
        Money.parse('70'),
      );
      expect(built.controller.transactions.single.category, 'food');
      expect(built.controller.knownCategories, ['food']);
      expect(built.controller.undoAvailable, isTrue);
      expect(built.controller.totalBalance, Money.parse('70'));
    });

    test('initialize is idempotent', () async {
      final built = await _build();
      await built.controller.addAccount('Bank');
      await built.controller.initialize();
      expect(built.controller.accounts, hasLength(1));
      expect(built.controller.accounts.single.name, 'Bank');
    });

    test('reports cover the selected month, and default to this one', () async {
      final built = await _build();
      await built.controller.addAccount('Bank', initialBalance: '1000');
      await built.controller.spend('Bank', '30', 'food', date: '2026-08-05');
      await built.controller.spend('Bank', '20', 'food');

      expect(built.controller.reportMonth, DateOnly(2026, 9, 1));
      expect(built.controller.cashFlow!.expenses, Money.parse('20'));

      await built.controller.setMonthFilter(DateOnly(2026, 8, 1));
      expect(built.controller.reportMonth, DateOnly(2026, 8, 1));
      expect(built.controller.cashFlow!.expenses, Money.parse('30'));
      expect(built.controller.transactions.single.date.toIso(), '2026-08-05');
    });

    test(
      'a missing rate is reported without losing the rest of the screen',
      () async {
        final built = await _build();
        await built.controller.addAccount(
          'Cash',
          currency: 'USD',
          initialBalance: '10',
        );
        await built.controller.addAccount(
          'Euro',
          currency: 'EUR',
          initialBalance: '10',
        );

        expect(built.controller.error, contains('No exchange rate for EUR'));
        expect(built.controller.totalBalance, isNull);
        expect(built.controller.accounts, hasLength(2));
      },
    );
  });

  group('GanjoorController — filters', () {
    test('account, kind, category, and text narrow the ledger', () async {
      final built = await _build();
      await built.controller.addAccount('Bank');
      await built.controller.addAccount('Cash');
      await built.controller.spend('Bank', '5', 'food', notes: 'soup');
      await built.controller.earn('Cash', '100', 'salary');

      await built.controller.setAccountFilter(
        built.controller.accounts.last.id,
      );
      expect(built.controller.transactions, hasLength(1));
      expect(built.controller.transactions.single.category, 'salary');

      await built.controller.setKindFilter(GanjoorTxKind.expense);
      expect(built.controller.transactions, isEmpty);

      await built.controller.clearFilters();
      expect(built.controller.transactions, hasLength(2));
      expect(built.controller.hasFilters, isFalse);

      await built.controller.setQuery('soup');
      expect(built.controller.transactions, hasLength(1));
      expect(built.controller.hasFilters, isTrue);
    });

    test('archived accounts hide until asked for', () async {
      final built = await _build();
      await built.controller.addAccount('Old');
      final id = built.controller.accounts.single.id;
      await built.controller.archiveAccount(id, true);

      await built.controller.setIncludeArchived(false);
      expect(built.controller.accounts, isEmpty);
      await built.controller.setIncludeArchived(true);
      expect(built.controller.accounts.single.name, 'Old');
    });
  });

  group('GanjoorController — accounts', () {
    test('AccountLifecycle_RenamesArchivesAndRemoves', () async {
      final built = await _build();

      await built.controller.addAccount('Bank');
      expect(built.controller.message, "Account 'Bank' created.");

      final id = built.controller.accounts.single.id;
      await built.controller.renameAccount(id, 'Main');
      expect(built.controller.accounts.single.name, 'Main');

      await built.controller.archiveAccount(id, true);
      expect(built.controller.message, 'Archived Main.');
      expect(built.controller.accounts.single.isArchived, isTrue);

      await built.controller.archiveAccount(id, false);
      expect(built.controller.message, 'Unarchived Main.');

      await built.controller.removeAccount(id);
      expect(
        built.controller.message,
        'Account removed (0 transaction(s) deleted).',
      );
      expect(built.controller.accounts, isEmpty);
    });

    test('a duplicate name fails with the wallet rule', () async {
      final built = await _build();
      await built.controller.addAccount('Cash');
      await built.controller.addAccount('CASH');

      expect(built.controller.error, "An account named 'CASH' already exists.");
    });

    test(
      'removing an account with history needs force, then cascades',
      () async {
        final built = await _build();
        await built.controller.addAccount('Card');
        final id = built.controller.accounts.single.id;
        await built.controller.spend('Card', '9', 'food');

        await built.controller.removeAccount(id);
        expect(built.controller.error, contains('--force'));
        expect(built.controller.accounts, hasLength(1));

        await built.controller.removeAccount(id, force: true);
        expect(
          built.controller.message,
          'Account removed (1 transaction(s) deleted).',
        );
        expect(built.controller.transactions, isEmpty);
      },
    );

    test('CurrencySetting_FlowsIntoNewAccounts', () async {
      final built = await _build();
      await built.settings.set(SettingKeys.ganjoorCurrency, 'eur');

      await built.controller.addAccount('Bank');

      expect(built.controller.accounts.single.currency, 'EUR');
    });

    test('the raw option currency still wins over the setting', () async {
      final built = await _build();
      await built.settings.set(SettingKeys.ganjoorCurrency, 'eur');
      await built.controller.addAccount('Bank', currency: 'USD');
      expect(built.controller.accounts.single.currency, 'USD');
    });

    test(
      'a bad currency in settings is reported, not silently dropped',
      () async {
        final built = await _build();
        await built.settings.set(SettingKeys.ganjoorCurrency, 'euros');
        await built.controller.addAccount('Bank');
        expect(built.controller.error, contains('3-letter code'));
        expect(built.controller.accounts, isEmpty);
      },
    );
  });

  group('GanjoorController — money', () {
    test('MoneyLifecycle_PrintsBalances_AndWarnsOnBudget', () async {
      final built = await _build();
      await built.controller.addAccount('Bank', initialBalance: '100');
      await built.controller.setBudget('food', '50');
      expect(built.controller.message, 'Budget set: food ≤ 50.00 per month.');

      await built.controller.spend('Bank', '45', 'food');
      expect(
        built.controller.message,
        'Budget check: food at 90% — 5.00 left this month.',
      );
      expect(built.controller.alerts.single.close, isTrue);
      expect(built.controller.alerts.single.over, isFalse);

      await built.controller.spend('Bank', '10', 'food');
      expect(built.controller.message, 'Over budget: food — 55.00 of 50.00.');
      expect(built.controller.alerts.single.over, isTrue);
      expect(
        built.controller.balanceOf(built.controller.accounts.single),
        Money.parse('45'),
      );
      expect(built.controller.error, isNull);
    });

    test('a 79% budget stays silent', () async {
      final built = await _build();
      await built.controller.addAccount('Bank', initialBalance: '100');
      await built.controller.setBudget('food', '100');
      await built.controller.spend('Bank', '79', 'food');
      expect(built.controller.message, '#1 recorded.');
      expect(built.controller.alerts, isEmpty);
    });

    test('Earn renders the signed amount and leaves spending alone', () async {
      final built = await _build();
      await built.controller.addAccount('Bank');
      await built.controller.earn('Bank', '500', 'salary');

      expect(built.controller.transactions.single.kind, GanjoorTxKind.income);
      expect(built.controller.cashFlow!.income, Money.parse('500'));
      expect(built.controller.cashFlow!.expenses, Money.zero);
    });

    test('transfers move money and name the target account', () async {
      final built = await _build();
      await built.controller.addAccount('Bank', initialBalance: '100');
      await built.controller.addAccount('Cash');
      await built.controller.transfer('Bank', 'Cash', '60', notes: 'pocket');

      final tx = built.controller.transactions.single;
      expect(built.controller.message, 'Transferred 60.00.');
      expect(built.controller.transferTargetName(tx), 'Cash');
      expect(built.controller.cashFlow!.expenses, Money.zero);
    });

    test('a transfer needs two accounts of one currency', () async {
      final built = await _build();
      await built.controller.addAccount('A');
      await built.controller.transfer('A', 'A', '5');
      expect(
        built.controller.error,
        'A transfer needs two different accounts.',
      );

      await built.controller.addAccount('Euro', currency: 'EUR');
      await built.controller.transfer('A', 'Euro', '5');
      expect(built.controller.error, contains('matching currencies'));
    });

    test('a bad amount is refused with the rail message', () async {
      final built = await _build();
      await built.controller.addAccount('Bank');
      await built.controller.spend('Bank', '0', 'food');
      expect(
        built.controller.error,
        contains('Amount must be a number between'),
      );
      expect(built.controller.transactions, isEmpty);
    });

    test('recategorize and delete round out the ledger verbs', () async {
      final built = await _build();
      await built.controller.addAccount('Bank');
      await built.controller.spend('Bank', '5', 'food');
      final id = built.controller.transactions.single.id;

      await built.controller.recategorize(id, 'groceries');
      expect(built.controller.message, '#$id categorized as groceries.');
      expect(built.controller.transactions.single.category, 'groceries');

      await built.controller.deleteTransaction(id);
      expect(built.controller.message, 'Transaction #$id removed.');
      expect(built.controller.transactions, isEmpty);
    });
  });

  group('GanjoorController — bills, goals, debts', () {
    test('BillCommands_Flow', () async {
      final built = await _build();
      await built.controller.addAccount('Bank', initialBalance: '5000');
      await built.controller.addBill(
        'Rent',
        '950',
        'out',
        'housing',
        'monthly',
        next: '2026-09-01',
      );
      expect(built.controller.message, 'Added bill #1: Rent.');
      expect(built.controller.dueBills.single.name, 'Rent');

      await built.controller.applyDueBills();
      expect(built.controller.message, 'Recorded 1 bill occurrence(s).');
      expect(built.controller.dueBills, isEmpty);
      expect(built.controller.transactions.single.amount, Money.parse('950'));
      expect(built.controller.transactions.single.fromBillId, 1);

      await built.controller.removeBill(1);
      expect(built.controller.message, "Removed bill 'Rent'.");
      expect(built.controller.bills, isEmpty);
    });

    test('nothing due is a friendly no-op', () async {
      final built = await _build();
      await built.controller.addAccount('Bank', initialBalance: '5000');
      await built.controller.addBill(
        'Rent',
        '950',
        'out',
        'housing',
        'monthly',
        next: '2026-10-01',
      );
      await built.controller.applyDueBills();
      expect(built.controller.message, 'Nothing was due.');
    });

    test('bills reject transfers and bad intervals', () async {
      final built = await _build();
      await built.controller.addAccount('Bank');
      await built.controller.addBill(
        'Move',
        '10',
        'transfer',
        'moving',
        'monthly',
      );
      expect(built.controller.error, contains('not a transfer'));

      await built.controller.addBill(
        'Bad',
        '10',
        'out',
        'c',
        'weekly',
        interval: '0',
      );
      expect(
        built.controller.error,
        contains('Interval must be between 1 and 365'),
      );
    });

    test('Goals_And_Debts_Flow', () async {
      final built = await _build();
      await built.controller.addGoal('Laptop', '100', deadline: '2026-12-31');
      await built.controller.contribute(1, '95');

      final goal = built.controller.goals.single;
      expect(goal.percent, 95);
      expect(
        goal.percent >= GanjoorDefaults.goalNearlyDonePercent,
        isTrue,
        reason: 'the screen flags ✨ almost there from this threshold',
      );

      await built.controller.contribute(1, '10');
      expect(built.controller.error, contains('only needs 5.00 more'));

      await built.controller.withdraw(1, '100');
      expect(built.controller.error, contains('holds only 95.00'));
      await built.controller.withdraw(1, '10');
      expect(built.controller.goals.single.contributed, Money.parse('85'));

      await built.controller.removeGoal(1);
      expect(built.controller.message, "Removed goal 'Laptop'.");
      expect(built.controller.goals, isEmpty);

      await built.controller.addDebt('Sara', '150', owedByMe: false);
      await built.controller.settleDebt(1, '150');
      expect(built.controller.message, 'Debt #1 (Sara) fully settled.');
      expect(built.controller.debts.single.settledInFull, isTrue);

      await built.controller.removeDebt(1);
      expect(built.controller.message, 'Removed debt #1 (Sara).');
      expect(built.controller.debts, isEmpty);
    });

    test('partial settlement keeps the outstanding amount', () async {
      final built = await _build();
      await built.controller.addDebt('Landlord', '600', owedByMe: true);
      await built.controller.settleDebt(1, '250');
      expect(built.controller.message, 'Debt #1: 350.00 outstanding.');
      expect(built.controller.debts.single.outstanding, Money.parse('350'));
    });

    test('DebtDirection is a required choice, not a default', () async {
      final built = await _build();
      await built.controller.addDebt('Sara', '150', owedByMe: false);
      expect(built.controller.debts.single.owedByMe, isFalse);
      expect(built.controller.debts.single.person, 'Sara');
    });

    test('NetWorth_And_Report', () async {
      final built = await _build();
      await built.controller.addAccount('Bank', initialBalance: '900');
      await built.controller.spend('Bank', '300', 'housing');
      await built.controller.addDebt('Sara', '150', owedByMe: false);

      expect(built.controller.cashFlow!.expenses, Money.parse('300'));
      expect(built.controller.cashFlow!.byCategory.single.category, 'housing');
      expect(built.controller.netWorth!.total, Money.parse('750'));
      expect(built.controller.netWorth!.receivable, Money.parse('150'));
      expect(built.controller.totalBalance, Money.parse('600'));
    });
  });

  group('GanjoorController — undo, files, and the AI gate', () {
    test('undo reverts one whole command at a time', () async {
      final built = await _build();
      await built.controller.addAccount('Bank', initialBalance: '100');
      await built.controller.spend('Bank', '30', 'food');

      await built.controller.undo();
      expect(built.controller.message, 'Undone.');
      expect(built.controller.transactions, isEmpty);
      expect(
        built.controller.balanceOf(built.controller.accounts.single),
        Money.parse('100'),
      );

      await built.controller.undo();
      expect(built.controller.accounts, isEmpty);
      expect(built.controller.undoAvailable, isFalse);

      await built.controller.undo();
      expect(built.controller.message, 'Nothing to undo.');
    });

    test('ExportImport_WorkThroughFiles', () async {
      final directory = Directory.systemTemp.createTempSync('ganjoor-io');
      try {
        final path = '${directory.path}/wallet.json';
        final built = await _build();
        await built.controller.addAccount('Bank', initialBalance: '10');

        await built.controller.exportJsonTo(path);
        expect(built.controller.message, contains('Exported to'));
        expect(File(path).existsSync(), isTrue);

        await built.controller.removeAccount(
          built.controller.accounts.single.id,
          force: true,
        );
        expect(built.controller.accounts, isEmpty);

        await built.controller.importJsonFrom(path);
        expect(built.controller.accounts.single.name, 'Bank');
        expect(built.controller.message, contains('ganjoor undo reverts it'));

        await built.controller.undo();
        expect(built.controller.accounts, isEmpty);
      } finally {
        directory.deleteSync(recursive: true);
      }
    });

    test('an empty path is refused before touching the disk', () async {
      final built = await _build();
      await built.controller.exportJsonTo('   ');
      expect(built.controller.error, 'Type a file path first.');
      await built.controller.importJsonFrom('');
      expect(built.controller.error, 'Type a file path first.');
    });

    test('a broken backup file reports the parser message', () async {
      final directory = Directory.systemTemp.createTempSync('ganjoor-bad');
      try {
        final path = '${directory.path}/broken.json';
        File(path).writeAsStringSync('{broken');
        final built = await _build();
        await built.controller.importJsonFrom(path);
        expect(
          built.controller.error,
          'The backup is not a valid Ganjoor file.',
        );
      } finally {
        directory.deleteSync(recursive: true);
      }
    });

    test('a CSV import needs a target account', () async {
      final built = await _build();
      await built.controller.importCsvFrom('statement.csv', account: ' ');
      expect(built.controller.error, contains('target account'));
    });

    test('CSV import and export round trip through the controller', () async {
      final directory = Directory.systemTemp.createTempSync('ganjoor-csv-ui');
      try {
        final out = '${directory.path}/out.csv';
        final built = await _build();
        await built.controller.addAccount('Bank', initialBalance: '100');
        await built.controller.spend('Bank', '10', 'food', notes: 'soup');

        expect(await built.controller.exportCsvTo(out), 1);
        expect(File(out).readAsStringSync(), contains('soup,-10.00'));

        await built.controller.addAccount('Cash');
        // The export writes the same header line the importer expects.
        await built.controller.importCsvFrom(
          out,
          account: 'Cash',
          hasHeader: true,
        );
        expect(built.controller.message, 'Imported 1 row(s), skipped 0.');
      } finally {
        directory.deleteSync(recursive: true);
      }
    });

    test('Ai_WithoutAKeyOrFunnel_IsUnavailable', () async {
      final built = await _build(withFunnel: false);
      await built.controller.aiInsights();
      expect(built.controller.error, 'AI is not available in this context.');
      expect(built.controller.aiAvailable, isFalse);
    });

    test('AiCategorize_Suggests_ThenApplies', () async {
      final prompts = <String>[];
      final built = await _build(
        httpClient: MockClient((request) async {
          prompts.add(
            jsonDecode(request.body)['messages'][0]['content'] as String,
          );
          return http.Response(_completion('**coffee**'), 200);
        }),
      );
      await built.controller.addAccount('Bank');
      await built.controller.spend(
        'Bank',
        '4.80',
        'uncategorised',
        notes: 'espresso bar',
      );
      await built.controller.setBudget('coffee', '10'); // gives the AI a name

      await built.controller.aiCategorize(1);
      expect(built.controller.aiAnswer, 'Suggestion: coffee');
      expect(built.controller.transactions.single.category, 'uncategorised');

      await built.controller.aiCategorize(1, apply: true);
      expect(built.controller.transactions.single.category, 'coffee');
      expect(built.controller.message, '#1 categorized as coffee.');

      expect(prompts, hasLength(2));
      expect(prompts[0], contains('---CATEGORIES BEGIN---'));
      expect(prompts[0], contains('untrusted data'));
    });

    test('AiCategorize_UnknownSuggestion_FailsFriendly', () async {
      final built = await _build(
        httpClient: MockClient(
          (_) async => http.Response(_completion('spaceships'), 200),
        ),
      );
      await built.controller.addAccount('Bank');
      await built.controller.spend('Bank', '4.80', 'uncategorised');

      await built.controller.aiCategorize(1);

      expect(built.controller.error, contains('no known category'));
      expect(built.controller.transactions.single.category, 'uncategorised');
    });

    test('AiInsights_AndAsk_FlowThroughTheGate', () async {
      final prompts = <String>[];
      final built = await _build(
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          prompts.add((body['messages']! as List).first['content'] as String);
          return http.Response(_completion('You are fine.'), 200);
        }),
      );
      await built.controller.addAccount('Bank', initialBalance: '50');

      await built.controller.aiInsights();
      expect(built.controller.aiAnswer, 'You are fine.');
      expect(built.controller.aiKind, 'insights');

      await built.controller.aiAsk('Where does my money go?');
      expect(built.controller.aiQuestion, 'Where does my money go?');
      expect(prompts[0], contains('---FINANCE BEGIN---'));
      expect(prompts[1], contains('Question: Where does my money go?'));
    });

    test('a blank AI question is refused by the prompt builder', () async {
      final built = await _build();
      await built.controller.addAccount('Bank', initialBalance: '50');
      await built.controller.aiAsk('   ');
      expect(built.controller.error, isNotNull);
    });

    test('default export path lives in the toolbox folder', () async {
      final built = await _build(
        environment: (key) => key == 'JAMEJAM_HOME' ? '/tmp/toolbox' : '',
      );
      expect(
        await built.controller.defaultExportPath('wallet.json'),
        '/tmp/toolbox/ganjoor/wallet.json',
      );
    });
  });

  group('GanjoorController — store failures', () {
    test('StoreFailures_BecomeFriendlyErrors', () async {
      final settings = SettingsController(MemorySettingsStore());
      await settings.load();
      final store = _BrokenTransactionStore();
      final controller = GanjoorController(
        service: GanjoorService(
          store: store,
          clock: () => _clock,
          options: const GanjoorOptions(),
        ),
        settings: settings,
      );
      await controller.initialize();
      await controller.addAccount('Bank');

      await controller.spend('Bank', '5', 'food');

      expect(controller.error, contains('store is broken'));
      expect(controller.busy, isFalse);
    });
  });
}

/// A store whose transaction writes always fail — the .NET `ThrowingStore`.
class _BrokenTransactionStore extends MemoryGanjoorStore {
  @override
  Future<GanjoorTransaction> addTransaction(
    GanjoorTransaction transaction,
  ) async => throw StateError('store is broken');
}

/// A secret store holding one AI key.
///
/// The funnel refuses to call a non-loopback endpoint without a key — the .NET's
/// `CompleteAiRequestAsync` gate — so a fixture that wants a request on the wire needs a key,
/// exactly like the original's tests (`ApiKey = "test-key-1234"`).
Future<MemorySecretStore> _seededSecrets() async {
  final secrets = MemorySecretStore();
  await secrets.write(SecretKeys.aiApiKey, 'sk-test');
  return secrets;
}
