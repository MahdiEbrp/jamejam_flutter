/// ganjoor — see doc/ganjoor.md and AGENTS.md
import 'money.dart';

abstract final class GanjoorDefaults {
  /// Human-facing service name used in help and errors.
  static const String serviceName = 'Ganjoor';

  /// Environment variable carrying the wallet database path.
  static const String databaseEnvironmentVariable = 'JAMEJAM_GANJOOR_DB';

  /// Settings key that stores the base currency code (e.g. `EUR`).
  static const String currencySettingKey = 'ganjoor.currency';

  /// Default base currency for new accounts and reports.
  static const String defaultCurrency = 'USD';

  /// Currency shown for values that live outside accounts (debts, goals).
  static const String baseCurrencyLabel = 'base';

  // ── Financial rails ──

  /// Default maximum size of a single amount.
  static final Money maxAmount = Money.parse('1000000000');

  /// Smallest meaningful amount (one cent).
  static const Money minAmount = Money.cent;

  /// Default number of undo snapshots kept.
  static const int undoDepth = 20;

  // ── Reporting ──

  /// How many category rows the cash-flow report shows by default.
  static const int topCategories = 8;

  /// How many upcoming bill days the due view looks ahead.
  static const int billHorizonDays = 7;

  /// Goals at or above this completion percent are marked nearly done.
  static const int goalNearlyDonePercent = 90;

  /// Budgets at or above this percent of the limit draw a warning.
  static const int budgetWarnPercent = 80;

  /// Debts count as overdue within this many days of the due date.
  static const int debtOverdueDays = 0;

  // ── Input shape ──

  /// Maximum length of account, bill, goal, and person names.
  static const int maxNameLength = 80;

  /// Maximum length of transaction/debt notes.
  static const int maxNotesLength = 400;

  /// Maximum number of tags on one transaction.
  static const int maxTags = 10;

  /// Maximum length of one tag or a category name.
  static const int maxTagLength = 30;

  /// Maximum length of a currency code (ISO 4217 = 3 letters).
  static const int currencyCodeLength = 3;

  // ── AI prompt tunables (Soroush layer) ──

  /// Maximum characters of a user finance question included in AI prompts.
  static const int aiMaxQuestionChars = 400;

  /// Maximum transactions included in the AI insights context.
  static const int aiMaxTransactions = 40;

  /// Maximum categories listed for the AI categorizer.
  static const int aiMaxCategories = 40;

  // ── Safety rails (bounds) ──

  /// Upper rail for a single amount.
  static final Money maxAmountBound = Money.parse('1000000000000');

  /// Upper rail for the undo depth.
  static const int undoDepthBound = 100;

  /// Upper rail for the number of accounts.
  static const int maxAccountsBound = 1000;

  /// Default cap on the number of accounts.
  static const int maxAccounts = 50;

  /// Upper rail for CSV import rows.
  static const int maxImportRowsBound = 50000;

  /// Default cap on CSV import rows.
  static const int maxImportRows = 5000;

  /// Upper rail for budgets.
  static const int maxBudgetsBound = 500;

  /// Upper rail for goals.
  static const int maxGoalsBound = 500;

  /// Upper rail for bills.
  static const int maxBillsBound = 500;

  /// Upper rail for debts.
  static const int maxDebtsBound = 2000;

  /// Upper rail for the AI question length.
  static const int aiMaxQuestionCharsBound = 2000;

  /// Bills never advance more than this many catch-up cycles in one apply.
  ///
  /// The .NET service kept this as a private constant; the port exposes it so the catch-up
  /// rail is testable from the outside.
  static const int billMaxCatchUp = 100;
}
