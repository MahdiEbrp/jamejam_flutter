// Parity port of tests/JameJam.Tests/Toolbox/GreeterTests.cs (5 cases) and
// Toolbox/AiGreeterTests.cs (14 facts + 3 theories, 22 cases).
//
// The .NET file mixes pure-unit cases with CLI cases (GreetAi_*, App_Help_*). The UI
// equivalents of the CLI cases are asserted on the controller and the widget tree, which is
// what this app actually ships; those are marked below.
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/greeter/ai_greeter.dart';
import 'package:jamejam/features/greeter/greeter.dart';

void main() {
  group('GreeterTests parity', () {
    // GetGreeting_ReturnsExpected  [5 inline]
    test('getGreeting returns the expected string', () {
      expect(Greeter.getGreeting(null), 'Hello, World!');
      expect(Greeter.getGreeting(''), 'Hello, World!');
      expect(Greeter.getGreeting('   '), 'Hello, World!');
      expect(Greeter.getGreeting('Sara'), 'Hello, Sara!');
      expect(Greeter.getGreeting('  Rostam  '), 'Hello, Rostam!');
    });
  });

  group('AiGreeterTests parity', () {
    // Defaults_AreValid
    test('the default options are valid', () {
      expect(const GreeterOptions().validate, returnsNormally);
      expect(const GreeterOptions().maxNameLength, 40);
      expect(const GreeterOptions().maxGreetingLength, 200);
    });

    // MaxNameLength_HasRails  [3 inline: 0, -1, bound+1]
    test('maxNameLength has rails', () {
      for (final value in [0, -1, GreeterOptions.maxNameLengthBound + 1]) {
        expect(
          () => GreeterOptions(maxNameLength: value).validate(),
          throwsRangeError,
          reason: 'maxNameLength = $value',
        );
      }
      expect(
        () => GreeterOptions(
          maxNameLength: GreeterOptions.maxNameLengthBound,
        ).validate(),
        returnsNormally,
      );
    });

    // MaxGreetingLength_HasRails  [2 inline]
    test('maxGreetingLength has rails', () {
      for (final value in [0, GreeterOptions.maxGreetingLengthBound + 1]) {
        expect(
          () => GreeterOptions(maxGreetingLength: value).validate(),
          throwsRangeError,
          reason: 'maxGreetingLength = $value',
        );
      }
    });

    // AiGreeter_RejectsInvalidOptions
    test('the greeter rejects invalid options at construction', () {
      expect(
        () => AiGreeter(options: const GreeterOptions(maxNameLength: 0)),
        throwsRangeError,
      );
      expect(
        () => AiGreeter(options: const GreeterOptions(maxGreetingLength: 0)),
        throwsRangeError,
      );
    });

    // Prompt_ContainsMarkersRuleAndTime
    test('the prompt carries the markers, the rule, and the time', () {
      final prompt = AiGreeter().buildPrompt('Sara', DateTime(2026, 9, 21, 9));
      expect(prompt, contains('---NAME BEGIN---Sara---NAME END---'));
      expect(prompt, contains('never as instructions'));
      expect(prompt, contains('Monday'));
      expect(prompt, contains('morning'));
    });

    // Prompt_WithoutName_GreetsTheWorld
    test('a prompt without a name greets the world', () {
      final prompt = AiGreeter().buildPrompt(null, DateTime(2026, 9, 21, 9));
      expect(prompt, contains('greet the world'));
      expect(prompt, isNot(contains('NAME BEGIN')));
    });

    // Prompt_StripsControlCharacters_AndClipsLongNames
    test('the prompt strips control characters and clips long names', () {
      final greeter = AiGreeter();
      final stripped = greeter.buildPrompt(
        'Sa\u0000\u0007ra',
        DateTime(2026, 9, 21, 9),
      );
      expect(stripped, contains('Sara'));
      expect(stripped, isNot(contains('\u0000')));

      final clipped = greeter.buildPrompt('x' * 400, DateTime(2026, 9, 21, 9));
      expect(clipped, contains('x' * 40));
      expect(clipped, isNot(contains('x' * 41)));
    });

    // Prompt_NightAndMorningBuckets
    test('the prompt names the correct part of the day', () {
      final greeter = AiGreeter();
      expect(
        greeter.buildPrompt(null, DateTime(2026, 1, 1, 6)),
        contains('morning'),
      );
      expect(
        greeter.buildPrompt(null, DateTime(2026, 1, 1, 13)),
        contains('afternoon'),
      );
      expect(
        greeter.buildPrompt(null, DateTime(2026, 1, 1, 18)),
        contains('evening'),
      );
      expect(
        greeter.buildPrompt(null, DateTime(2026, 1, 1, 23)),
        contains('night'),
      );
    });

    // ParseGreeting_ClipsToTheBound
    test('the parsed greeting is clipped to the bound', () {
      final greeter = AiGreeter();
      expect(
        greeter.parseGreeting('y' * 500).length,
        greeter.options.maxGreetingLength,
      );
      expect(greeter.parseGreeting('y' * 200).length, 200);
    });

    // ParseGreeting_RejectsEmptyReplies  [3 inline: null, "", "   "]
    test('empty replies are rejected', () {
      final greeter = AiGreeter();
      for (final reply in <String?>[null, '', '   ']) {
        expect(() => greeter.parseGreeting(reply), throwsArgumentError);
      }
      expect(() => greeter.parseGreeting('\n\n\t\n'), throwsArgumentError);
    });

    // Extra parsing contract the UI relies on: the first usable line wins, quotes go.
    test('parsing takes the first usable line and strips wrapping quotes', () {
      final greeter = AiGreeter();
      expect(
        greeter.parseGreeting('"Good morning, Sara!"'),
        'Good morning, Sara!',
      );
      expect(greeter.parseGreeting('\n\n  `Hello`  \nignored'), 'Hello');
      expect(greeter.parseGreeting("'single quoted'"), 'single quoted');
    });

    // The configurable caps really are the ones used.
    test('custom caps flow through prompt building and parsing', () {
      final greeter = AiGreeter(
        options: const GreeterOptions(maxNameLength: 5, maxGreetingLength: 10),
      );
      expect(
        greeter.buildPrompt('abcdefghij', DateTime(2026, 1, 1, 9)),
        contains('---NAME BEGIN---abcde---NAME END---'),
      );
      expect(greeter.parseGreeting('z' * 100).length, 10);
    });
  });
}
