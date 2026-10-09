import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/app/app_shell.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/greeter/greeter_page.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/settings/settings_page.dart';

import '../helpers/test_harness.dart';

String _completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

void main() {
  testWidgets('the shell opens on the dashboard with every step catalogued', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.wrapApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('steps implemented'), findsOneWidget);
    expect(find.text('Haft Khan'), findsWidgets);
    expect(find.text('Anahita'), findsWidgets);
  });

  testWidgets('navigating to the greeter produces a local greeting', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.wrapApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Greeter').last);
    await tester.pumpAndSettle();

    expect(find.byType(GreeterPage), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Sara');
    await tester.tap(find.text('Greet').first);
    await tester.pumpAndSettle();

    expect(find.text('Hello, Sara!'), findsOneWidget);
  });

  testWidgets(
    'the AI greeting routes through the funnel and renders the reply',
    (tester) async {
      final requests = <http.Request>[];
      final harness = TestHarness(
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(_completion('Good morning, Sara!'), 200);
        }),
      );
      await harness.build();
      addTearDown(harness.dispose);

      await harness.secretStore.write(SecretKeys.aiApiKey, 'sk-test');
      await harness.services.settings.load();

      await tester.pumpWidget(harness.wrap(const GreeterPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Sara');
      await tester.tap(find.text('Greet with AI'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(requests.single.headers['authorization'], 'Bearer sk-test');
      expect(find.text('Good morning, Sara!'), findsOneWidget);
    },
  );

  testWidgets(
    'the AI greeting explains a missing key instead of failing obscurely',
    (tester) async {
      final harness = TestHarness();
      await harness.build();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.wrap(const GreeterPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Greet with AI'));
      await tester.pumpAndSettle();

      expect(find.textContaining('needs an API key'), findsOneWidget);
    },
  );

  testWidgets('switching to Persian makes the whole app right-to-left', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.wrapApp());
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(AppShell))),
      TextDirection.ltr,
    );

    await harness.services.settings.set(SettingKeys.appLocale, 'fa');
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(AppShell))),
      TextDirection.rtl,
    );
    expect(find.text('خانه'), findsWidgets);
  });

  testWidgets('the settings screen refuses a secret-looking key and says why', (
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
      'openai.apiKey',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Value'),
      'sk-secret',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('looks like a secret'), findsOneWidget);
    expect(harness.services.settings.entries, isEmpty);
  });

  testWidgets('the settings screen persists a legitimate key', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.wrap(const SettingsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Key'),
      'anahita.units',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Value'), 'metric');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(harness.services.settings.value('anahita.units'), 'metric');
    expect(find.text('metric'), findsOneWidget);
  });

  testWidgets('the desktop layout shows a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.wrapApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
  });
}
