// Parity port of the CLI-level files:
//   tests/JameJam.Tests/AppTests.cs          (5 facts + 1 theory, 8 cases)
//   tests/JameJam.Tests/AppSettingsTests.cs  (8 facts, 8 cases)
//   tests/JameJam.Tests/AppHaftKhanTests.cs  → phase 4 (not yet ported)
//
// The .NET versions drive `App.RunAsync(string[] args)` and assert on console output. A GUI
// has no argv, so each case is asserted where the behaviour now lives: the composition root
// for wiring, the navigation/shell for routing, and the screens for output.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/app/app_shell.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/greeter/greeter_page.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/settings/settings_page.dart';
import 'package:jamejam/features/soroush/soroush_page.dart';

import '../helpers/test_harness.dart';

void main() {
  group('AppTests parity — wiring and routing', () {
    // Constructor_WithNullOutput_Throws / RunAsync_WithNullArgs_Throws
    // → the Dart equivalent of "the app refuses to start with a missing dependency" is that
    //   the composition root always produces a complete graph.
    test('the composition root builds a complete graph', () async {
      final harness = TestHarness();
      final services = await harness.build();
      addTearDown(harness.dispose);

      expect(services.settings, isNotNull);
      expect(services.settingsStore, isNotNull);
      expect(services.secrets, isNotNull);
      expect(services.funnel, isNotNull);
      expect(services.soroush, isNotNull);
      expect(services.greeter, isNotNull);
      expect(services.settings.isLoaded, isTrue);
    });

    // RunAsync_WithNoArgs_GreetsWorldAndReturnsZero
    testWidgets('the default screen settles on the dashboard, not an error', (
      tester,
    ) async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrapApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AppShell), findsOneWidget);
    });

    // RunAsync_WithHelp_PrintsUsageAndReturnsZero [3 inline]
    // → every route the shell advertises must resolve to a real screen.
    test('every destination in the shell is reachable and builds', () {
      final destinations = AppShell.destinations();
      expect(destinations, hasLength(11));
      expect(destinations.first.id, 'dashboard');
      for (final destination in destinations) {
        expect(
          () => destination.builder(),
          returnsNormally,
          reason: 'destination ${destination.id}',
        );
      }
      final ids = destinations.map((d) => d.id).toSet();
      expect(
        ids,
        hasLength(destinations.length),
        reason: 'duplicate route ids',
      );
    });

    // RunAsync_WithName_GreetsNameAndReturnsZero / …_TreatsItAsName
    testWidgets('a name typed into the greeter is greeted', (tester) async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const GreeterPage()));
      await tester.pumpAndSettle();

      // The first argument in the CLI becomes the text field here.
      await tester.enterText(find.byType(TextField).first, 'Rostam');
      await tester.tap(find.text('Greet').first);
      await tester.pumpAndSettle();

      expect(find.text('Hello, Rostam!'), findsOneWidget);
    });
  });

  group('AppSettingsTests parity', () {
    // Set_ThenGet_RoundTrips / List_PrintsAllEntries
    testWidgets('the settings screen lists what was set', (tester) async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      await harness.services.settings.set('anahita.location', 'Berlin');

      await tester.pumpWidget(harness.wrap(const SettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('anahita.location'), findsOneWidget);
      expect(find.text('Berlin'), findsOneWidget);
    });

    // Get_MissingKey_Fails
    test('a missing key reads as null rather than failing the app', () async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      expect(harness.services.settings.value('never.set'), isNull);
      expect(await harness.services.settings.read('never.set'), isNull);
    });

    // Remove_RemovesExistingKey
    testWidgets('removing a setting takes it out of the list', (tester) async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      await harness.services.settings.set('divan.notebook', 'Research');

      await tester.pumpWidget(harness.wrap(const SettingsPage()));
      await tester.pumpAndSettle();
      expect(find.text('divan.notebook'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();

      expect(find.text('divan.notebook'), findsNothing);
    });

    // Clear_RemovesEverything
    testWidgets('clear-all empties the store', (tester) async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      await harness.services.settings.set('a.key', '1');
      await harness.services.settings.set('b.key', '2');

      await tester.pumpWidget(harness.wrap(const SettingsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear').last);
      await tester.pumpAndSettle();

      expect(harness.services.settings.entries, isEmpty);
    });

    // WithoutStore_SettingsCommand_Fails
    // → the GUI equivalent: a store that refuses still produces a message, not a crash.
    test('a refusing store surfaces a message and keeps running', () async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      final refusal = await harness.services.settings.set('sync.token', 'abc');
      expect(refusal, isNotNull);
      expect(harness.services.settings.lastError, isNotNull);
    });

    // SecretLookingKey_IsRefused
    testWidgets('a secret-looking key is refused with the reason shown', (
      tester,
    ) async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const SettingsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Key'),
        'soroush.apiKey',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Value'), 'sk-1');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('looks like a secret'), findsOneWidget);
      expect(harness.services.settings.entries, isEmpty);
    });

    // Greet_UsesDefaultNameSetting_WhenNoArgs
    testWidgets('the greeter falls back to the default-name setting', (
      tester,
    ) async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      await harness.services.settings.set(
        SettingKeys.greeterDefaultName,
        'Soroush',
      );

      await tester.pumpWidget(harness.wrap(const GreeterPage()));
      await tester.pumpAndSettle();

      // No name typed: the stored default is used.
      await tester.tap(find.text('Greet').first);
      await tester.pumpAndSettle();

      expect(find.text('Hello, Soroush!'), findsOneWidget);
    });
  });

  group('AppSoroushTests parity — the soroush screen', () {
    // ClientFailure_SurfacesMessage, through the actual screen.
    testWidgets('a provider failure is shown on the AI screen', (tester) async {
      // 400 is non-retryable, so the failure is surfaced without backoff delays.
      final harness = TestHarness(
        httpClient: MockClient((_) async => http.Response('boom', 400)),
      );
      await harness.build();
      addTearDown(harness.dispose);

      await harness.secretStore.write(SecretKeys.aiApiKey, 'sk-test');
      await harness.services.settings.load();

      await tester.pumpWidget(harness.wrap(const SoroushPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(promptFieldKey), 'hello');
      // "Send" is both the card title and the button label; target the button's icon.
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.textContaining('boom'), findsOneWidget);
    });

    // Flags_FlowIntoOptions — the key field writes to the keychain, not the settings DB.
    testWidgets('saving a key puts it in the secret store and masks it', (
      tester,
    ) async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const SoroushPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(apiKeyFieldKey), 'sk-abcdefghijkl');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        await harness.secretStore.read(SecretKeys.aiApiKey),
        'sk-abcdefghijkl',
      );
      expect(find.textContaining('sk-abcdefghijkl'), findsNothing);
      expect(find.textContaining('****ijkl'), findsOneWidget);
      // …and nothing about it reached the settings database.
      expect(harness.services.settings.entries, isEmpty);
    });

    // MissingKey_OnNonLoopbackEndpoint_Fails, surfaced in the UI.
    testWidgets('the key chip reports a missing key', (tester) async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const SoroushPage()));
      await tester.pumpAndSettle();

      expect(find.textContaining('No API key'), findsOneWidget);
    });
  });
}
