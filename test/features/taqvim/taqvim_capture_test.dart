/// Parity suite for [TaqvimCapture] — mirrors
/// `tests/JameJam.Tests/Taqvim/TaqvimCaptureTests.cs`: dates, times, durations, tags,
/// locations and the safe fallbacks (never invent a time).
///
/// One recorded divergence: .NET took a `TimeZoneInfo` argument, the Dart port works in UTC
/// (see `docs/TEST_PARITY.md` §5), so the assertions below are all UTC instants.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/taqvim/taqvim_capture.dart';
import 'package:jamejam/features/taqvim/taqvim_defaults.dart';

/// Sunday 2026-09-20, 12:00 UTC.
final _now = DateTime.utc(2026, 9, 20, 12);

void main() {
  CaptureResult? parse(String sentence) =>
      TaqvimCapture.tryParse(sentence, _now);

  group('capture parity', () {
    test('null or whitespace returns null', () {
      expect(TaqvimCapture.tryParse('', _now), isNull);
      expect(TaqvimCapture.tryParse('   ', _now), isNull);
    });

    test('no signal returns null so nothing is invented', () {
      expect(parse('write the report'), isNull);
      expect(parse('buy oat milk sometime'), isNull);
    });

    test('"lunch with Sara next Tuesday at 1pm"', () {
      final result = parse('lunch with Sara next Tuesday at 1pm')!;
      expect(result.title, 'lunch with Sara');
      // Next week's Tuesday.
      expect(result.start, DateTime.utc(2026, 9, 29, 13));
      expect(
        result.end.difference(result.start),
        Duration(minutes: TaqvimDefaults.defaultEventMinutes),
      );
      expect(result.isAllDay, isFalse);
    });

    test('a bare weekday means the soonest future', () {
      final result = parse('dentist friday at 3')!;
      // Bare small hour → afternoon.
      expect(result.start, DateTime.utc(2026, 9, 25, 15));
    });

    test('today and tomorrow', () {
      expect(
        parse('standup today at 9:30')!.start,
        DateTime.utc(2026, 9, 20, 9, 30),
      );
      expect(
        parse('standup tomorrow at 9:30')!.start,
        DateTime.utc(2026, 9, 21, 9, 30),
      );
    });

    test('iso date with clock', () {
      final result = parse('review 2026-12-01 14:00')!;
      expect(result.start, DateTime.utc(2026, 12, 1, 14));
      expect(result.title, 'review');
    });

    test('month day rolls to next year when past', () {
      final result = parse('trip to Shiraz on March 21')!;
      expect(result.start, DateTime.utc(2027, 3, 21));
      expect(result.isAllDay, isTrue);
      expect(result.title, 'trip to Shiraz');
    });

    test('month day stays this year when future', () {
      expect(
        parse('checkup on Dec 5 at 10:00')!.start,
        DateTime.utc(2026, 12, 5, 10),
      );
    });

    test('am and pm both ways', () {
      expect(parse('run at 7am')!.start, DateTime.utc(2026, 9, 20, 7));
      expect(parse('gym at 6pm')!.start, DateTime.utc(2026, 9, 20, 18));
    });

    test('noon and midnight', () {
      expect(
        parse('lunch meeting at noon')!.start,
        DateTime.utc(2026, 9, 20, 12),
      );
      expect(parse('deploy at midnight')!.start, DateTime.utc(2026, 9, 20));
    });

    test('duration words', () {
      final result = parse('yoga tomorrow at 6pm for 75m')!;
      expect(result.end.difference(result.start), const Duration(minutes: 75));
    });

    test('duration hours', () {
      final result = parse('workshop Friday for 2 hours at 2pm')!;
      expect(result.end.difference(result.start), const Duration(hours: 2));
    });

    test('tags are harvested', () {
      final result = parse('lunch with Sara tomorrow at noon #friends #food')!;
      expect(result.tags, 'friends,food');
      expect(result.title, isNot(contains('#')));
    });

    test('location from capitalized words', () {
      final result = parse('lunch at Cafe Riviera tomorrow at 1pm')!;
      expect(result.location, 'Cafe Riviera');
      expect(result.title, 'lunch');
    });

    test('location from an @handle', () {
      expect(parse('standup @studio tomorrow at 9am')!.location, 'studio');
    });

    test('a lowercase place stays in the title', () {
      final result = parse('picnic in the park tomorrow at noon')!;
      expect(result.location, isNull);
      expect(result.title, contains('park'));
    });

    test('all-day when only a date is given', () {
      final result = parse('Nowruz holiday 2027-03-21')!;
      expect(result.isAllDay, isTrue);
      expect(result.end, result.start.add(const Duration(days: 1)));
    });

    test('a time with no title gets a default title', () {
      expect(parse('at 3pm')!.title, 'Event');
    });

    test('weekday words do not match inside other words', () {
      // "monitor" must not read as Monday — and "for 10 minutes" alone is no date either.
      expect(parse('monitor the build for 10 minutes'), isNull);
    });

    test('an invalid clock returns null', () {
      expect(parse('meet at 25:99'), isNull);
      expect(parse('meet at 99pm'), isNull);
    });

    test('bare nine reads morning, bare three reads afternoon', () {
      expect(parse('call at 9')!.start.hour, 9);
      expect(parse('call at 3')!.start.hour, 15);
      expect(parse('call at 11')!.start.hour, 11);
    });

    test('midnight hour is twelve am', () {
      expect(parse('silent retreat at 12am')!.start.hour, 0);
    });

    test('twelve pm is noon', () {
      expect(parse('board lunch at 12pm')!.start.hour, 12);
    });

    test('saturday and sunday words', () {
      final result = parse('football on sunday at 5pm')!;
      expect(result.start.weekday, DateTime.sunday);
      expect(result.start.hour, 17);
      expect(result.title, 'football');
    });

    test('an empty title falls back to the date', () {
      final result = parse('2027-01-05')!;
      expect(result.title, '2027-01-05');
      expect(result.isAllDay, isTrue);
    });

    test('a bare day number is read as pm', () {
      // The Dart-only sweep: 4 → 16, 7 → 19 (the same rule the C# bare-hour test pins for 3).
      expect(parse('call at 4')!.start.hour, 16);
      expect(parse('call at 7')!.start.hour, 19);
    });

    test('a bare hour after noon stays where it lands', () {
      final result = parse('call tomorrow at 4')!;
      expect(result.start, DateTime.utc(2026, 9, 21, 16));
    });
  });
}
