/// ganjoor — see doc/ganjoor.md and AGENTS.md
import 'ganjoor_defaults.dart';
import 'models.dart';
import 'money.dart';
import 'money_guard.dart';

class GanjoorOptions {
  const GanjoorOptions({
    this.defaultCurrency = GanjoorDefaults.defaultCurrency,
    Money? maxAmount,
    this.undoDepth = GanjoorDefaults.undoDepth,
    this.maxAccounts = GanjoorDefaults.maxAccounts,
    this.maxImportRows = GanjoorDefaults.maxImportRows,
    this.aiMaxTransactions = GanjoorDefaults.aiMaxTransactions,
    this.aiMaxCategories = GanjoorDefaults.aiMaxCategories,
    this.aiMaxQuestionChars = GanjoorDefaults.aiMaxQuestionChars,
    this.rates = const {},
  }) : _maxAmount = maxAmount;

  /// Base currency: new accounts default to it, reports convert into it.
  final String defaultCurrency;

  final Money? _maxAmount;

  /// Rail for a single amount.
  Money get maxAmount => _maxAmount ?? GanjoorDefaults.maxAmount;

  /// How many undo snapshots to keep.
  final int undoDepth;

  /// Maximum number of accounts.
  final int maxAccounts;

  /// Maximum rows accepted by one CSV import.
  final int maxImportRows;

  /// Maximum transactions included in the AI insights context.
  final int aiMaxTransactions;

  /// Maximum categories listed for the AI categorizer.
  final int aiMaxCategories;

  /// Maximum characters of a user question inside AI prompts.
  final int aiMaxQuestionChars;

  /// Exchange rates into the base currency: one unit of the key is worth this much base.
  ///
  /// The .NET record held `decimal` rates; the port holds [Money] (the rate is itself an
  /// amount in the base currency), so conversion stays exact integer arithmetic. The base
  /// currency itself always converts as 1 and may be omitted.
  final Map<String, Money> rates;

  /// Reads the rails from the environment, falling back to the defaults.
  ///
  /// The .NET CLI bound these through `GanjoorOptions`; a GUI has no flags, but the
  /// environment is still the operator's seam — and it keeps the parity tests honest.
  factory GanjoorOptions.fromEnvironment(Map<String, String> environment) {
    const defaults = GanjoorOptions();
    int read(String key, int fallback) =>
        int.tryParse(environment[key] ?? '') ?? fallback;

    final currency = environment['JAMEJAM_GANJOOR_CURRENCY'];
    final maxAmount = environment['JAMEJAM_GANJOOR_MAX_AMOUNT'];
    final rates = <String, Money>{};
    for (final entry in environment.entries) {
      const prefix = 'JAMEJAM_GANJOOR_RATE_';
      if (!entry.key.startsWith(prefix)) continue;
      final code = entry.key.substring(prefix.length);
      try {
        rates[code] = Money.parse(entry.value);
      } on FormatException {
        continue; // a broken rate is reported by validate(), not by the parser
      }
    }

    return GanjoorOptions(
      defaultCurrency: currency == null || currency.trim().isEmpty
          ? defaults.defaultCurrency
          : currency,
      maxAmount: maxAmount == null || maxAmount.trim().isEmpty
          ? null
          : Money.parse(maxAmount),
      undoDepth: read('JAMEJAM_GANJOOR_UNDO_DEPTH', defaults.undoDepth),
      maxAccounts: read('JAMEJAM_GANJOOR_MAX_ACCOUNTS', defaults.maxAccounts),
      maxImportRows: read(
        'JAMEJAM_GANJOOR_MAX_IMPORT_ROWS',
        defaults.maxImportRows,
      ),
      aiMaxTransactions: read(
        'JAMEJAM_GANJOOR_AI_MAX_TRANSACTIONS',
        defaults.aiMaxTransactions,
      ),
      aiMaxCategories: read(
        'JAMEJAM_GANJOOR_AI_MAX_CATEGORIES',
        defaults.aiMaxCategories,
      ),
      aiMaxQuestionChars: read(
        'JAMEJAM_GANJOOR_AI_MAX_QUESTION_CHARS',
        defaults.aiMaxQuestionChars,
      ),
      rates: rates,
    );
  }

  /// Validates every value against its named rail and the currency policy.
  void validate() {
    try {
      MoneyGuard.currency(defaultCurrency);
    } on ArgumentError catch (error) {
      throw GanjoorException('Default currency is invalid: ${error.message}');
    }

    if (maxAmount < GanjoorDefaults.minAmount ||
        maxAmount > GanjoorDefaults.maxAmountBound) {
      throw GanjoorException(
        'MaxAmount must be between ${GanjoorDefaults.minAmount.formatAmount()} '
        'and ${GanjoorDefaults.maxAmountBound.formatAmount()}.',
      );
    }

    if (undoDepth < 0 || undoDepth > GanjoorDefaults.undoDepthBound) {
      throw GanjoorException(
        'UndoDepth must be between 0 and ${GanjoorDefaults.undoDepthBound}.',
      );
    }

    if (maxAccounts < 1 || maxAccounts > GanjoorDefaults.maxAccountsBound) {
      throw GanjoorException(
        'MaxAccounts must be between 1 and '
        '${GanjoorDefaults.maxAccountsBound}.',
      );
    }

    if (maxImportRows < 1 ||
        maxImportRows > GanjoorDefaults.maxImportRowsBound) {
      throw GanjoorException(
        'MaxImportRows must be between 1 and '
        '${GanjoorDefaults.maxImportRowsBound}.',
      );
    }

    if (aiMaxTransactions < 1 ||
        aiMaxTransactions > GanjoorDefaults.aiMaxTransactions) {
      throw GanjoorException(
        'AiMaxTransactions must be between 1 and '
        '${GanjoorDefaults.aiMaxTransactions}.',
      );
    }

    if (aiMaxCategories < 1 ||
        aiMaxCategories > GanjoorDefaults.aiMaxCategories) {
      throw GanjoorException(
        'AiMaxCategories must be between 1 and '
        '${GanjoorDefaults.aiMaxCategories}.',
      );
    }

    if (aiMaxQuestionChars < 1 ||
        aiMaxQuestionChars > GanjoorDefaults.aiMaxQuestionCharsBound) {
      throw GanjoorException(
        'AiMaxQuestionChars must be between 1 and '
        '${GanjoorDefaults.aiMaxQuestionCharsBound}.',
      );
    }

    for (final entry in rates.entries) {
      try {
        MoneyGuard.currency(entry.key);
      } on ArgumentError catch (error) {
        throw GanjoorException('Rate currency is invalid: ${error.message}');
      }

      if (entry.value <= Money.zero ||
          entry.value > GanjoorDefaults.maxAmountBound) {
        throw GanjoorException(
          'Rate for ${entry.key.toUpperCase()} must be between 0 and '
          '${GanjoorDefaults.maxAmountBound.formatAmount()}.',
        );
      }
    }
  }

  /// The rate for [currency] (`null` when the wallet has none for it).
  Money? rateFor(String currency) {
    final wanted = currency.toUpperCase();
    for (final entry in rates.entries) {
      if (entry.key.toUpperCase() == wanted) return entry.value;
    }
    return null;
  }

  GanjoorOptions copyWith({
    String? defaultCurrency,
    Money? maxAmount,
    int? undoDepth,
    int? maxAccounts,
    int? maxImportRows,
    int? aiMaxTransactions,
    int? aiMaxCategories,
    int? aiMaxQuestionChars,
    Map<String, Money>? rates,
  }) => GanjoorOptions(
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    maxAmount: maxAmount ?? _maxAmount,
    undoDepth: undoDepth ?? this.undoDepth,
    maxAccounts: maxAccounts ?? this.maxAccounts,
    maxImportRows: maxImportRows ?? this.maxImportRows,
    aiMaxTransactions: aiMaxTransactions ?? this.aiMaxTransactions,
    aiMaxCategories: aiMaxCategories ?? this.aiMaxCategories,
    aiMaxQuestionChars: aiMaxQuestionChars ?? this.aiMaxQuestionChars,
    rates: rates ?? this.rates,
  );

  @override
  String toString() =>
      'GanjoorOptions($defaultCurrency, undoDepth: $undoDepth)';
}
