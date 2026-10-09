/// A calendar date without a time or zone — the Dart counterpart of C# `DateOnly`.
///
/// The .NET toolbox stores due dates with day precision, which is what a to-do list actually
/// needs: "due Tuesday" must not shift when the user travels. Using a value type here (rather
/// than a midnight `DateTime`) keeps the port's semantics identical to the original.
library;

import 'fa_format.dart';

/// A day, month and year, compared and ordered by calendar position.
class DateOnly implements Comparable<DateOnly> {
  const DateOnly(this.year, this.month, this.day);

  /// Builds a date from a `DateTime`, dropping the time and zone.
  factory DateOnly.fromDateTime(DateTime value) =>
      DateOnly(value.year, value.month, value.day);

  /// Parses a strict ISO `yyyy-MM-dd` string.
  ///
  /// Throws [FormatException] for anything else — the caller decides whether to try natural
  /// language next.
  static DateOnly parseIso(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Expected yyyy-MM-dd, got "$value"');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (!isValid(year, month, day)) {
      throw FormatException('"$value" is not a real calendar date');
    }
    return DateOnly(year, month, day);
  }

  /// True when the triple is a real calendar date.
  static bool isValid(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return false;
    return day <= daysInMonth(year, month);
  }

  /// Number of days in [month] of [year], leap years included.
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  final int year;
  final int month;
  final int day;

  /// Days since the Unix epoch — the scalar every arithmetic operation rides on.
  int get _epochDay =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch ~/ 86400000;

  /// 1 = Monday … 7 = Sunday, matching C#'s `DayOfWeek` numbering used by the port.
  int get weekday => DateTime.utc(year, month, day).weekday;

  /// Adds [days] (which may be negative), rolling over month and year boundaries.
  DateOnly addDays(int days) => DateOnly.fromDateTime(
    DateTime.utc(year, month, day).add(Duration(days: days)),
  );

  /// Adds [months], clamping the day to the target month's length — `2026-01-31 + 1 month`
  /// is `2026-02-28`, exactly like `DateOnly.AddMonths`.
  DateOnly addMonths(int months) {
    final rawMonth = month - 1 + months;
    final targetYear = year + (rawMonth ~/ 12);
    final targetMonth = (rawMonth % 12) + 1;
    final clampedDay = day > daysInMonth(targetYear, targetMonth)
        ? daysInMonth(targetYear, targetMonth)
        : day;
    return DateOnly(targetYear, targetMonth, clampedDay);
  }

  /// Signed day difference (`this - other`).
  int differenceInDays(DateOnly other) => _epochDay - other._epochDay;

  /// Midnight UTC on this date — the interchange form for storage and clocks.
  DateTime toUtcDateTime() => DateTime.utc(year, month, day);

  /// `yyyy-MM-dd` — the storage and backup format, culture-invariant by design.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// A locale-aware short form for display.
  ///
  /// Under `en` this is the Gregorian `21 Sep 2026`; under `fa` it is the **Jalali** date in
  /// Persian digits — `۳۱ شهریور ۱۴۰۵` — because a Persian reader
  /// plans in 1405. The conversion itself lives in [FaFormat].
  String format({String? locale}) => FaFormat.date(this, locale);

  @override
  int compareTo(DateOnly other) => _epochDay.compareTo(other._epochDay);

  bool operator <(DateOnly other) => compareTo(other) < 0;
  bool operator <=(DateOnly other) => compareTo(other) <= 0;
  bool operator >(DateOnly other) => compareTo(other) > 0;
  bool operator >=(DateOnly other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is DateOnly &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
