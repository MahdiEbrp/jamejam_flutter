// The vault screen end to end: the lock card, the editor, the live TOTP chip, the audit
// panel, and the coach card — driven through the real composition root with an in-memory
// vault store and the KDF at its cheapest legal setting.
//
// `raz unlock`/`raz add`/`raz totp`/`raz audit` are the CLI verbs this screen stands in for;
// the assertions below are their GUI equivalents.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/raz/models.dart';
import 'package:jamejam/features/raz/raz_page.dart';
import 'package:jamejam/features/raz/vault_controller.dart';

import '../../helpers/test_harness.dart';

const String _passphrase = 'correct-horse-battery';
const String _rfcSeed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

String _completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

/// Drains the snack-bar queue.
///
/// A scaffold shows one snack bar at a time: the next one is queued and not even built until
/// the previous one leaves, which the fake clock only does when the test says so.
Future<void> _flushMessages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }
}

/// Taps something that starts a PBKDF2 derivation.
///
/// `package:cryptography` yields to the event loop every thousand iterations, and the fake
/// clock only moves when the test says so — so a bare `pumpAndSettle` can return while the
/// key is still being derived.
Future<void> _settleKdf(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

/// Pumps the screen onto a surface big enough to hold it.
Future<void> _pumpPage(WidgetTester tester, TestHarness harness) async {
  // The screen is a toolbar of wrapped buttons over a list of tiles: at the default
  // 800x600 test surface half of them fall outside the viewport and taps miss.
  await tester.binding.setSurfaceSize(const Size(1200, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(harness.wrap(const RazPage()));
  await tester.pumpAndSettle();
}

/// Creates the vault through the UI and returns the controller behind it.
Future<VaultController> _unlock(
  TestHarness harness,
  WidgetTester tester,
) async {
  await tester.enterText(find.byKey(razPassphraseFieldKey), _passphrase);
  await tester.tap(find.byKey(razCreateButtonKey));
  await _settleKdf(tester);
  expect(harness.services.raz.isUnlocked, isTrue);
  await _flushMessages(tester);
  return harness.services.raz;
}

Future<void> _addEntry(
  WidgetTester tester, {
  required String title,
  required String secret,
  String tags = '',
}) async {
  await tester.tap(find.byKey(razAddButtonKey));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('raz.field.title')), title);
  await tester.enterText(find.byKey(const Key('raz.field.secret')), secret);
  if (tags.isNotEmpty) {
    await tester.enterText(find.byKey(const Key('raz.field.tags')), tags);
  }

  await tester.tap(find.byKey(const Key('raz.field.submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a fresh install offers to create the vault', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await _pumpPage(tester, harness);

    expect(find.byKey(razCreateButtonKey), findsOneWidget);
    expect(find.byKey(razUnlockButtonKey), findsNothing);
    expect(find.text('Raz — encrypted vault'), findsOneWidget);
    expect(find.textContaining('no sync adapter'), findsOneWidget);

    await tester.enterText(find.byKey(razPassphraseFieldKey), _passphrase);
    await tester.tap(find.byKey(razCreateButtonKey));
    await _settleKdf(tester);

    expect(find.byKey(razAddButtonKey), findsOneWidget);
    expect(find.byKey(razCreateButtonKey), findsNothing);
    expect(find.byKey(razPassphraseFieldKey), findsNothing);
    expect(find.text('Vault created and unlocked.'), findsOneWidget);
  });

  testWidgets('after locking, a wrong passphrase is reported', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await _pumpPage(tester, harness);
    await _unlock(harness, tester);
    await _addEntry(tester, title: 'GitHub', secret: 'hunter2!builds-strong');
    expect(find.text('GitHub'), findsOneWidget);

    await tester.tap(find.byKey(razLockButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(razUnlockButtonKey), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);
    expect(harness.services.raz.isUnlocked, isFalse);

    await tester.enterText(find.byKey(razPassphraseFieldKey), 'not-it');
    await tester.tap(find.byKey(razUnlockButtonKey));
    await _settleKdf(tester);

    expect(find.text('Wrong passphrase or corrupted vault.'), findsOneWidget);
    expect(harness.services.raz.isUnlocked, isFalse);

    await tester.enterText(find.byKey(razPassphraseFieldKey), _passphrase);
    await tester.tap(find.byKey(razUnlockButtonKey));
    await _settleKdf(tester);

    expect(find.text('GitHub'), findsOneWidget);
    expect(harness.services.raz.isUnlocked, isTrue);
  });

  testWidgets('an entry typed into the editor lands in the list', (
    tester,
  ) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await _pumpPage(tester, harness);
    await _unlock(harness, tester);

    expect(
      find.text('No entries match. Add one, or clear the filters.'),
      findsOneWidget,
    );

    await _addEntry(
      tester,
      title: 'GitHub',
      secret: 'hunter2!builds-strong',
      tags: 'work, dev',
    );

    expect(find.text('Entry added.'), findsOneWidget);
    await _flushMessages(tester);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('work'), findsOneWidget);
    expect(harness.services.raz.entries.single.title, 'GitHub');
  });

  testWidgets('the search box and the filters narrow the list', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await _pumpPage(tester, harness);
    await _unlock(harness, tester);

    await _addEntry(tester, title: 'GitHub', secret: 'hunter2!builds-strong');
    await _flushMessages(tester);
    await _addEntry(tester, title: 'Router', secret: 'abc');
    await _flushMessages(tester);

    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Router'), findsOneWidget);

    await tester.enterText(find.byKey(razSearchFieldKey), 'rou');
    await tester.pumpAndSettle();

    expect(find.text('Router'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);

    await tester.enterText(find.byKey(razSearchFieldKey), '');
    await tester.tap(find.byKey(razWeakFilterKey));
    await tester.pumpAndSettle();

    expect(find.text('Router'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);

    await tester.tap(find.byKey(razWeakFilterKey));
    await tester.pumpAndSettle();
    expect(find.text('GitHub'), findsOneWidget);
  });

  testWidgets('reveal shows the secret and copy puts it on the clipboard', (
    tester,
  ) async {
    final clipboard = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboard.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await _pumpPage(tester, harness);
    final controller = await _unlock(harness, tester);
    await _addEntry(tester, title: 'GitHub', secret: 'hunter2!builds-strong');
    await _flushMessages(tester);

    final id = controller.entries.single.id;
    expect(find.text('hunter2!builds-strong'), findsNothing);

    await tester.tap(find.byKey(ValueKey('raz-reveal-$id')));
    await tester.pumpAndSettle();
    expect(find.text('hunter2!builds-strong'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('raz-copy-$id')));
    await tester.pumpAndSettle();

    expect(clipboard, hasLength(1));
    expect(
      (clipboard.single.arguments as Map<Object?, Object?>)['text'],
      'hunter2!builds-strong',
    );
    expect(find.text('Copied to the clipboard'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('raz-reveal-$id')));
    await tester.pumpAndSettle();
    expect(find.text('hunter2!builds-strong'), findsNothing);
  });

  testWidgets('the TOTP chip shows a live six-digit code', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await _pumpPage(tester, harness);
    final controller = await _unlock(harness, tester);
    await _addEntry(tester, title: 'RFC 6238', secret: 'shhh-its-a-secret');
    await _flushMessages(tester);

    // The seed is entered through the editor, the way a user would add it.
    final entry = controller.entries.single;
    await tester.tap(find.byKey(ValueKey('raz-edit-${entry.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('raz.field.totp')), _rfcSeed);
    await tester.tap(find.byKey(const Key('raz.field.submit')));
    await tester.pumpAndSettle();

    // The defaults come back with the seed, the way `raz edit` substitutes them.
    expect(controller.entries.single.totpSeed, _rfcSeed);
    expect(controller.entries.single.totpAlgorithm, TotpAlgorithm.sha1);

    final id = controller.entries.single.id;
    await tester.tap(find.byKey(ValueKey('raz-totp-$id')));
    await tester.pumpAndSettle();

    final totp = controller.totp;
    expect(totp, isNotNull);
    expect(RegExp(r'^\d{6}$').hasMatch(totp!.code), isTrue);
    expect(find.textContaining('TOTP ${totp.code}'), findsOneWidget);
  });

  testWidgets('the audit button fills the vault-health card', (tester) async {
    final harness = TestHarness();
    await harness.build();
    addTearDown(harness.dispose);

    await _pumpPage(tester, harness);
    await _unlock(harness, tester);

    await _addEntry(tester, title: 'GitHub', secret: 'hunter2!builds-strong');
    await _flushMessages(tester);
    await _addEntry(tester, title: 'Router', secret: 'abc');
    await _flushMessages(tester);

    await tester.tap(find.byKey(razAuditButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Vault health'), findsOneWidget);
    expect(find.text('entries'), findsOneWidget);
    expect(find.text('weak'), findsOneWidget);
    expect(find.text('Audit refreshed.'), findsOneWidget);
    await _flushMessages(tester);

    final stats = harness.services.raz.stats;
    expect(stats, isNotNull);
    expect(stats!.totalEntries, 2);
    expect(stats.weakCount, 1);

    await tester.tap(find.byKey(razUndoButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('Last change undone.'), findsOneWidget);
  });

  testWidgets('the coach answers, and never sees the entries', (tester) async {
    final sent = <String>[];
    final harness = TestHarness(
      httpClient: MockClient((request) async {
        sent.add(request.body);
        return http.Response(_completion('Rotate the weak one.'), 200);
      }),
    );
    await harness.build();
    addTearDown(harness.dispose);
    await harness.secretStore.write(SecretKeys.aiApiKey, 'sk-test-key');

    await _pumpPage(tester, harness);
    await _unlock(harness, tester);
    await _addEntry(tester, title: 'GitHub', secret: 'hunter2!builds-strong');
    await _flushMessages(tester);

    await tester.tap(find.byKey(razAiAuditButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Rotate the weak one.'), findsWidgets);
    expect(find.text('Security coach'), findsWidgets);
    expect(sent, hasLength(1));
    expect(sent.single, contains('---AUDIT BEGIN---'));
    expect(sent.single, isNot(contains('GitHub')));
    expect(sent.single, isNot(contains('hunter2!')));

    // A question goes through the same gate, with the question quoted.
    await tester.enterText(find.byKey(razAskFieldKey), 'how bad is it?');
    await tester.tap(find.byKey(razAskButtonKey));
    await tester.pumpAndSettle();

    expect(sent, hasLength(2));
    expect(sent.last, contains('Question: how bad is it?'));
  });
}
