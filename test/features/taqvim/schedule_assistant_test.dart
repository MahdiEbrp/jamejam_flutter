/// Parity suite for [ScheduleAssistant] — mirrors
/// `tests/JameJam.Tests/Taqvim/ScheduleAssistantTests.cs`: bounded, marker-guarded prompts and
/// defensive reply parsing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/taqvim/models.dart';
import 'package:jamejam/features/taqvim/schedule_assistant.dart';
import 'package:jamejam/features/taqvim/taqvim_defaults.dart';
import 'package:jamejam/features/taqvim/taqvim_options.dart';

final _now = DateTime.utc(2026, 9, 20, 12);

void main() {
  Occurrence occ(
    String title,
    String start,
    String end, {
    String location = '',
    String notes = '',
    String calendar = 'Work',
  }) {
    final from = DateTime.parse(start);
    final to = DateTime.parse(end);
    return Occurrence(
      event: TaqvimEvent(
        id: 1,
        calendar: calendar,
        title: title,
        location: location,
        notes: notes,
        tags: '',
        start: from,
        end: to,
        isAllDay: false,
        rule: null,
        reminders: const [],
        createdAt: _now,
        updatedAt: _now,
        syncId: '',
      ),
      start: from,
      end: to,
    );
  }

  group('schedule assistant parity', () {
    test(
      'the brief prompt carries the day, the markers and the untrusted rule',
      () {
        final assistant = ScheduleAssistant();
        final prompt = assistant.buildBriefPrompt([
          occ('Lunch', '2026-09-20T12:00:00Z', '2026-09-20T13:00:00Z'),
        ], _now);
        expect(prompt, contains('---EVENT BEGIN---'));
        expect(prompt, contains('---EVENT END---'));
        expect(prompt, contains('UNTRUSTED USER DATA'));
        expect(prompt, contains('Lunch'));
        expect(prompt, contains('2026'));
      },
    );

    test('the plan prompt includes the free windows', () {
      final assistant = ScheduleAssistant();
      final prompt = assistant.buildPlanPrompt(
        [occ('Deep work', '2026-09-21T09:00:00Z', '2026-09-21T11:00:00Z')],
        const ['Mon 13:00-15:00 (120 min free)'],
      );
      expect(prompt, contains('Mon 13:00-15:00'));
      expect(prompt, contains('Deep work'));
    });

    test('the plan prompt honors the event rail', () {
      final assistant = ScheduleAssistant(const TaqvimOptions(maxAiEvents: 3));
      final many = [
        for (var i = 0; i < 10; i++)
          occ(
            'Event $i',
            '2026-09-21T0${i % 9}:00:00Z',
            '2026-09-21T0${i % 9}:30:00Z',
          ),
      ];
      final prompt = assistant.buildPlanPrompt(many, const []);
      expect(prompt, isNot(contains('Event 5'))); // clipped at 3
    });

    test('the ask prompt embeds the question and the context', () {
      final assistant = ScheduleAssistant();
      final prompt = assistant.buildAskPrompt('when is my next free hour?', [
        occ('Lunch', '2026-09-21T12:00:00Z', '2026-09-21T13:00:00Z'),
      ]);
      expect(prompt, contains('when is my next free hour?'));
      expect(prompt, contains('Lunch'));
      expect(prompt, contains('ONLY the events below'));
    });

    test('an empty question throws', () {
      expect(
        () => ScheduleAssistant().buildAskPrompt('  ', const []),
        throwsA(isA<TaqvimException>()),
      );
    });

    test('long questions are clipped', () {
      final prompt = ScheduleAssistant().buildAskPrompt('x' * 999, const []);
      expect(prompt.length, lessThan(1200));
    });

    test('the capture prompt carries the sentence and the template', () {
      final prompt = ScheduleAssistant.buildCapturePrompt(
        'lunch with Sara tuesday noon',
        _now,
      );
      expect(prompt, contains('lunch with Sara tuesday noon'));
      expect(prompt, contains('taqvim add'));
      expect(prompt, contains('UNTRUSTED'));
    });

    test('long capture sentences are clipped', () {
      final prompt = ScheduleAssistant.buildCapturePrompt('y' * 900, _now);
      expect(prompt.length, lessThan(1200));
    });

    test('parse capture accepts a bare command line', () {
      expect(
        ScheduleAssistant.parseCapture(
          'taqvim add Lunch --at 2026-09-22 12:00',
        ),
        'taqvim add Lunch --at 2026-09-22 12:00',
      );
    });

    test('parse capture unwraps a backticked command line', () {
      expect(
        ScheduleAssistant.parseCapture(
          '`JameJam taqvim add Standup --at 2026-09-22 09:00 --dur 15m`',
        ),
        'JameJam taqvim add Standup --at 2026-09-22 09:00 --dur 15m',
      );
    });

    test('parse capture picks the command line out of chatter', () {
      const reply =
          'Sure! Here is what you asked for:\n'
          'taqvim add Gym --at 2026-09-22 18:00\n'
          'Hope that helps!';
      expect(
        ScheduleAssistant.parseCapture(reply),
        'taqvim add Gym --at 2026-09-22 18:00',
      );
    });

    test('parse capture rejects overlong commands', () {
      expect(ScheduleAssistant.parseCapture('taqvim add ${'a' * 600}'), isNull);
    });

    for (final reply in [
      '',
      'no command here at all',
      'taqvim remove everything',
    ]) {
      test('parse capture rejects non-commands [$reply]', () {
        expect(ScheduleAssistant.parseCapture(reply), isNull);
      });
    }

    test('notes are clipped into the prompt', () {
      final occurrence = occ(
        'With notes',
        '2026-09-21T09:00:00Z',
        '2026-09-21T10:00:00Z',
        notes: 'n' * 20000,
      );
      final prompt = ScheduleAssistant().buildBriefPrompt([occurrence], _now);
      expect(prompt.length, lessThan(10000));
    });

    test('the options are validated at construction', () {
      expect(
        () => ScheduleAssistant(const TaqvimOptions(maxEvents: 0)),
        throwsA(isA<TaqvimException>()),
      );
    });
  });
}
