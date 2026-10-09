/// ganjoor — see doc/ganjoor.md and AGENTS.md
library;

class Money implements Comparable<Money> {
  /// Wraps an exact count of minor units (cents).
  const Money.fromMinor(this.minorUnits);

  /// Zero in any currency.
  static const Money zero = Money.fromMinor(0);

  /// One cent.
  static const Money cent = Money.fromMinor(1);

  /// Exact count of minor units — the value the wallet stores and does arithmetic on.
  final int minorUnits;

  /// Parses invariant text (`"42.5"`, `"1,234.5"`, `"-5"`) without applying a rail.
  ///
  /// Mirrors `decimal.TryParse(text, NumberStyles.Number, InvariantCulture)`: leading and
  /// trailing whitespace, a leading sign, a decimal point, and comma group separators are
  /// accepted; exponents are not. Throws [FormatException] when the text is not a number —
  /// callers turn that into the wallet's own message.
  static Money parse(String? text) {
    final input = (text ?? '').trim();
    if (input.isEmpty) throw FormatException('Not a number: "$text"');

    var body = input;
    var negative = false;
    if (body.startsWith('+')) {
      body = body.substring(1);
    } else if (body.startsWith('-')) {
      negative = true;
      body = body.substring(1);
    }

    // Group separators are allowed in either position, like `NumberStyles.Number`.
    body = body.replaceAll(',', '');
    if (body.isEmpty) throw FormatException('Not a number: "$text"');

    final parts = body.split('.');
    if (parts.length > 2) throw FormatException('Not a number: "$text"');

    final whole = parts[0].isEmpty ? '0' : parts[0];
    final fraction = parts.length == 2 ? parts[1] : '';
    if (!RegExp(r'^\d+$').hasMatch(whole) ||
        (fraction.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fraction))) {
      throw FormatException('Not a number: "$text"');
    }

    final wholeMinor = int.parse(whole) * 100;
    final cents = _roundFraction(fraction);
    final total = wholeMinor + cents;
    return Money.fromMinor(negative ? -total : total);
  }

  /// Rounds a fractional digit string to whole cents, half away from zero (`"5"` → 1).
  static int _roundFraction(String fraction) {
    if (fraction.isEmpty) return 0;
    final padded = fraction.padRight(3, '0');
    final cents = int.parse(padded.substring(0, 2));
    return padded[2].codeUnitAt(0) >= '5'.codeUnitAt(0) ? cents + 1 : cents;
  }

  /// Splits a stored decimal string (`"1234.50"`) — the SQLite/backup spelling.
  static Money fromStorage(String value) => parse(value);

  /// The storage spelling: plain decimal, no group separators (`"1234.50"`).
  ///
  /// The .NET wallet stored `decimal.ToString(InvariantCulture)`, which keeps the scale it
  /// was given (`42` stayed `42`). The port always writes two places, so the column is at
  /// least as strict and the value round-trips exactly through [fromStorage].
  String toStorage() {
    final negative = minorUnits < 0;
    final absolute = minorUnits.abs();
    final whole = absolute ~/ 100;
    final cents = (absolute % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$whole.$cents';
  }

  /// Formats with thousands separators and exactly two decimals (`"1,234.50"`).
  ///
  /// Port of `MoneyGuard.Money(amount)`.
  String formatAmount() {
    final negative = minorUnits < 0;
    final absolute = minorUnits.abs();
    final whole = (absolute ~/ 100).toString();
    final cents = (absolute % 100).toString().padLeft(2, '0');
    final grouped = _group(whole);
    return '${negative ? '-' : ''}$grouped.$cents';
  }

  /// Formats amount and currency (`"1,234.50 USD"`).
  ///
  /// Port of `MoneyGuard.Money(amount, currency)`.
  String formatWith(String currency) => '${formatAmount()} $currency';

  static String _group(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Returns this value when it sits inside `[GanjoorDefaults.minAmount, max]`.
  ///
  /// Port of `MoneyGuard.WithinAmountRail`; throws [ArgumentError] with the wallet's own
  /// message so callers can show it verbatim.
  Money withinRail(Money max, {String paramName = 'amount'}) {
    if (minorUnits < cent.minorUnits || this > max) {
      throw ArgumentError.value(
        formatAmount(),
        paramName,
        'Amount must be between ${cent.formatAmount()} '
        'and ${max.formatAmount()}.',
      );
    }
    return this;
  }

  /// True when the value is at least one cent.
  bool get isPositive => minorUnits >= cent.minorUnits;

  /// This value as a percentage of [limit], rounded half away from zero.
  ///
  /// Port of `GanjoorBudgetStatus.PercentUsed`'s `decimal` division — done in integers here,
  /// so it cannot inherit a floating-point tie.
  int percentOf(Money limit) {
    if (limit.minorUnits == 0) return 0;
    final numerator = minorUnits * 100;
    final denominator = limit.minorUnits;
    final negative = (numerator < 0) != (denominator < 0);
    final absolute =
        (numerator.abs() * 2 + denominator.abs()) ~/ (denominator.abs() * 2);
    return negative ? -absolute : absolute;
  }

  /// Scales by a rate expressed as money (`rate` base units per unit), rounded half away.
  ///
  /// `100.00 USD × 2.00 = 200.00`; both sides are minor units, so the result divides by 100.
  Money scaledBy(Money rate) {
    final numerator = minorUnits * rate.minorUnits;
    const denominator = 100;
    final negative = numerator < 0;
    final absolute = (numerator.abs() + denominator ~/ 2) ~/ denominator;
    return Money.fromMinor(negative ? -absolute : absolute);
  }

  /// Multiplies by a whole number (percentage helpers).
  Money times(int factor) => Money.fromMinor(minorUnits * factor);

  Money operator +(Money other) =>
      Money.fromMinor(minorUnits + other.minorUnits);

  Money operator -(Money other) =>
      Money.fromMinor(minorUnits - other.minorUnits);

  Money operator -() => Money.fromMinor(-minorUnits);

  bool get isNegative => minorUnits < 0;

  bool get isZero => minorUnits == 0;

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  bool operator <(Money other) => minorUnits < other.minorUnits;
  bool operator <=(Money other) => minorUnits <= other.minorUnits;
  bool operator >(Money other) => minorUnits > other.minorUnits;
  bool operator >=(Money other) => minorUnits >= other.minorUnits;

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => formatAmount();
}
