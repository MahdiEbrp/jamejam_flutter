/// ganjoor — see doc/ganjoor.md and AGENTS.md
import '../../core/date_only.dart';
import '../../core/text_guard.dart';
import 'ganjoor_defaults.dart';
import 'models.dart';
import 'money.dart';

abstract final class MoneyGuard {
  /// Validates and sanitizes a required name (account, bill, goal, person).
  static String name(String? value, int maxLength) =>
      TextGuard.sanitizeRequired(value, maxLength, 'name');

  /// Validates and sanitizes optional notes.
  static String notes(String? value, int maxLength) =>
      TextGuard.sanitizeOptional(value, maxLength, 'notes');

  /// Parses a positive amount within the rail.
  static Money amount(String? text, Money max) {
    final Money parsed;
    try {
      parsed = Money.parse(text);
    } on FormatException {
      throw ArgumentError.value(
        text,
        'amount',
        'Amount must be a number between '
            '${GanjoorDefaults.minAmount.formatAmount()} and '
            '${max.formatAmount()}.',
      );
    }

    if (parsed < GanjoorDefaults.minAmount) {
      throw ArgumentError.value(
        text,
        'amount',
        'Amount must be a number between '
            '${GanjoorDefaults.minAmount.formatAmount()} and '
            '${max.formatAmount()}.',
      );
    }

    return withinAmountRail(parsed, max);
  }

  /// Validates an already-parsed amount against the rail.
  static Money withinAmountRail(Money amount, Money max) {
    if (amount < GanjoorDefaults.minAmount || amount > max) {
      throw ArgumentError.value(
        amount.formatAmount(),
        'amount',
        'Amount must be between ${GanjoorDefaults.minAmount.formatAmount()} '
            'and ${max.formatAmount()}.',
      );
    }
    return amount;
  }

  /// Validates a currency code: exactly three ASCII letters, upper-cased.
  static String currency(String? code) {
    final trimmed = (code ?? '').trim();
    final letters = RegExp(r'^[A-Za-z]{3}$');
    if (trimmed.isEmpty ||
        trimmed.length != GanjoorDefaults.currencyCodeLength ||
        !letters.hasMatch(trimmed)) {
      throw ArgumentError.value(
        code,
        'currency',
        'Currency must be a 3-letter code (e.g. USD, EUR, IRR).',
      );
    }
    return trimmed.toUpperCase();
  }

  /// Validates and sanitizes a category name.
  static String category(String? value) => TextGuard.sanitizeRequired(
    value,
    GanjoorDefaults.maxTagLength,
    'category',
  );

  /// Parses a comma-separated tag list within the rails.
  static List<String> tags(String? csv, int maxCount) {
    if (csv == null || csv.trim().isEmpty) return const [];

    final seen = <String>{};
    final tags = <String>[];
    for (final raw in csv.split(',')) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final tag = TextGuard.sanitizeRequired(
        trimmed,
        GanjoorDefaults.maxTagLength,
        'tag',
      );
      if (seen.add(tag.toLowerCase())) tags.add(tag);
    }

    if (tags.length > maxCount) {
      throw ArgumentError.value(
        csv,
        'tags',
        'At most $maxCount tags are allowed.',
      );
    }
    return tags;
  }

  /// Parses a strict `yyyy-MM-dd` date.
  static DateOnly date(String? text) {
    try {
      return DateOnly.parseIso(text ?? '');
    } on FormatException {
      throw ArgumentError.value(
        text,
        'date',
        'Date must be yyyy-MM-dd (e.g. 2026-09-19).',
      );
    }
  }

  /// Parses a strict `yyyy-MM` month into its first day.
  static DateOnly month(String? text) {
    final trimmed = (text ?? '').trim();
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(trimmed);
    if (match == null) {
      throw ArgumentError.value(
        text,
        'month',
        'Month must be yyyy-MM (e.g. 2026-09).',
      );
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    if (!DateOnly.isValid(year, month, 1)) {
      throw ArgumentError.value(
        text,
        'month',
        'Month must be yyyy-MM (e.g. 2026-09).',
      );
    }
    return DateOnly(year, month, 1);
  }

  /// Parses a transaction kind.
  static GanjoorTxKind kind(String? text) {
    switch ((text ?? '').trim().toLowerCase()) {
      case 'income':
      case 'in':
        return GanjoorTxKind.income;
      case 'expense':
      case 'out':
      case 'spend':
        return GanjoorTxKind.expense;
      case 'transfer':
        return GanjoorTxKind.transfer;
      default:
        throw ArgumentError.value(
          text,
          'kind',
          'Kind must be income, expense, or transfer.',
        );
    }
  }

  /// Parses a bill frequency.
  static GanjoorFrequency frequency(String? text) {
    switch ((text ?? '').trim().toLowerCase()) {
      case 'daily':
      case 'day':
        return GanjoorFrequency.daily;
      case 'weekly':
      case 'week':
        return GanjoorFrequency.weekly;
      case 'monthly':
      case 'month':
        return GanjoorFrequency.monthly;
      case 'yearly':
      case 'year':
        return GanjoorFrequency.yearly;
      default:
        throw ArgumentError.value(
          text,
          'frequency',
          'Frequency must be daily, weekly, monthly, or yearly.',
        );
    }
  }

  /// Parses a positive identifier.
  static int id(String? text, String what) {
    final parsed = int.tryParse((text ?? '').trim());
    if (parsed == null || parsed < 1) {
      throw ArgumentError.value(text, what, '$what must be a positive number.');
    }
    return parsed;
  }

  /// Formats an amount for display, invariant (`"1,234.50 USD"`).
  static String money(Money amount, [String? currency]) =>
      currency == null ? amount.formatAmount() : amount.formatWith(currency);
}
