// The Persian digit sweep.
//
// The reference CLI printed invariant numerals everywhere — `#12`, `-30.00`, `3 notes`. A
// Persian reader should not see any of that: under `fa` every number the *app* formats is
// written with Persian digits, while everything the *user* typed (a note, a file name, a URL)
// stays exactly as written. These cases pin one screen per category — money, an id, a count —
// so a regression in `FaFormat.at` cannot slip back in one call site at a time.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/app/app.dart';
import 'package:jamejam/app/app_navigation.dart';
import 'package:jamejam/features/divan/divan_page.dart';
import 'package:jamejam/features/ganjoor/ganjoor_page.dart';
import 'package:jamejam/features/haftkhan/haftkhan_page.dart';
import 'package:jamejam/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../helpers/test_harness.dart';

/// Pumps [screen] in Persian, the way the shell does once the locale is `fa`.
Future<void> _pumpPersian(
  TestHarness harness,
  WidgetTester tester,
  Widget screen,
) async {
  await tester.binding.setSurfaceSize(const Size(1500, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: harness.services.providers(),
      child: MaterialApp(
        locale: const Locale('fa'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the wallet total uses Persian digits in fa', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    await harness.services.ganjoor.addAccount('بانک', initialBalance: '1234.5');

    await _pumpPersian(harness, tester, const GanjoorPage());

    final total = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .firstWhere((data) => data.contains('مجموع'));
    expect(total, contains('۱,۲۳۴.۵۰'));
    expect(
      RegExp(r'\d').hasMatch(total),
      isFalse,
      reason: 'an ASCII digit survived the money formatter: $total',
    );
  });

  testWidgets('task ids use Persian digits in fa', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final haftKhan = harness.services.haftKhan;
    await haftKhan.addTask(title: 'بنویس');

    await _pumpPersian(harness, tester, const HaftKhanPage());

    expect(find.text('#۱'), findsWidgets);
    expect(
      find.textContaining(RegExp(r'#\d')),
      findsNothing,
      reason: 'the id rail should not fall back to ASCII in fa',
    );
  });

  testWidgets('counts use Persian digits in fa', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.dispose);
    await harness.build();
    final divan = harness.services.divan;
    await divan.createNotebook('کار');
    await divan.addNote(title: 'یادداشت', body: 'یک');
    await divan.addNote(title: 'دومی', body: 'دو');

    await _pumpPersian(harness, tester, const DivanPage());

    expect(find.text('۲'), findsWidgets);
  });

  testWidgets('no screen shows an ASCII numeral outside an input', (
    tester,
  ) async {
    // Three kinds of ASCII digit are *correct* in Persian and stay: what the reader typed or
    // will type (an ISO date, a coordinate, an interval — the parsers take ASCII), identifiers
    // the app is merely displaying (`jamejam.sync/1`, `AES-256-GCM`), and nothing else. This
    // sweep is what caught the money, the ids and the counts above; it is deliberately strict
    // so the next screen that forgets `FaFormat` fails here instead of shipping.
    final allowed = RegExp('AES-256-GCM|PBKDF2-HMAC-SHA512|jamejam[.]sync/1');
    final hasAsciiDigit = RegExp('[0-9]');
    final offenders = <String>[];
    for (final route in const [
      'dashboard',
      'greeter',
      'soroush',
      'settings',
      'haftkhan',
      'anahita',
      'ganjoor',
      'raz',
      'divan',
      'sync',
      'taqvim',
    ]) {
      final harness = TestHarness();
      await harness.build();
      await harness.services.settings.setLocale(const Locale('fa'));
      await tester.binding.setSurfaceSize(const Size(1500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...harness.services.providers(),
            ChangeNotifierProvider<AppNavigation>(
              create: (_) => AppNavigation(initial: route),
            ),
          ],
          child: const JameJamApp(),
        ),
      );
      await tester.pumpAndSettle();

      for (final element in find.byType(Text).evaluate()) {
        final data = (element.widget as Text).data;
        if (data == null || !hasAsciiDigit.hasMatch(data)) continue;
        if (allowed.hasMatch(data)) continue;
        // A field's own text — its hint, label, prefix or value — is input chrome: the
        // parsers behind those fields read ASCII (`2026-10-08`, `35.69,51.39`, `1`), so the
        // sweep stops at the `InputDecorator`/`EditableText` boundary.
        var inField = false;
        element.visitAncestorElements((ancestor) {
          final widget = ancestor.widget;
          if (widget is EditableText || widget is InputDecorator) {
            inField = true;
          }
          return !inField;
        });
        if (inField) continue;
        offenders.add('$route: $data');
      }
      harness.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(offenders, isEmpty);
  });
}
