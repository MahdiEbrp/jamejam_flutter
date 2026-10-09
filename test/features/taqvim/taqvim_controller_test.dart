/// Controller suite for Taqvim — the `taqvim` CLI verbs as callable state, mirroring
/// `tests/JameJam.Tests/Taqvim/TaqvimCommandsTests.cs` and `TaqvimCliGapTests.cs`.
///
/// Mapping, verb by verb: `add|edit|reschedule|repeat|remind|delete` → the mutation methods,
/// `today|tomorrow|week|month|list --scope upcoming` → [TaqvimScope], `list --calendar/--tag`
/// → [TaqvimController.setFilters], `search` → [TaqvimController.search], `free` →
/// [TaqvimController.computeFreeSlots], `export|import` → [TaqvimController.exportIcs] /
/// [TaqvimController.importIcs], `undo` → [TaqvimController.undo], `capture` →
/// [TaqvimController.capture], and `ai brief|plan|ask|capture` → the AI methods.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/settings/memory_settings_store.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/settings/settings_controller.dart';
import 'package:jamejam/features/soroush/ai_funnel.dart';
import 'package:jamejam/features/taqvim/models.dart';
import 'package:jamejam/features/taqvim/taqvim_controller.dart';
import 'package:jamejam/features/taqvim/taqvim_defaults.dart';
import 'package:jamejam/features/taqvim/taqvim_service.dart';
import 'package:jamejam/features/taqvim/taqvim_store.dart';

/// 2026-09-21T09:00:00Z — a Monday, the clock every case is measured against.
final _now = DateTime.utc(2026, 9, 21, 9);

/// The OpenAI-shaped completion the funnel reads.
String _completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

void main() {
  late MemoryTaqvimStore store;
  late TaqvimService service;
  late TaqvimController controller;

  Future<TaqvimController> build({
    bool withFunnel = false,
    String aiReply = 'done',
    Future<List<String>> Function()? dueTasks,
    SettingsController? settings,
  }) async {
    store = MemoryTaqvimStore();
    service = TaqvimService(store: store, clock: () => _now);
    final settingsController =
        settings ?? SettingsController(MemorySettingsStore());
    if (settings == null) await settingsController.load();
    controller = TaqvimController(
      service: service,
      settings: settingsController,
      funnel: withFunnel
          ? AiFunnel(
              settings: settingsController,
              secrets: await _seededSecrets(),
              httpClient: MockClient(
                (_) async => http.Response(_completion(aiReply), 200),
              ),
            )
          : null,
      dueTasks: dueTasks,
      clock: () => _now,
    );
    await controller.load();
    return controller;
  }

  Future<TaqvimEvent?> add({
    String title = 'Lunch',
    String start = '2026-09-21T12:00:00Z',
    String end = '2026-09-21T13:00:00Z',
    String tags = '',
    String? calendar,
    Recurrence? rule,
    List<int>? reminders,
    bool allDay = false,
  }) => controller.addEvent(
    title: title,
    start: DateTime.parse(start),
    end: DateTime.parse(end),
    tags: tags,
    calendar: calendar,
    rule: rule,
    reminders: reminders,
    allDay: allDay,
  );

  group('TaqvimController — loading and scopes', () {
    test('load fills the day agenda and the counters', () async {
      await build();
      await add();
      await controller.load();

      expect(controller.events, hasLength(1));
      expect(controller.agenda, hasLength(1));
      expect(controller.stats!.events, 1);
      expect(controller.today, const DateOnly(2026, 9, 21));
      expect(controller.undoAvailable, isTrue); // the add pushed a snapshot
    });

    test('the scope picks the window: today, tomorrow, week, month', () async {
      await build();
      await add(title: 'Today', tags: 'work');
      await add(
        title: 'Tomorrow',
        start: '2026-09-22T12:00:00Z',
        end: '2026-09-22T13:00:00Z',
      );
      await add(
        title: 'Sunday',
        start: '2026-09-27T12:00:00Z',
        end: '2026-09-27T13:00:00Z',
      );
      await add(
        title: 'Next month',
        start: '2026-10-02T12:00:00Z',
        end: '2026-10-02T13:00:00Z',
      );

      await controller.setScope(TaqvimScope.today);
      expect(controller.agenda.map((o) => o.event.title), ['Today']);

      await controller.setScope(TaqvimScope.tomorrow);
      expect(controller.agenda.map((o) => o.event.title), ['Tomorrow']);

      // Monday-anchored: Mon 21 – Sun 27.
      await controller.setScope(TaqvimScope.week);
      expect(controller.agenda, hasLength(3));

      await controller.setScope(TaqvimScope.month);
      expect(
        controller.agenda,
        hasLength(3),
      ); // October's event is out of September

      await controller.setScope(TaqvimScope.upcoming);
      expect(controller.agenda, hasLength(4));
    });

    test('shifting the anchor moves the today scope', () async {
      await build();
      await add(
        title: 'Tomorrow',
        start: '2026-09-22T12:00:00Z',
        end: '2026-09-22T13:00:00Z',
      );
      await controller.shiftDays(1);
      expect(controller.anchor, const DateOnly(2026, 9, 22));
      expect(controller.agenda.map((o) => o.event.title), ['Tomorrow']);
      await controller.shiftDays(-1);
      expect(controller.agenda, isEmpty);
    });

    test('the calendar and tag filters narrow the agenda', () async {
      await build();
      await add(title: 'Work thing', tags: 'focus', calendar: 'Work');
      await add(
        title: 'Home thing',
        start: '2026-09-21T14:00:00Z',
        end: '2026-09-21T15:00:00Z',
        tags: 'family',
        calendar: 'Home',
      );

      await controller.setFilters(calendar: 'work'); // case-insensitive
      expect(controller.agenda.map((o) => o.event.title), ['Work thing']);

      await controller.setFilters(tag: 'family');
      expect(controller.agenda.map((o) => o.event.title), ['Home thing']);

      await controller.setFilters(calendar: '  ', tag: '');
      expect(controller.agenda, hasLength(2));
      expect(controller.scopeOccurrences, hasLength(2));
    });
  });

  group('TaqvimController — mutations', () {
    test(
      'add surfaces the rails in the message and keeps the selection',
      () async {
        await build();
        final created = await add(title: '  Yoga  ');
        expect(created, isNotNull);
        expect(created!.title, 'Yoga'); // trimmed by the service
        expect(controller.message, 'Added "Yoga".');
        expect(controller.error, isNull);
        expect(controller.selected!.id, created.id);
      },
    );

    test('a rail failure is a message, never a crash', () async {
      await build();
      final created = await controller.addEvent(
        title: 'Backwards',
        start: DateTime.parse('2026-09-21T13:00:00Z'),
        end: DateTime.parse('2026-09-21T12:00:00Z'),
      );
      expect(created, isNull);
      expect(controller.error, contains('end must be after'));
      expect(controller.events, isEmpty);
    });

    test('an empty title is refused with the pinned message', () async {
      await build();
      await add(title: '   ');
      expect(controller.error, 'An event needs a title.');
      expect(controller.events, isEmpty);
    });

    test('edit, reschedule, repeat and remind all report back', () async {
      await build();
      final created = (await add())!;

      await controller.editEvent(created.id, title: 'Lunch with Sara');
      expect(controller.selected!.title, 'Lunch with Sara');

      final moved = await controller.reschedule(
        created.id,
        DateTime.parse('2026-09-21T14:00:00Z'),
      );
      expect(moved!.start.hour, 14);
      expect(moved.end.difference(moved.start), const Duration(hours: 1));
      expect(controller.message, 'Moved "Lunch with Sara".');

      final repeated = await controller.setRule(
        created.id,
        const Recurrence(RecurrenceKind.weekly, onWeekdays: [1]),
      );
      expect(repeated!.rule!.kind, RecurrenceKind.weekly);
      expect(controller.message, contains('It repeats'));

      await controller.setRule(created.id, null);
      expect(controller.message, 'The event no longer repeats.');

      final reminded = await controller.setReminders(created.id, [30, 5]);
      expect(reminded!.reminders, [5, 30]);
      expect(controller.message, 'Reminding 5,30 minutes before.');

      await controller.setReminders(created.id, const []);
      expect(controller.message, 'Reminders cleared.');
    });

    test('delete removes the event and undo restores it', () async {
      await build();
      final created = (await add())!;

      expect(await controller.delete(created.id), isTrue);
      expect(controller.message, contains('undo restores it'));
      expect(controller.events, isEmpty);
      expect(controller.selected, isNull);

      expect(await controller.undo(), isTrue);
      expect(controller.events, hasLength(1));
      expect(controller.message, 'Undone.');
    });

    test('undo on an empty stack says so', () async {
      await build();
      expect(await controller.undo(), isFalse);
      expect(controller.message, 'Nothing left to undo.');
    });

    test('the undo flag follows the store', () async {
      await build();
      expect(controller.undoAvailable, isFalse);
      await add();
      expect(controller.undoAvailable, isTrue);
    });

    test('duplicateDraft clones the selection into a new event', () async {
      await build();
      final created = (await add(title: 'Standup'))!;
      await controller.select(created.id);

      final draft = controller.duplicateDraft()!;
      expect(draft.id, 0);
      expect(draft.syncId, isEmpty);
      expect(draft.title, 'Standup (copy)');
    });
  });

  group('TaqvimController — search and windows', () {
    test('search finds by title and notes and reports the count', () async {
      await build();
      await add(title: 'Dentist appointment');
      await add(
        title: 'Sprint planning',
        start: '2026-09-21T15:00:00Z',
        end: '2026-09-21T16:00:00Z',
      );

      await controller.search('dentist');
      expect(controller.searchResults, hasLength(1));
      expect(controller.message, '1 event(s) matched "dentist".');

      await controller.search('nothing at all');
      expect(controller.searchResults, isEmpty);
      expect(controller.message, 'Nothing matched "nothing at all".');

      await controller.search('  ');
      expect(controller.searchResults, isEmpty);
      expect(controller.error, isNull);
    });

    test('free windows are computed and reported', () async {
      await build();
      await add(
        title: 'Morning',
        start: '2026-09-21T10:00:00Z',
        end: '2026-09-21T11:30:00Z',
      );

      final slots = await controller.computeFreeSlots(
        const DateOnly(2026, 9, 21),
        const ClockTime(9, 0),
        const ClockTime(14, 0),
        60,
      );
      expect(slots, hasLength(2));
      expect(controller.freeSlots, hasLength(2));
      expect(controller.message, '2 free window(s).');

      controller.clearFreeSlots();
      expect(controller.freeSlots, isEmpty);
    });

    test('an impossible window is a message, not a crash', () async {
      await build();
      final slots = await controller.computeFreeSlots(
        const DateOnly(2026, 9, 21),
        const ClockTime(9, 0),
        const ClockTime(12, 0),
        0,
      );
      expect(slots, isEmpty);
      expect(controller.error, contains('between 1 and'));
    });
  });

  group('TaqvimController — transfer', () {
    test('.ics round-trips through the controller', () async {
      await build();
      await add(title: 'Exported', tags: 'work', reminders: [10]);

      final document = await controller.exportIcs();
      expect(document, contains('BEGIN:VEVENT'));
      expect(document, contains('SUMMARY:Exported'));

      // A second calendar imports the document.
      final other = MemoryTaqvimStore();
      final otherController = TaqvimController(
        service: TaqvimService(store: other, clock: () => _now),
        clock: () => _now,
      );
      await otherController.load();
      final imported = await otherController.importIcs(document);
      expect(imported, hasLength(1));
      expect(otherController.message, 'Imported 1 event(s).');
      expect((await other.listEvents()).single.title, 'Exported');
    });

    test('a document with nothing in it imports nothing', () async {
      await build();
      final imported = await controller.importIcs('not an ics at all');
      expect(imported, isEmpty);
      expect(controller.message, 'Imported 0 event(s).');
      expect(controller.events, isEmpty);
    });

    test('a document past the event rail is refused', () async {
      await build();
      final lines = <String>[];
      for (var i = 0; i < TaqvimDefaults.maxIcsEvents + 1; i++) {
        lines.add(
          'BEGIN:VEVENT\r\nSUMMARY:E$i\r\nDTSTART:20260921T0${i % 9}0000\r\n'
          'END:VEVENT',
        );
      }
      final document = lines.join('\r\n');
      await controller.importIcs(
        'BEGIN:VCALENDAR\r\n$document\r\nEND:VCALENDAR\r\n',
      );
      expect(controller.error, 'At most 2000 events may be imported at once.');
      expect(controller.events, isEmpty);
    });
  });

  group('TaqvimController — capture', () {
    test('a sentence with a date and time becomes an event', () async {
      await build();
      final parsed = controller.capture('lunch with Sara next Tuesday at 1pm')!;
      expect(parsed.title, 'lunch with Sara');
      expect(parsed.start, DateTime.utc(2026, 9, 29, 13));

      final created = await add(
        title: parsed.title,
        start: parsed.start.toIso8601String(),
        end: parsed.end.toIso8601String(),
        tags: parsed.tags,
        calendar: parsed.location,
      );
      expect(created!.title, 'lunch with Sara');
      expect(created.calendar, TaqvimDefaults.defaultCalendar);
    });

    test('a sentence with no signal parses to nothing', () async {
      await build();
      expect(controller.capture('write the report'), isNull);
    });
  });

  group('TaqvimController — the AI card', () {
    test('without a funnel the action says so', () async {
      await build();
      await controller.aiBrief();
      expect(controller.aiAvailable, isFalse);
      expect(controller.error, 'AI is not available in this context.');
      expect(controller.aiAnswer, isNull);
    });

    test('brief, plan and ask all reach the funnel', () async {
      await build(withFunnel: true, aiReply: 'You have one thing today.');
      await add(title: 'Lunch');

      await controller.aiBrief();
      expect(controller.aiVerb, TaqvimAiVerb.brief);
      expect(controller.aiAnswer, 'You have one thing today.');

      await controller.aiPlan();
      expect(controller.aiVerb, TaqvimAiVerb.plan);

      await controller.aiAsk('when is my next free hour?');
      expect(controller.aiVerb, TaqvimAiVerb.ask);

      controller.clearAiAnswer();
      expect(controller.aiAnswer, isNull);
      expect(controller.aiVerb, isNull);
    });

    test('capture scans the reply for the suggested command', () async {
      await build(
        withFunnel: true,
        aiReply:
            'Sure:\ntaqvim add Gym --at 2026-09-22 18:00\nHope that helps!',
      );
      await controller.aiCapture('gym tomorrow at 6pm');
      expect(controller.aiVerb, TaqvimAiVerb.capture);
      expect(controller.aiSuggestion, 'taqvim add Gym --at 2026-09-22 18:00');
    });

    test('a reply without a command leaves the suggestion empty', () async {
      await build(
        withFunnel: true,
        aiReply: 'I could not turn that into a command.',
      );
      await controller.aiCapture('something vague');
      expect(controller.aiSuggestion, isNull);
    });

    test('the plan prompt carries the open tasks from Haft Khan', () async {
      final prompts = <String>[];
      final settingsController = SettingsController(MemorySettingsStore());
      await settingsController.load();
      final captured = TaqvimController(
        service: TaqvimService(store: MemoryTaqvimStore(), clock: () => _now),
        settings: settingsController,
        funnel: AiFunnel(
          settings: settingsController,
          secrets: await _seededSecrets(),
          httpClient: MockClient((request) async {
            prompts.add(request.body);
            return http.Response(_completion('ok'), 200);
          }),
        ),
        dueTasks: () async => ['Renew the passport', 'Pay the rent'],
        clock: () => _now,
      );
      await captured.load();
      await captured.aiPlan();

      expect(prompts, hasLength(1));
      expect(prompts.single, contains('open task: Renew the passport'));
      expect(prompts.single, contains('open task: Pay the rent'));
    });
  });

  group('TaqvimController — settings', () {
    test('the sync URL comes from the settings store', () async {
      await build();
      expect(await controller.syncUrl(), isNull); // nothing saved yet

      final store2 = MemorySettingsStore();
      final settingsController = SettingsController(store2);
      await settingsController.load();
      await store2.setValue(
        SettingKeys.taqvimSyncUrl,
        ' https://example.test/t ',
      );
      final wired = await build(settings: settingsController);
      expect(await wired.syncUrl(), 'https://example.test/t');
    });
  });
}

/// A secret store holding one AI key.
///
/// The funnel refuses to call a non-loopback endpoint without a key — the .NET's
/// `CompleteAiRequestAsync` gate — so a fixture that wants a request on the wire needs a key,
/// exactly like the original's tests (`ApiKey = "test-key-1234"`).
Future<MemorySecretStore> _seededSecrets() async {
  final secrets = MemorySecretStore();
  await secrets.write(SecretKeys.aiApiKey, 'sk-test');
  return secrets;
}
