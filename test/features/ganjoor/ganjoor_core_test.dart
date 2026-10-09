import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/ganjoor/ganjoor_defaults.dart';
import 'package:jamejam/features/ganjoor/ganjoor_options.dart';
import 'package:jamejam/features/ganjoor/models.dart';
import 'package:jamejam/features/ganjoor/money.dart';
import 'package:jamejam/features/ganjoor/money_guard.dart';

/// Port of `tests/JameJam.Tests/Ganjoor/GanjoorCoreTests.cs`
/// (`GanjoorOptionsTests` + `MoneyGuardTests`, 41 cases).
void main() {
  group('GanjoorOptionsTests', () {
    void rejects(GanjoorOptions options, String messagePart) {
      final exception = _throwsGanjoor(options.validate);
      expect(exception.message, contains(messagePart));
    }

    test('Defaults_AreValid', () {
      expect(() => const GanjoorOptions().validate(), returnsNormally);
    });

    for (final code in ['US', 'USDD', 'US1', '']) {
      test('DefaultCurrency_MustBeACurrencyCode($code)', () {
        rejects(
          GanjoorOptions(defaultCurrency: code),
          'Default currency is invalid',
        );
      });
    }

    for (final max in ['0.001', '1000000000001']) {
      test('MaxAmount_HasRails($max)', () {
        rejects(
          GanjoorOptions(maxAmount: Money.parse(max)),
          'MaxAmount must be',
        );
      });
    }

    for (final depth in [-1, 101]) {
      test('UndoDepth_HasRails($depth)', () {
        rejects(GanjoorOptions(undoDepth: depth), 'UndoDepth must be');
      });
    }

    for (final max in [0, 1001]) {
      test('MaxAccounts_HasRails($max)', () {
        rejects(GanjoorOptions(maxAccounts: max), 'MaxAccounts must be');
      });
    }

    for (final rows in [0, 50001]) {
      test('MaxImportRows_HasRails($rows)', () {
        rejects(GanjoorOptions(maxImportRows: rows), 'MaxImportRows must be');
      });
    }

    test('Rates_MustBeValidCurrencies_WithPositiveValues', () {
      rejects(
        GanjoorOptions(rates: {'EURO': Money.parse('1')}),
        'Currency must be a 3-letter code',
      );
      rejects(
        GanjoorOptions(rates: {'EUR': Money.zero}),
        'Rate for EUR must be between 0 and',
      );
    });

    test('ValidRates_Pass', () {
      final options = GanjoorOptions(rates: {'EUR': Money.parse('1.08')});
      expect(options.validate, returnsNormally);
    });

    test('rate lookup is case-insensitive and base converts as identity', () {
      final options = GanjoorOptions(rates: {'EUR': Money.parse('1.08')});
      expect(options.rateFor('eur'), Money.parse('1.08'));
      expect(options.rateFor('GBP'), isNull);
    });

    test('defaults carry the documented rails', () {
      const options = GanjoorOptions();
      expect(options.defaultCurrency, 'USD');
      expect(options.maxAmount, GanjoorDefaults.maxAmount);
      expect(options.undoDepth, 20);
      expect(options.maxAccounts, 50);
      expect(options.maxImportRows, 5000);
    });
  });

  group('MoneyGuardTests', () {
    test('Amount_ParsesPositiveValues', () {
      expect(
        MoneyGuard.amount('42.5', GanjoorDefaults.maxAmount),
        Money.parse('42.50'),
      );
      expect(
        MoneyGuard.amount('0.01', GanjoorDefaults.maxAmount),
        Money.parse('0.01'),
      );
      expect(
        MoneyGuard.amount('1,234.5', GanjoorDefaults.maxAmount),
        Money.parse('1234.50'),
      );
    });

    for (final text in ['0', '-5', 'abc', '2000000']) {
      test('Amount_RejectsJunk_AndRailViolations($text)', () {
        expect(
          () => MoneyGuard.amount(text, Money.parse('1000000')),
          throwsArgumentError,
        );
      });
    }

    test('Currency_Normalizes', () {
      expect(MoneyGuard.currency('usd'), 'USD');
      expect(MoneyGuard.currency(' Eur '), 'EUR');
    });

    for (final code in ['US', 'USDD', '12A', '', null]) {
      test('Currency_RejectsBadCodes($code)', () {
        expect(() => MoneyGuard.currency(code), throwsArgumentError);
      });
    }

    test('Tags_SplitTrimDedup_AndRespectTheCount', () {
      final tags = MoneyGuard.tags(' Food, food , drinks ,, ', 5);
      expect(tags, ['Food', 'drinks']);
      expect(() => MoneyGuard.tags('a,b,c,d,e,f', 5), throwsArgumentError);
    });

    test('Dates_AndMonths_AreStrict', () {
      expect(MoneyGuard.date('2026-09-19').toIso(), '2026-09-19');
      expect(() => MoneyGuard.date('19-09-2026'), throwsArgumentError);
      expect(() => MoneyGuard.date('not-a-date'), throwsArgumentError);
      expect(MoneyGuard.month('2026-09').toIso(), '2026-09-01');
      expect(() => MoneyGuard.month('2026-9'), throwsArgumentError);
    });

    test('Kind_ParsesAliases', () {
      expect(MoneyGuard.kind('income'), GanjoorTxKind.income);
      expect(MoneyGuard.kind('in'), GanjoorTxKind.income);
      expect(MoneyGuard.kind(' SPEND '), GanjoorTxKind.expense);
      expect(MoneyGuard.kind('transfer'), GanjoorTxKind.transfer);
    });

    test('Kind_RejectsUnknown', () {
      expect(() => MoneyGuard.kind('barter'), throwsArgumentError);
    });

    test('Frequency_Parses', () {
      expect(MoneyGuard.frequency('daily'), GanjoorFrequency.daily);
      expect(MoneyGuard.frequency('yearly'), GanjoorFrequency.yearly);
    });

    test('Frequency_RejectsUnknown', () {
      expect(() => MoneyGuard.frequency('whenever'), throwsArgumentError);
    });

    test('Id_RequiresPositiveNumbers', () {
      expect(MoneyGuard.id('7', 'Thing'), 7);
      expect(() => MoneyGuard.id('0', 'Thing'), throwsArgumentError);
      expect(() => MoneyGuard.id('-2', 'Thing'), throwsArgumentError);
      expect(() => MoneyGuard.id('many', 'Thing'), throwsArgumentError);
    });

    test('Money_FormatsInvariantly', () {
      expect(Money.parse('1234.5').formatWith('USD'), '1,234.50 USD');
      expect(Money.parse('0.07').formatAmount(), '0.07');
    });

    test('storage spelling is plain decimals', () {
      expect(Money.parse('1234.5').toStorage(), '1234.50');
      expect(Money.fromStorage('1234.50'), Money.parse('1234.5'));
    });
  });
}

/// Runs [action] and returns the [GanjoorException] it must throw.
GanjoorException _throwsGanjoor(void Function() action) {
  try {
    action();
  } on GanjoorException catch (error) {
    return error;
  }
  fail('Expected a GanjoorException.');
}
