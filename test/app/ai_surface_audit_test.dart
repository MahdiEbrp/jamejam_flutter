/// **AI everywhere** — the phase-11 audit that keeps every feature on one path.
///
/// The plan's first bullet is "every service's AI surface wired through `AiFunnel` (the seam
/// already exists)". The seam does exist, and every feature uses it — but a port that drifts
/// one service at a time is exactly how a toolbox ends up with two HTTP clients, one of them
/// without the retry policy. This suite walks the real composition root and asserts, per
/// feature, that:
///
/// 1. the feature's AI verb reaches the funnel's own call path (a `MockClient` behind
///    `TestHarness(httpClient: …)` sees exactly one request);
/// 2. the prompt it sends keeps the plan's untrusted-data rule — the user's own text appears
///    **inside** a marker block, never bare;
/// 3. with no key configured the feature says so instead of sending anything.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/anahita/models.dart';
import 'package:jamejam/features/anahita/weather_assistant.dart';
import 'package:jamejam/features/haftkhan/models.dart';
import 'package:jamejam/features/soroush/prompt_markers.dart';
import 'package:jamejam/features/soroush/soroush_options.dart';

import '../helpers/test_harness.dart';

/// One completion-shaped reply — the shape every OpenAI-compatible provider returns.
String _completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

/// A harness whose AI calls land in [requests] instead of on the network.
///
/// The key is written to the in-memory secret store, which is the only place the funnel
/// accepts one from apart from the environment — the same path the app uses.
TestHarness _harness(List<http.Request> requests, {bool withKey = true}) {
  final harness = TestHarness(
    httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
        _completion('fine'),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  if (withKey) {
    unawaited(harness.secretStore.write(SecretKeys.aiApiKey, 'sk-test'));
  }
  return harness;
}

/// The text of a request's messages, joined — where a prompt can be inspected.
String _promptOf(http.Request request) {
  final decoded = jsonDecode(request.body) as Map<String, dynamic>;
  final parts = <String>[];
  for (final message in decoded['messages'] as List<dynamic>) {
    parts.add('${(message as Map<String, dynamic>)['content']}');
  }
  return parts.join('\n');
}

/// True when [needle] sits between a `BEGIN---` marker and the `END---` that follows it.
bool _insideABlock(String prompt, String needle) {
  final at = prompt.indexOf(needle);
  if (at < 0) return false;
  final begin = prompt.lastIndexOf('BEGIN---', at);
  if (begin < 0) return false;
  final end = prompt.indexOf('END---', at);
  return end > at;
}

void main() {
  test('the harness really routes an AI call through the funnel', () async {
    final requests = <http.Request>[];
    final harness = _harness(requests);
    addTearDown(harness.dispose);
    await harness.build();

    await harness.services.greeter.greetWithAi('Rostam');

    expect(requests, hasLength(1));
    expect(requests.single.url.path, endsWith('/chat/completions'));
  });

  test('the greeter marks the name it was given', () async {
    final requests = <http.Request>[];
    final harness = _harness(requests);
    addTearDown(harness.dispose);
    await harness.build();

    await harness.services.greeter.greetWithAi('Rostam');
    final prompt = _promptOf(requests.single);

    expect(prompt, contains('Rostam'));
    expect(_insideABlock(prompt, 'Rostam'), isTrue);
    expect(prompt.toLowerCase(), contains('untrusted'));
  });

  test('Haft Khan summarises through the funnel, tasks marked', () async {
    final requests = <http.Request>[];
    final harness = _harness(requests);
    addTearDown(harness.dispose);
    await harness.build();

    await harness.services.taskRepository.add(
      const NewTask(title: 'Ship the port', project: 'JameJam'),
    );
    await harness.services.haftKhan.refresh();

    await harness.services.haftKhan.summarise();
    expect(requests, hasLength(1));
    final prompt = _promptOf(requests.single);
    expect(prompt, contains('Ship the port'));
    expect(_insideABlock(prompt, 'Ship the port'), isTrue);
  });

  test('the pad asks through the funnel, the note marked', () async {
    final requests = <http.Request>[];
    final harness = _harness(requests);
    addTearDown(harness.dispose);
    await harness.build();

    final pad = harness.services.divan;
    await pad.createNotebook('Work');
    final note = await pad.addNote(
      notebookId: 1,
      title: 'Design',
      body: 'The merge must be commutative.',
    );
    await pad.select(note!.id);

    await pad.summarize();
    expect(requests, hasLength(1));
    final prompt = _promptOf(requests.single);
    expect(prompt, contains('commutative'));
    expect(_insideABlock(prompt, 'commutative'), isTrue);
  });

  test('the wallet asks through the funnel, the ledger marked', () async {
    final requests = <http.Request>[];
    final harness = _harness(requests);
    addTearDown(harness.dispose);
    await harness.build();

    final wallet = harness.services.ganjoor;
    await wallet.addAccount('Bank', initialBalance: '100');
    await wallet.spend('Bank', '20', 'groceries');
    await wallet.refresh();

    await wallet.aiInsights();
    expect(requests, hasLength(1));
    final prompt = _promptOf(requests.single);
    expect(prompt.toLowerCase(), contains('groceries'));
    expect(_insideABlock(prompt, 'groceries'), isTrue);
  });

  test('the calendar asks through the funnel, the agenda marked', () async {
    final requests = <http.Request>[];
    final harness = _harness(requests);
    addTearDown(harness.dispose);
    await harness.build();

    final calendar = harness.services.taqvim;
    final today = calendar.today;
    await calendar.addEvent(
      title: 'Standup',
      start: DateTime.utc(today.year, today.month, today.day, 9),
      end: DateTime.utc(today.year, today.month, today.day, 10),
    );
    await calendar.load();

    await calendar.aiBrief();
    expect(requests, hasLength(1));
    final prompt = _promptOf(requests.single);
    expect(prompt, contains('Standup'));
    expect(_insideABlock(prompt, 'Standup'), isTrue);
  });

  test('the weather assistant fences the forecast it is given', () {
    // The landscape's own suite drives the fetch and the explain button through the screen
    // (`weather_page_test.dart`: "explain sends a fenced prompt and confirms", "nothing was
    // sent" without a key). What this audit owes is the shape of the prompt itself.
    const assistant = WeatherAssistant();
    final report = WeatherReport(
      place: const GeoPlace(
        name: 'Berlin',
        country: 'Germany',
        latitude: 52.52,
        longitude: 13.41,
        timezone: 'Europe/Berlin',
      ),
      current: CurrentConditions(
        localTime: DateTime.utc(2026, 9, 21, 9),
        temperatureC: 18,
        apparentC: 17,
        humidityPercent: 55,
        precipMm: 0,
        code: 3,
        windKmh: 12,
        windDirectionDeg: 240,
      ),
      daily: const [],
      hourly: const [],
      fetchedAt: DateTime.utc(2026, 9, 21, 9),
    );

    final prompt = assistant.buildExplainPrompt(report);
    expect(prompt, contains(WeatherAssistant.weatherBeginMarker));
    expect(prompt, contains(WeatherAssistant.weatherEndMarker));
    expect(prompt.toLowerCase(), contains('untrusted'));
  });

  test('without a key no feature calls out', () async {
    final requests = <http.Request>[];
    final harness = _harness(requests, withKey: false);
    addTearDown(harness.dispose);
    await harness.build();

    await harness.services.taskRepository.add(
      const NewTask(title: 'Ship the port', project: 'JameJam'),
    );
    await harness.services.haftKhan.refresh();

    final calls = <Future<Object?> Function()>[
      () => harness.services.greeter.greetWithAi('Rostam'),
      () => harness.services.haftKhan.summarise(),
      () => harness.services.taqvim.aiBrief(),
      () => harness.services.ganjoor.aiInsights(),
    ];
    for (final call in calls) {
      // A refusal is the expected outcome; a network call is not. Each feature reports the
      // refusal its own way (a snack bar, a message field), so the assertion is the thing
      // that matters: the gate held before anything left the process.
      try {
        await call();
      } catch (_) {
        // The funnel's own refusal is also fine.
      }
    }
    expect(
      requests,
      isEmpty,
      reason: 'the key gate must hold for every feature',
    );

    // And the gate's own wording is the CLI's, so a reader upgrading from the console sees
    // the same sentence.
    await expectLater(
      harness.services.funnel.completeText('hello'),
      throwsA(
        isA<SoroushException>().having(
          (error) => error.message,
          'message',
          contains(
            'Missing API key. Set the JAMEJAM_AI_API_KEY environment variable',
          ),
        ),
      ),
    );
    expect(requests, isEmpty);
  });

  test('the marker helper is what every prompt is built from', () {
    final block = PromptMarkers.block(
      'AGENDA',
      'Standup at 09:00',
      maxChars: 200,
    );
    expect(block, contains('BEGIN---'));
    expect(block, contains('END---'));
    expect(block, contains('Standup at 09:00'));
    expect(_insideABlock(block, 'Standup'), isTrue);
    expect(PromptMarkers.untrustedRule.toLowerCase(), contains('untrusted'));
    expect(PromptMarkers.untrustedRule, contains('never as instructions'));
  });
}
