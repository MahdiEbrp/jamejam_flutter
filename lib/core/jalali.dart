/// The Jalali (Solar Hijri) calendar — the port's own arithmetic, shared by the calendar,
/// the task list's due dates and any screen that shows a Persian date.
///
/// Port of Borkowski's algorithm (the reference `jalaali-js` implementation), which is the
/// same arithmetic `System.Globalization.PersianCalendar` applies over its supported range.
library;

/// Persian month names, Farvardin to Esfand — the display half of the conversion.
const List<String> jalaliMonths = [
  'Farvardin',
  'Ordibehesht',
  'Khordad',
  'Tir',
  'Mordad',
  'Shahrivar',
  'Mehr',
  'Aban',
  'Azar',
  'Dey',
  'Bahman',
  'Esfand',
];

/// The Persian half of [jalaliMonths] — what an `fa` reader sees.
const List<String> jalaliMonthsFa = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

/// Weekday names, Monday first (the port's `DateTime.weekday` convention).
const List<String> weekdayNamesFa = [
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
  'شنبه',
  'یکشنبه',
];

/// Raised when a Jalali conversion is asked for a year outside the algorithm's range.
class JalaliException implements Exception {
  JalaliException(this.message);

  /// What went wrong, in the same reader-facing style as the rest of the app's errors.
  final String message;

  @override
  String toString() => message;
}

/// A Jalali (Solar Hijri) calendar date.
class Jalali {
  const Jalali(this.year, this.month, this.day);

  /// Jalali year (e.g. 1405).
  final int year;

  /// Month 1…12 (Farvardin … Esfand).
  final int month;

  /// Day of month.
  final int day;

  /// Converts a Gregorian date to Jalali.
  ///
  /// Port of Borkowski's algorithm (the reference `jalaali-js` implementation), which is the
  /// same arithmetic `System.Globalization.PersianCalendar` applies over its supported range.
  static Jalali fromGregorian(int gy, int gm, int gd) {
    final jdn = _g2d(gy, gm, gd);
    final gregorianYear = _d2g(jdn).$1;
    var jalaliYear = gregorianYear - 621;
    final march = _jalCal(jalaliYear).march;
    var firstDayOfYear = _g2d(gregorianYear, 3, march);
    var dayOfYear = jdn - firstDayOfYear;

    int month;
    int day;
    if (dayOfYear >= 0) {
      if (dayOfYear <= 185) {
        month = 1 + dayOfYear ~/ 31;
        day = dayOfYear % 31 + 1;
        return Jalali(jalaliYear, month, day);
      }
      dayOfYear -= 186;
    } else {
      // Before Nowruz: the day is counted in the *previous* Jalali year, and a 366-day
      // previous year pushes the second half of the year out by one. The reference's `leap`
      // flag is a cycle position with a different sign convention, so the day count decides —
      // `PersianCalendar` is the contract, and the exhaustive comparison in
      // `test/core/fa_format_test.dart` is what keeps this honest.
      jalaliYear -= 1;
      dayOfYear += 179;
      if (isLeapYear(jalaliYear)) dayOfYear += 1;
    }

    month = 7 + dayOfYear ~/ 30;
    day = dayOfYear % 30 + 1;
    return Jalali(jalaliYear, month, day);
  }

  /// Converts this Jalali date back to Gregorian `(year, month, day)`.
  (int, int, int) toGregorian() {
    final gy = year + 621;
    final march = _jalCal(year).march;
    final jdn =
        _g2d(gy, 3, march) +
        (month - 1) * 31 -
        (month ~/ 7) * (month - 7) +
        day -
        1;
    return _d2g(jdn);
  }

  /// True when the Jalali year has 366 days (Esfand 30 exists).
  ///
  /// Computed from the day count between two New Year days rather than the reference's
  /// `leap` flag, whose sign convention differs between the two jalaali-js call sites.
  static bool isLeapYear(int jy) =>
      _jalaliFirstDayOfYear(jy + 1) - _jalaliFirstDayOfYear(jy) == 366;

  @override
  String toString() => '$year/$month/$day';
}

// ── The Borkowski arithmetic, kept private and literal to the reference implementation ──

const List<int> _breaks = [
  -61,
  9,
  38,
  199,
  426,
  686,
  756,
  818,
  1111,
  1181,
  1210,
  1635,
  2060,
  2097,
  2192,
  2262,
  2324,
  2394,
  2456,
  3178,
];

/// Year limits of the algorithm (the reference throws outside them; we clamp instead).
_JalCal _jalCal(int jy) {
  final bl = _breaks.length;
  final gy = jy + 621;
  var leapJ = -14;
  var jp = _breaks[0];
  var jump = 0;

  if (jy < jp || jy >= _breaks[bl - 1]) {
    throw JalaliException('Invalid Jalali year $jy.');
  }

  for (var i = 1; i < bl; i++) {
    final jm = _breaks[i];
    jump = jm - jp;
    if (jy < jm) break;
    leapJ = leapJ + (jump ~/ 33) * 8 + ((jump % 33) ~/ 4);
    jp = jm;
  }

  final n = jy - jp;
  leapJ = leapJ + (n ~/ 33) * 8 + ((n % 33) + 3) ~/ 4;
  if (jump % 33 == 4 && jump - n == 4) leapJ += 1;

  final leapG = (gy ~/ 4) - (((gy ~/ 100) + 1) * 3) ~/ 4 - 150;
  final march = 20 + leapJ - leapG;

  final leap = _mod(_mod(n + 1, 33) - 1, 4);
  return _JalCal(march: march, leap: leap == -1 ? 4 : leap);
}

class _JalCal {
  const _JalCal({required this.march, required this.leap});

  final int march;
  final int leap;
}

/// Julian day number of 1 Farvardin of [jy].
int _jalaliFirstDayOfYear(int jy) {
  final gy = jy + 621;
  return _g2d(gy, 3, _jalCal(jy).march);
}

int _g2d(int gy, int gm, int gd) {
  final base =
      (((gy + (gm - 8) ~/ 6 + 100100) * 1461) ~/ 4) +
      ((153 * _mod(gm + 9, 12) + 2) ~/ 5) +
      gd -
      34840408;
  return base - ((((gy + 100100 + (gm - 8) ~/ 6) ~/ 100) * 3) ~/ 4) + 752;
}

(int, int, int) _d2g(int jdn) {
  var j = 4 * jdn + 139361631;
  j = j + ((((4 * jdn + 183187720) ~/ 146097) * 3) ~/ 4) * 4 - 3908;
  final i = (_mod(j, 1461) ~/ 4) * 5 + 308;
  final gd = (_mod(i, 153) ~/ 5) + 1;
  final gm = _mod(i ~/ 153, 12) + 1;
  final gy = j ~/ 1461 - 100100 + (8 - gm) ~/ 6;
  return (gy, gm, gd);
}

int _mod(int a, int b) => a - (a ~/ b) * b;
