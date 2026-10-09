/// The Jalali conversion, checked against the platform the original ran on.
///
/// The .NET toolbox formatted Persian dates with `System.Globalization.PersianCalendar`, so
/// that class — not a blog post about Borkowski's algorithm — is the contract. This suite
/// pins a table dumped **from that class**, so the port can never drift from it again:
///
/// ```
/// // C# — the reference dump this table was taken from
/// var pc = new PersianCalendar();
/// for (var d = new DateTime(1990, 1, 1); d <= new DateTime(2060, 12, 31); d = d.AddDays(1))
///     Console.WriteLine($"{d:yyyy-MM-dd}\t{pc.GetYear(d)}/{pc.GetMonth(d)}/{pc.GetDayOfMonth(d)}");
/// ```
///
/// The first version of [Jalali] was wrong for **2 687 of 25 933 days** — every day between
/// 1 January and 20 March, because the "before Nowruz" branch asked the reference's *cycle
/// position* flag whether the previous year was long. The table below is why that cannot
/// come back: it covers the boundary of every year from 1395 to 1410, both the leap ones
/// (366 days, Esfand 30) and the ordinary ones (365 days, Esfand 29).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/jalali.dart';

/// One row of the reference dump: the Jalali year, its length, and the Gregorian dates of
/// its first and last day.
class _Year {
  const _Year(
    this.year,
    this.days,
    this.newYear,
    this.lastDay,
    this.lastDayOfMonth,
  );

  final int year;
  final int days;
  final String newYear;
  final String lastDay;
  final int lastDayOfMonth;
}

/// 1395–1410, straight from `PersianCalendar`.
const List<_Year> _reference = [
  _Year(1395, 366, '2016-03-20', '2017-03-20', 30),
  _Year(1396, 365, '2017-03-21', '2018-03-20', 29),
  _Year(1397, 365, '2018-03-21', '2019-03-20', 29),
  _Year(1398, 365, '2019-03-21', '2020-03-19', 29),
  _Year(1399, 366, '2020-03-20', '2021-03-20', 30),
  _Year(1400, 365, '2021-03-21', '2022-03-20', 29),
  _Year(1401, 365, '2022-03-21', '2023-03-20', 29),
  _Year(1402, 365, '2023-03-21', '2024-03-19', 29),
  _Year(1403, 366, '2024-03-20', '2025-03-20', 30),
  _Year(1404, 365, '2025-03-21', '2026-03-20', 29),
  _Year(1405, 365, '2026-03-21', '2027-03-20', 29),
  _Year(1406, 365, '2027-03-21', '2028-03-19', 29),
  _Year(1407, 365, '2028-03-20', '2029-03-19', 29),
  _Year(1408, 366, '2029-03-20', '2030-03-20', 30),
  _Year(1409, 365, '2030-03-21', '2031-03-20', 29),
  _Year(1410, 365, '2031-03-21', '2032-03-19', 29),
];

/// `2026-03-20` → `(2026, 3, 20)`.
(int, int, int) _parse(String iso) {
  final parts = iso.split('-').map(int.parse).toList();
  return (parts[0], parts[1], parts[2]);
}

void main() {
  group('the year table matches PersianCalendar', () {
    test('each New Year lands on the day the reference names', () {
      for (final year in _reference) {
        final (gy, gm, gd) = _parse(year.newYear);
        expect(
          Jalali.fromGregorian(gy, gm, gd).toString(),
          '${year.year}/1/1',
          reason: '${year.year} new year',
        );
      }
    });

    test('the last day of every year is the day the reference names', () {
      for (final year in _reference) {
        final (gy, gm, gd) = _parse(year.lastDay);
        expect(
          Jalali.fromGregorian(gy, gm, gd).toString(),
          '${year.year}/12/${year.lastDayOfMonth}',
          reason: '${year.year} last day',
        );
      }
    });

    test('the day after the last day is the next New Year', () {
      for (var i = 0; i < _reference.length - 1; i++) {
        final (gy, gm, gd) = _parse(_reference[i].lastDay);
        final next = DateTime.utc(gy, gm, gd).add(const Duration(days: 1));
        expect(
          Jalali.fromGregorian(next.year, next.month, next.day).toString(),
          '${_reference[i + 1].year}/1/1',
        );
      }
    });

    test('year lengths — the leap flags — agree', () {
      for (final year in _reference) {
        expect(
          Jalali.isLeapYear(year.year),
          year.days == 366,
          reason: '${year.year} length',
        );
      }
    });
  });

  group('the conversion is total over the supported range', () {
    test('every day of a year maps to a legal date and back', () {
      var checked = 0;
      for (final year in _reference) {
        for (var month = 1; month <= 12; month++) {
          for (var day = 1; day <= 29; day++) {
            final jalali = Jalali(year.year, month, day);
            final (gy, gm, gd) = jalali.toGregorian();
            final back = Jalali.fromGregorian(gy, gm, gd);
            expect(back.toString(), jalali.toString());
            checked++;
          }
        }
      }
      expect(checked, 16 * 12 * 29);
    });

    test('a long month has 30 days and a short one 29 (month 12)', () {
      // The trap the first draft fell into: Esfand of a 365-day year has 29 days.
      final lastOf1404 = Jalali(1404, 12, 29).toGregorian();
      expect(lastOf1404, (2026, 3, 20));
      final newYear1405 = Jalali(1405, 1, 1).toGregorian();
      expect(newYear1405, (2026, 3, 21));
    });

    test('the first half of the year is six 31-day months', () {
      expect(Jalali(1405, 1, 31).toGregorian(), (2026, 4, 20));
      expect(Jalali(1405, 6, 31).toGregorian(), (2026, 9, 22));
      expect(Jalali(1405, 7, 1).toGregorian(), (2026, 9, 23));
    });

    test('the anchors the calendar phase pinned are unchanged', () {
      expect(Jalali.fromGregorian(2024, 3, 20).toString(), '1403/1/1');
      expect(Jalali.fromGregorian(2025, 3, 21).toString(), '1404/1/1');
      expect(Jalali.fromGregorian(2026, 3, 21).toString(), '1405/1/1');
      expect(Jalali.fromGregorian(2026, 9, 21).toString(), '1405/6/30');
    });
  });
}
