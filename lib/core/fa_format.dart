/// Persian display polish: the digits and the calendar a Persian reader expects.
///
/// The .NET toolbox printed `2026-09-21 09:00` and `1405/6/30` wherever a console had no
/// culture set, and the app's `app_fa.arb` already writes Persian digits inside its own
/// literals (`۳۰، ۱۰`, `۲۰۰۰ رویداد`) — but an interpolated number arrives from Dart as ASCII
/// digits, so a chip read `۵ رویداد` next to `۷ روز آینده`. This helper is the one place that
/// decides how a number is *shown*, so every screen can agree:
///
/// ```dart
/// FaFormat.at(locale, '${events.length}')   // '5' under en, '۵' under fa
/// ```
///
/// It deliberately does not touch storage, input or the wire: an `fa` reader still types
/// `2026-09-21` and still receives ASCII digits from a sync peer — only the rendering changes.
library;

import 'date_only.dart';
import 'jalali.dart';

/// Renders numbers for the reader's locale, without touching any stored value.
abstract final class FaFormat {
  /// The Persian digits `0…9`, in order.
  static const List<String> persianDigits = [
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹',
  ];

  /// Whether [locale] is a Persian locale (`fa`, `fa-IR`, …).
  ///
  /// The **primary** subtag decides: `fao` is Faroese, so a prefix test would be wrong.
  static bool isPersian(String? locale) {
    if (locale == null) return false;
    final primary = locale.toLowerCase().split(RegExp('[-_]')).first;
    return primary == 'fa';
  }

  /// [text] with every ASCII digit replaced by its Persian counterpart.
  ///
  /// Anything that is not a digit is left exactly as it was, so a string that already mixes
  /// scripts (a URL, a `2026-09-21` the reader typed, a file name) survives unchanged apart
  /// from its numerals.
  static String digits(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final digit = rune >= 0x30 && rune <= 0x39 ? rune - 0x30 : null;
      buffer.write(
        digit == null ? String.fromCharCode(rune) : persianDigits[digit],
      );
    }
    return buffer.toString();
  }

  /// [text] as the reader's locale shows it: Persian digits under `fa`, unchanged otherwise.
  static String at(String? locale, String text) =>
      isPersian(locale) ? digits(text) : text;

  /// A date the way the reader's locale writes it.
  ///
  /// * `en` — the Gregorian `21 Sep 2026` (the .NET's `"d MMM yyyy"`, culture-invariant in a
  ///   console without a culture set, spelled out here).
  /// * `fa` — the **Jalali** date with Persian digits and the Persian month name,
  ///   `۳۱ شهریور ۱۴۰۵`.
  ///
  /// The two are different days of the same instant, which is the whole point: a Persian
  /// reader plans in 1405, not 2026.
  static String date(DateOnly day, String? locale) {
    if (!isPersian(locale)) {
      return '${day.day} ${_gregorianMonths[day.month - 1]} ${day.year}';
    }
    final jalali = Jalali.fromGregorian(day.year, day.month, day.day);
    return digits(
      '${jalali.day} ${jalaliMonthsFa[jalali.month - 1]} ${jalali.year}',
    );
  }

  /// An instant's date and time of day, for the reader's locale.
  ///
  /// `en` — `2026-09-21 09:00`, the culture-invariant storage form the .NET printed, which is
  /// also what a log line wants; `fa` — the Jalali day with Persian digits,
  /// `۳۱ شهریور ۱۴۰۵ ۰۹:۰۰`.
  static String dateTime(DateTime instant, String? locale) {
    final local = instant.toLocal();
    final clock =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    if (!isPersian(locale)) {
      final iso =
          '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
      return '$iso $clock';
    }
    final day = date(DateOnly(local.year, local.month, local.day), locale);
    return digits('$day $clock');
  }

  static const List<String> _gregorianMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
