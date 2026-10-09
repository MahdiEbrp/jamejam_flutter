/// The Persian display layer — phase 11's polish item: *Persian digits where appropriate,
/// Jalali calendar display for Taqvim and due dates*.
///
/// Two rules are pinned here, and every screen that shows a number or a date depends on
/// them:
///
/// 1. **Display only.** `FaFormat` never touches a stored value, an input field or the wire,
///    so a date the reader typed stays `2026-09-21` and a sync peer still reads ASCII.
/// 2. **One conversion.** `DateOnly.format(locale: 'fa')` and the calendar's `whenLine` both
///    go through [FaFormat], so a due date in Haft Khan and an agenda row in Taqvim cannot
///    disagree about which day they are.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/core/fa_format.dart';
import 'package:jamejam/features/taqvim/models.dart';

void main() {
  group('Persian digits', () {
    test('every ASCII digit maps to its Persian counterpart', () {
      expect(FaFormat.digits('0123456789'), '۰۱۲۳۴۵۶۷۸۹');
    });

    test('non-digits survive, so mixed text keeps its shape', () {
      expect(FaFormat.digits('2026-09-21 09:00'), '۲۰۲۶-۰۹-۲۱ ۰۹:۰۰');
      expect(FaFormat.digits('earbuds #2 — Café'), 'earbuds #۲ — Café');
      expect(FaFormat.digits(''), '');
    });

    test('a URL or a file name keeps its structure', () {
      expect(
        FaFormat.digits('https://sync.example.dev/v1?page=2'),
        'https://sync.example.dev/v۱?page=۲',
      );
      expect(FaFormat.digits('taqvim-2026-09-21.ics'), 'taqvim-۲۰۲۶-۰۹-۲۱.ics');
    });

    test('accepted twins — ۹ and ۹ — are left alone', () {
      // The helper runs over *rendered* strings; Persian input must pass through unchanged.
      expect(FaFormat.digits('رکورد ۹'), 'رکورد ۹');
    });

    test('at() is identity for every non-Persian locale', () {
      expect(FaFormat.at('en', '5 events'), '5 events');
      expect(FaFormat.at(null, '5 events'), '5 events');
      expect(FaFormat.at('de-DE', '5 events'), '5 events');
    });

    test('at() switches on the language subtag, not the whole tag', () {
      expect(FaFormat.isPersian('fa'), isTrue);
      expect(FaFormat.isPersian('fa-IR'), isTrue);
      expect(FaFormat.isPersian('FA'), isTrue);
      expect(FaFormat.isPersian('en-US'), isFalse);
      expect(FaFormat.isPersian(''), isFalse);
      expect(
        FaFormat.isPersian('fao'),
        isFalse,
      ); // not a Persian tag by prefix accident
      expect(
        FaFormat.at('fa-IR', '7 in the next 7 days'),
        '۷ in the next ۷ days',
      );
    });
  });

  group('Jalali dates', () {
    test('the anchors the calendar phase pinned still hold', () {
      expect(Jalali.fromGregorian(2024, 3, 20).toString(), '1403/1/1');
      expect(Jalali.fromGregorian(2025, 3, 21).toString(), '1404/1/1');
      expect(Jalali.fromGregorian(2026, 3, 21).toString(), '1405/1/1');
      expect(Jalali.fromGregorian(2026, 9, 21).toString(), '1405/6/30');
    });

    test('the leap flag covers 1403 but not 1404', () {
      expect(Jalali.isLeapYear(1403), isTrue);
      expect(Jalali.isLeapYear(1404), isFalse);
      expect(Jalali.isLeapYear(1405), isFalse);
    });

    test(
      'the month and weekday tables are complete and in the port\'s order',
      () {
        expect(jalaliMonthsFa, hasLength(12));
        expect(jalaliMonthsFa.first, 'فروردین');
        expect(jalaliMonthsFa.last, 'اسفند');
        expect(weekdayNamesFa, hasLength(7));
        expect(weekdayNamesFa.first, 'دوشنبه'); // DateTime.weekday == 1
        expect(weekdayNamesFa.last, 'یکشنبه'); // DateTime.weekday == 7
      },
    );

    test(
      'an out-of-range year raises the core exception, not a feature one',
      () {
        expect(
          () => Jalali.fromGregorian(6600, 1, 1),
          throwsA(isA<JalaliException>()),
        );
      },
    );
  });

  group('FaFormat.date', () {
    test('en keeps the Gregorian short form', () {
      expect(FaFormat.date(const DateOnly(2026, 9, 21), 'en'), '21 Sep 2026');
      expect(FaFormat.date(const DateOnly(2026, 1, 3), null), '3 Jan 2026');
    });

    test('fa writes the Jalali day in Persian digits', () {
      expect(
        FaFormat.date(const DateOnly(2026, 9, 21), 'fa'),
        '۳۰ شهریور ۱۴۰۵',
      );
      expect(
        FaFormat.date(const DateOnly(2025, 3, 21), 'fa-IR'),
        '۱ فروردین ۱۴۰۴',
      );
    });

    test('the Jalali day rolls over the new year, not the Gregorian one', () {
      // 20 March is still 1404; the next day is 1 Farvardin 1405.
      expect(FaFormat.date(const DateOnly(2026, 3, 20), 'fa'), '۲۹ اسفند ۱۴۰۴');
      expect(
        FaFormat.date(const DateOnly(2026, 3, 21), 'fa'),
        '۱ فروردین ۱۴۰۵',
      );
    });

    test('every month of a year is named once', () {
      final seen = <String>{};
      for (var month = 1; month <= 12; month++) {
        final jalali = Jalali.fromGregorian(2026, month, 15);
        final rendered = FaFormat.date(DateOnly(2026, month, 15), 'fa');
        final name = jalaliMonthsFa[jalali.month - 1];
        expect(rendered, contains(name));
        seen.add(name);
      }
      expect(seen, hasLength(12));
    });
  });

  group('DateOnly.format', () {
    test('the English form matches the .NET display pattern', () {
      expect(const DateOnly(2026, 9, 21).format(locale: 'en'), '21 Sep 2026');
    });

    test('the Persian form is the Jalali date, not a Gregorian year', () {
      final rendered = const DateOnly(2026, 9, 21).format(locale: 'fa');
      expect(rendered, '۳۰ شهریور ۱۴۰۵');
      expect(rendered, isNot(contains('۲۰۲۶')));
    });

    test('the storage form is untouched by the display rule', () {
      expect(const DateOnly(2026, 9, 21).toIso(), '2026-09-21');
    });
  });

  group('the calendar\'s own lines', () {
    final event = TaqvimEvent(
      id: 1,
      calendar: 'Work',
      title: 'Standup',
      start: DateTime.utc(2026, 9, 21, 9),
      end: DateTime.utc(2026, 9, 21, 10),
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );
    final allDay = TaqvimEvent(
      id: 2,
      calendar: 'Personal',
      title: 'Nowruz',
      start: DateTime.utc(2026, 3, 21),
      end: DateTime.utc(2026, 3, 22),
      isAllDay: true,
      createdAt: DateTime.utc(2026, 3, 1),
      updatedAt: DateTime.utc(2026, 3, 1),
    );

    test(
      'without a locale the line is the culture-invariant one the .NET printed',
      () {
        final line = TaqvimText.whenLine(
          Occurrence(event: event, start: event.start, end: event.end),
        );
        expect(line, 'Mon 2026-09-21 09:00–10:00');
      },
    );

    test(
      'under fa the same line is Jalali, with Persian weekday and digits',
      () {
        final line = TaqvimText.whenLine(
          Occurrence(event: event, start: event.start, end: event.end),
          locale: 'fa',
        );
        expect(line, 'دوشنبه ۳۰ شهریور ۱۴۰۵ ۰۹:۰۰–۱۰:۰۰');
      },
    );

    test('the all-day marker is localized too', () {
      final occurrence = Occurrence(
        event: allDay,
        start: allDay.start,
        end: allDay.end,
      );
      expect(TaqvimText.whenLine(occurrence), contains('(all day)'));
      expect(
        TaqvimText.whenLine(occurrence, locale: 'fa'),
        'شنبه ۱ فروردین ۱۴۰۵ (تمام روز)',
      );
    });

    test(
      'a multi-day line still names the end weekday (§5 keeps the short form)',
      () {
        final overnight = Occurrence(
          event: event,
          start: DateTime.utc(2026, 9, 21, 22),
          end: DateTime.utc(2026, 9, 22, 1),
        );
        expect(
          TaqvimText.whenLine(overnight),
          'Mon 2026-09-21 22:00–Tue 01:00',
        );
        expect(
          TaqvimText.whenLine(overnight, locale: 'fa'),
          'دوشنبه ۳۰ شهریور ۱۴۰۵ ۲۲:۰۰–Tue ۰۱:۰۰',
        );
      },
    );
  });

  group('FaFormat.dateTime', () {
    test('en is the storage form', () {
      expect(
        FaFormat.dateTime(DateTime.utc(2026, 9, 21, 9, 5), 'en'),
        '2026-09-21 09:05',
      );
    });

    test('fa is the Jalali day with a Persian clock', () {
      expect(
        FaFormat.dateTime(DateTime.utc(2026, 9, 21, 9, 5), 'fa'),
        '۳۰ شهریور ۱۴۰۵ ۰۹:۰۵',
      );
    });
  });
}
