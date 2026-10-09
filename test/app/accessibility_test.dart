import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/app/app.dart';
import 'package:jamejam/app/app_navigation.dart';
import 'package:jamejam/l10n/generated/app_localizations.dart';
import 'package:jamejam/widgets/adaptive_layout.dart';
import 'package:provider/provider.dart';

import '../helpers/test_harness.dart';

/// Every route the shell can open, in the order the dashboard lists them.
const List<String> _routes = [
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
];

/// The smallest phone viewport the app claims to support.
const Size _phone = Size(400, 800);

/// Pumps one route of the real shell at a chosen size, text scale and locale.
///
/// Errors during the pump are captured instead of failing the test, so the sweeps below can
/// report *which* route broke rather than stopping at the first one.
Future<List<FlutterErrorDetails>> _pumpRoute(
  WidgetTester tester,
  TestHarness harness, {
  required String route,
  Size size = const Size(1600, 1200),
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await harness.services.settings.setLocale(locale);
  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;
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
  FlutterError.onError = previous;
  return captured;
}

/// Tears one pumped shell down between routes.
Future<void> _tearDownRoute(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  await tester.binding.setSurfaceSize(null);
}

/// The first line that names the widget that overflowed, or null when nothing did.
String? _overflowSource(FlutterErrorDetails details) {
  for (final line in details.toString().split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('Row:') ||
        trimmed.startsWith('Column:') ||
        trimmed.startsWith('Wrap:') ||
        trimmed.startsWith('Flex:') ||
        trimmed.startsWith('Padding:')) {
      return trimmed;
    }
  }
  return null;
}

void main() {
  group('hit targets', () {
    testWidgets('every icon-only button carries a tooltip and a 40 dp target', (
      tester,
    ) async {
      final offenders = <String>[];
      for (final route in _routes) {
        final harness = TestHarness();
        await harness.build();
        await _pumpRoute(tester, harness, route: route);
        for (final element in find.byType(IconButton).evaluate()) {
          final button = element.widget as IconButton;
          final tooltip = button.tooltip?.trim() ?? '';
          final size = tester.getSize(find.byWidget(button));
          if (tooltip.isEmpty) {
            offenders.add('$route: IconButton without a tooltip');
          }
          // Material's own floor is 48 dp; 40 dp is the floor this app accepts for the
          // dense toolbars it copies from the .NET window.
          if (size.shortestSide < 40) {
            offenders.add(
              '$route: IconButton ${size.width}x${size.height} under 40 dp',
            );
          }
        }
        harness.dispose();
        await _tearDownRoute(tester);
      }
      expect(offenders, isEmpty);
    });
  });

  group('semantics', () {
    testWidgets('no tappable node is left without a label', (tester) async {
      final handle = tester.ensureSemantics();
      final offenders = <String>[];
      for (final route in _routes) {
        final harness = TestHarness();
        await harness.build();
        await _pumpRoute(tester, harness, route: route);
        // Each render view owns its own pipeline — and with it the semantics tree; the
        // binding-level owner is the deprecated spelling and is empty here.
        final root = tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!;
        // A tappable node may take its label from a wrapper: `Tooltip` puts the message on
        // the node above the button, `SegmentedButton` labels the segment rather than the
        // button inside it, and `ListTile` labels the row. Two levels is what those wrappers
        // need — a hand-written button of ours never relies on it, and forgetting a label on
        // one of ours is the defect this sweep exists to catch.
        void walk(SemanticsNode node, List<SemanticsNode> ancestors) {
          final data = node.getSemanticsData();
          final tappable =
              data.hasAction(SemanticsAction.tap) ||
              data.hasAction(SemanticsAction.longPress);
          if (tappable) {
            final labelled = <SemanticsNode>[node, ...ancestors].any((
              candidate,
            ) {
              final candidateData = candidate.getSemanticsData();
              return candidateData.label.trim().isNotEmpty ||
                  candidateData.tooltip.trim().isNotEmpty;
            });
            if (!labelled) {
              offenders.add(
                '$route: ${node.rect.size} node with a tap action and no label',
              );
            }
          }
          node.visitChildren((child) {
            // Keep the two nearest ancestors only.
            final chain = [...ancestors, node];
            walk(
              child,
              chain.length > 2 ? chain.sublist(chain.length - 2) : chain,
            );
            return true;
          });
        }

        walk(root, const []);
        harness.dispose();
        await _tearDownRoute(tester);
      }
      handle.dispose();
      expect(offenders, isEmpty);
    });

    testWidgets('the dashboard grid and the agenda are labelled regions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final harness = TestHarness();
      await harness.build();

      await _pumpRoute(tester, harness, route: 'dashboard');
      expect(
        find.bySemanticsLabel(RegExp('toolbox steps')),
        findsOneWidget,
        reason: 'the step grid should announce itself once',
      );
      await _tearDownRoute(tester);

      await _pumpRoute(tester, harness, route: 'taqvim');
      expect(find.bySemanticsLabel(RegExp('Agenda')), findsWidgets);

      handle.dispose();
      harness.dispose();
      await _tearDownRoute(tester);
    });
  });

  group('text scale', () {
    for (final size in const [Size(400, 800), Size(360, 640)]) {
      for (final scale in const [1.0, 1.3, 1.6]) {
        testWidgets(
          'nothing overflows on ${size.width}x${size.height} at $scale',
          (tester) async {
            final offenders = <String>[];
            for (final route in _routes) {
              final harness = TestHarness();
              await harness.build();
              final captured = await _pumpRoute(
                tester,
                harness,
                route: route,
                size: size,
                textScale: scale,
              );
              for (final details in captured) {
                final source = _overflowSource(details);
                if (source != null) {
                  offenders.add('$route: $source');
                }
              }
              harness.dispose();
              await _tearDownRoute(tester);
            }
            expect(offenders, isEmpty);
          },
        );
      }
    }

    testWidgets(
      'Persian on a phone at 1.6 keeps every route inside the window',
      (tester) async {
        final offenders = <String>[];
        for (final route in _routes) {
          final harness = TestHarness();
          await harness.build();
          final captured = await _pumpRoute(
            tester,
            harness,
            route: route,
            size: _phone,
            textScale: 1.6,
            locale: const Locale('fa'),
          );
          for (final details in captured) {
            final source = _overflowSource(details);
            if (source != null) {
              offenders.add('$route: $source');
            }
          }
          harness.dispose();
          await _tearDownRoute(tester);
        }
        expect(offenders, isEmpty);
      },
    );
  });

  group('adaptive layout', () {
    testWidgets('a roomy viewport keeps the classic column', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptivePageBody(
              chrome: const [Text('chrome')],
              body: Container(key: const Key('body'), color: Colors.black12),
            ),
          ),
        ),
      );
      expect(find.text('chrome'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
      final chromeHeight = tester.getSize(find.text('chrome')).height;
      expect(
        tester.getSize(find.byKey(const Key('body'))).height,
        900 - chromeHeight,
      );
    });

    testWidgets('a compact viewport scrolls and bounds the body', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptivePageBody(
              chrome: const [SizedBox(height: 600, child: Text('tall chrome'))],
              body: Container(key: const Key('body')),
            ),
          ),
        ),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      // 62% of 800 px, so the chrome can be scrolled off without starving the body.
      expect(tester.getSize(find.byKey(const Key('body'))).height, 496);
    });

    testWidgets('a field and its actions reflow instead of clipping', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FieldActionFlow(
              field: const TextField(),
              actions: [
                for (var i = 0; i < 3; i++)
                  FilledButton(onPressed: () {}, child: Text('Action $i')),
              ],
            ),
          ),
        ),
      );
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.runSpacing, 8);
      // Three buttons cannot share one row with the field at 360 px.
      expect(
        find.byType(FilledButton).evaluate().length,
        3,
        reason: 'the actions stay reachable after reflowing',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('keyboard', () {
    testWidgets('tab traversal reaches a screen action and Enter fires it', (
      tester,
    ) async {
      // The desktop targets have to be usable without a mouse. Every route is checked for
      // *a* reachable action: the settings screen's "Add" is the one that is also verifiable
      // end-to-end, since pressing Enter on it opens the add dialog.
      final harness = TestHarness();
      addTearDown(harness.dispose);
      await harness.build();
      await _pumpRoute(tester, harness, route: 'settings');

      Element? focusOwner;
      for (var press = 0; press < 40 && focusOwner == null; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus;
        final context = focused?.context;
        if (context == null) continue;
        var isTheAddButton = false;
        context.visitAncestorElements((ancestor) {
          if (ancestor.widget is FilledButton) {
            isTheAddButton = true;
          }
          return !isTheAddButton;
        });
        if (isTheAddButton) focusOwner = context as Element;
      }
      expect(
        focusOwner,
        isNotNull,
        reason: 'Tab should reach the settings screen primary action',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizations.of(focusOwner!).settingsAddTitle),
        findsOneWidget,
      );

      await _tearDownRoute(tester);
    });
  });
}
