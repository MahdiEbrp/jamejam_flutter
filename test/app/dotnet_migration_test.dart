// Migration from a .NET toolbox.
//
// The fixtures in this file are written the way `System.Text.Json` wrote them: PascalCase
// keys, the same version numbers, the same nested records. They are the whole point of the
// feature — the port's own readers are case-sensitive camelCase, so these documents are
// exactly what a user arriving from the .NET build has on disk and what has to keep working.
//
// The last case drives the dialog itself (settings → migrate), so the door the user walks
// through is exercised, not only the parser behind it.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/ganjoor/ganjoor_backup.dart';
import 'package:jamejam/features/haftkhan/backup.dart';
import 'package:jamejam/features/migration/dotnet_migration.dart';
import 'package:jamejam/features/migration/migration_dialog.dart';
import 'package:jamejam/features/raz/models.dart';
import 'package:jamejam/features/settings/settings_page.dart';
import 'package:jamejam/l10n/generated/app_localizations.dart';

import '../helpers/test_harness.dart';

/// A Haft Khan backup as `haftkhan export tasks.json` wrote it (version 2, PascalCase).
const String _dotnetHaftKhanBackup = '''
{
  "Version": 2,
  "ExportedAt": "2026-10-08T09:00:00.0000000+00:00",
  "Tasks": [
    {
      "Id": 1,
      "Title": "Write the release notes",
      "Notes": "for 0.1.0",
      "Priority": 2,
      "State": 0,
      "DueDate": "2026-10-10",
      "CreatedAt": "2026-10-01T08:00:00Z",
      "UpdatedAt": "2026-10-02T08:00:00Z",
      "CompletedAt": null,
      "Project": "release",
      "Tags": ["docs"],
      "Effort": 1,
      "Recurrence": 0,
      "RecurrenceInterval": 1,
      "StartedAt": null,
      "Uid": "3f0c1a2e-6b6f-4f2f-9a3a-0f1d2c3b4a59"
    }
  ],
  "Dependencies": []
}
''';

/// A wallet backup as `ganjoor export wallet.json` wrote it (version 1, PascalCase).
const String _dotnetGanjoorBackup = '''
{
  "Version": 1,
  "ExportedAt": "2026-10-08T09:00:00+00:00",
  "Accounts": [
    {
      "Id": 1,
      "Name": "Bank",
      "Currency": "USD",
      "InitialBalance": 100.00,
      "IsArchived": false,
      "CreatedAt": "2026-01-01T00:00:00Z"
    }
  ],
  "Transactions": [
    {
      "Id": 1,
      "AccountId": 1,
      "Kind": 1,
      "Amount": 12.50,
      "Category": "food",
      "Tags": ["food"],
      "Notes": "",
      "Date": "2026-10-01",
      "CreatedAt": "2026-10-01T00:00:00Z",
      "TransferToAccountId": null,
      "RecurringBillId": null
    }
  ],
  "Budgets": [],
  "Bills": [],
  "Goals": [],
  "Debts": []
}
''';

/// A calendar document as `taqvim export calendar.ics` wrote it.
const String _dotnetCalendar = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//JameJam//Taqvim//EN
BEGIN:VEVENT
UID:evt-1
DTSTART:20261012T090000Z
DTEND:20261012T100000Z
SUMMARY:Standup
END:VEVENT
END:VCALENDAR
''';

/// A vault bundle as `raz export vault.json` wrote it — the envelope is already PascalCase.
const String _dotnetVaultBundle = '''
{
  "Version": 1,
  "Salt": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
  "Iterations": 210000,
  "KeyCheck": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
  "Payload": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('detection', () {
    test('names a Haft Khan backup and counts it', () {
      final document = DotnetMigration.inspect(_dotnetHaftKhanBackup);
      expect(document.kind, DotnetDocumentKind.haftKhanBackup);
      expect(document.version, 2);
      expect(document.counts['tasks'], 1);
      expect(document.counts['links'], 0);
      expect(document.isImportable, isTrue);
    });

    test('names a wallet backup and counts it', () {
      final document = DotnetMigration.inspect(_dotnetGanjoorBackup);
      expect(document.kind, DotnetDocumentKind.ganjoorBackup);
      expect(document.version, 1);
      expect(document.counts['accounts'], 1);
      expect(document.counts['transactions'], 1);
    });

    test('names a vault bundle and a calendar', () {
      expect(
        DotnetMigration.inspect(_dotnetVaultBundle).kind,
        DotnetDocumentKind.razBackup,
      );
      expect(
        DotnetMigration.inspect(_dotnetCalendar).kind,
        DotnetDocumentKind.taqvimCalendar,
      );
    });

    test('refuses text that is not a document', () {
      expect(
        DotnetMigration.inspect('hello').problem,
        DotnetDocumentProblem.notJson,
      );
      expect(
        DotnetMigration.inspect('{"hello": 1}').problem,
        DotnetDocumentProblem.notADocument,
      );
      expect(DotnetMigration.inspect('   ').isImportable, isFalse);
    });
  });

  group('translation', () {
    test('the .NET spelling of a task lands on the reader the port uses', () {
      final translated = DotnetMigration.translate(_dotnetHaftKhanBackup);
      final backup = Backup.fromJson(translated);
      expect(backup.version, 2);
      expect(backup.tasks.single.title, 'Write the release notes');
      expect(backup.tasks.single.project, 'release');
      expect(backup.tasks.single.tags, ['docs']);
      expect(backup.tasks.single.uid, '3f0c1a2e-6b6f-4f2f-9a3a-0f1d2c3b4a59');
    });

    test('a camelCase document is left alone', () {
      final camel = '{"version":1,"tasks":[],"dependencies":[]}';
      expect(DotnetMigration.translate(camel), camel);
    });

    test('a decimal the .NET wrote as a number is re-spelled as a string', () {
      // `System.Text.Json` writes a C# decimal as a JSON number; the port reads the
      // invariant string its own export writes. Without this hop the wallet refuses every
      // amount a .NET backup carries.
      final translated = DotnetMigration.translate(_dotnetGanjoorBackup);
      expect(translated, contains('"initialBalance": "100.00"'));
      expect(translated, contains('"amount": "12.50"'));
      final wallet = GanjoorBackup.fromJson(translated);
      expect(wallet.accounts.single.initialBalance.toStorage(), '100.00');
      expect(wallet.transactions.single.amount.toStorage(), '12.50');
    });

    test('a vault bundle crosses over in either spelling', () {
      // The Raz envelope was written in the .NET's casing and its reader takes either
      // spelling, so a bundle migrates as it stands — the ciphertext is never touched.
      final original = VaultBackupFile.fromJson(
        jsonDecode(_dotnetVaultBundle) as Map<String, Object?>,
      );
      final translated = VaultBackupFile.fromJson(
        jsonDecode(DotnetMigration.translate(_dotnetVaultBundle))
            as Map<String, Object?>,
      );
      expect(translated.version, original.version);
      expect(translated.iterations, original.iterations);
      expect(translated.payload, original.payload);
      expect(translated.salt, original.salt);
    });

    test('an acronym key is lowered whole, not to a broken half-case', () {
      final translated = DotnetMigration.translate('{"UID":"x","Id":1}');
      expect(translated, contains('"uid"'));
      expect(translated, contains('"id"'));
    });
  });

  group('the dialog', () {
    testWidgets('a .NET task backup is imported through the settings door', (
      tester,
    ) async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      await harness.build();
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness.wrap(const SettingsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(settingsMigrateKey));
      await tester.pumpAndSettle();
      expect(find.byType(MigrationDialog), findsOneWidget);

      // Nothing pasted: the preview says so and the button is inert.
      expect(
        tester.widget<FilledButton>(find.byKey(migrationImportKey)).onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(migrationTextBoxKey),
        _dotnetHaftKhanBackup,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(migrationPreviewKey)).data,
        contains('Haft Khan backup'),
      );

      await tester.tap(find.byKey(migrationImportKey));
      await tester.pumpAndSettle();

      expect(
        harness.services.haftKhan.tasks.single.title,
        'Write the release notes',
      );
      expect(
        tester.widget<Text>(find.byKey(migrationResultKey)).data,
        contains('Imported Haft Khan backup: 1 record(s).'),
      );
    });

    testWidgets('a damaged backup fails with the message the rails pin', (
      tester,
    ) async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      await harness.build();
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness.wrap(const MigrationDialog()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(migrationTextBoxKey),
        '{"Version": 9, "Tasks": [], "Dependencies": []}',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(migrationImportKey));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(migrationResultKey)).data,
        contains('Unsupported backup version 9'),
        reason: 'the rails speak, not the dialog',
      );
      expect(harness.services.haftKhan.tasks, isEmpty);
    });

    testWidgets('a .NET wallet backup fills the wallet', (tester) async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      await harness.build();
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness.wrap(const MigrationDialog()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(migrationTextBoxKey),
        _dotnetGanjoorBackup,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(migrationImportKey));
      await tester.pumpAndSettle();

      final wallet = harness.services.ganjoor;
      expect(wallet.accounts.single.name, 'Bank');
      expect(wallet.transactions.single.amount.toStorage(), '12.50');
      expect(wallet.transactions.single.tags, ['food']);
      expect(wallet.accounts.single.initialBalance.toStorage(), '100.00');
      expect(
        tester.widget<Text>(find.byKey(migrationResultKey)).data,
        contains('Ganjoor wallet backup'),
      );
    });

    testWidgets('a locked vault says so instead of guessing', (tester) async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      await harness.build();
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness.wrap(const MigrationDialog()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(migrationTextBoxKey),
        _dotnetVaultBundle,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(migrationImportKey));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(migrationResultKey)).data,
        contains('The vault is locked'),
        reason: 'the vault rail answers, and the bundle is never half-applied',
      );
    });

    testWidgets('the dialog reads Persian', (tester) async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      await harness.build();
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: MigrationDialog()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('داده‌های پیشین را بیاورید'), findsOneWidget);
      await tester.enterText(
        find.byKey(migrationTextBoxKey),
        _dotnetHaftKhanBackup,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('پشتیبان هفت‌خان'), findsWidgets);
    });
  });
}
