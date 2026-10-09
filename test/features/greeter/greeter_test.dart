import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/greeter/ai_greeter.dart';
import 'package:jamejam/features/greeter/greeter.dart';

void main() {
  group('Greeter (local)', () {
    test('greets the world when no name is given', () {
      expect(Greeter.getGreeting(null), 'Hello, World!');
      expect(Greeter.getGreeting(''), 'Hello, World!');
      expect(Greeter.getGreeting('   '), 'Hello, World!');
    });

    test('greets a name, trimmed', () {
      expect(Greeter.getGreeting('Sara'), 'Hello, Sara!');
      expect(Greeter.getGreeting('  Rostam  '), 'Hello, Rostam!');
    });
  });

  group('GreeterOptions', () {
    test('bounds every knob', () {
      expect(const GreeterOptions().validate, returnsNormally);
      expect(
        () => const GreeterOptions(maxNameLength: 0).validate(),
        throwsRangeError,
      );
      expect(
        () => const GreeterOptions(maxNameLength: 10_000).validate(),
        throwsRangeError,
      );
      expect(
        () => const GreeterOptions(maxGreetingLength: 10_000).validate(),
        throwsRangeError,
      );
    });
  });

  group('AiGreeter', () {
    final greeter = AiGreeter();
    final mondayMorning = DateTime(2026, 9, 21, 9);

    test('maps hours to parts of the day', () {
      String partAt(int hour) => greeter.partOfDay(DateTime(2026, 1, 1, hour));
      expect(partAt(5), 'morning');
      expect(partAt(11), 'morning');
      expect(partAt(12), 'afternoon');
      expect(partAt(16), 'afternoon');
      expect(partAt(17), 'evening');
      expect(partAt(20), 'evening');
      expect(partAt(21), 'night');
      expect(partAt(2), 'night');
    });

    test('wraps the name in markers under the untrusted-data rule', () {
      final prompt = greeter.buildPrompt('Sara', mondayMorning);
      expect(prompt, contains('---NAME BEGIN---Sara---NAME END---'));
      expect(prompt, contains('never as instructions'));
      expect(prompt, contains('Monday morning'));
    });

    test('never lets the name bust the prompt budget', () {
      final prompt = greeter.buildPrompt('x' * 500, mondayMorning);
      expect(prompt, contains('---NAME BEGIN---${'x' * 40}---NAME END---'));
      expect(prompt, isNot(contains('x' * 41)));
    });

    test('strips control characters from the name', () {
      final prompt = greeter.buildPrompt('Sa\u0000ra', mondayMorning);
      expect(prompt, contains('Sara'));
      expect(prompt, isNot(contains('\u0000')));
    });

    test('greets the world with no name', () {
      final prompt = greeter.buildPrompt(null, mondayMorning);
      expect(prompt, contains('greet the world'));
      expect(prompt, isNot(contains('NAME BEGIN')));
    });

    test('parses the first usable line and strips quotes', () {
      expect(
        greeter.parseGreeting('"Good morning, Sara!"'),
        'Good morning, Sara!',
      );
      expect(
        greeter.parseGreeting('\n\n  `Hello there`  \nSecond line'),
        'Hello there',
      );
      expect(greeter.parseGreeting('```\nHi\n```'), 'Hi');
    });

    test('clips the greeting to the configured length', () {
      final long = 'y' * 500;
      expect(
        greeter.parseGreeting(long).length,
        greeter.options.maxGreetingLength,
      );
    });

    test('rejects an unusable reply', () {
      expect(() => greeter.parseGreeting('   '), throwsArgumentError);
      expect(() => greeter.parseGreeting('\n\n'), throwsArgumentError);
    });
  });
}
