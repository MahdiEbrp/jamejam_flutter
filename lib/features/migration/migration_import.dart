/// migration — see doc/migration.md and AGENTS.md
library;

import '../ganjoor/ganjoor_backup.dart';
import '../ganjoor/ganjoor_controller.dart';
import '../haftkhan/backup.dart';
import '../haftkhan/haftkhan_controller.dart';
import '../raz/vault_controller.dart';
import '../taqvim/taqvim_controller.dart';
import 'dotnet_migration.dart';

class MigrationOutcome {
  /// Creates the outcome of importing [kind].
  const MigrationOutcome({
    required this.kind,
    this.imported = 0,
    this.backupVersion,
  });

  /// The document that was applied.
  final DotnetDocumentKind kind;

  /// How many records (or entries, or events) landed.
  final int imported;

  /// The version the document declared, when it declared one.
  final int? backupVersion;
}

Future<MigrationOutcome> importDotnetDocument(
  String text, {
  required HaftKhanController haftKhan,
  required GanjoorController ganjoor,
  required VaultController raz,
  required TaqvimController taqvim,
}) async {
  final document = DotnetMigration.inspect(text);
  final translated = DotnetMigration.translate(text);

  switch (document.kind) {
    case DotnetDocumentKind.haftKhanBackup:
      // Parse first: a document the reader rejects never reaches the store, so nothing is
      // half-applied.
      final backup = Backup.fromJson(translated);
      await haftKhan.importBackup(backup, replace: false);
      _refuseRecorded(haftKhan.error);
      return MigrationOutcome(
        kind: document.kind,
        imported: backup.tasks.length,
        backupVersion: backup.version,
      );

    case DotnetDocumentKind.ganjoorBackup:
      final file = GanjoorBackup.fromJson(translated);
      await ganjoor.importJsonText(translated);
      _refuseRecorded(ganjoor.error);
      return MigrationOutcome(
        kind: document.kind,
        imported: file.transactions.length,
        backupVersion: file.version,
      );

    case DotnetDocumentKind.razBackup:
      // The Raz envelope was written in the .NET's own casing and its reader takes either,
      // so the bundle goes across as it stands — still encrypted, opened by the passphrase
      // it was made with.
      final entries = await raz.importBackup(text.trim());
      _refuseRecorded(raz.error);
      return MigrationOutcome(kind: document.kind, imported: entries);

    case DotnetDocumentKind.taqvimCalendar:
      final events = await taqvim.importIcs(text);
      _refuseRecorded(taqvim.error);
      return MigrationOutcome(kind: document.kind, imported: events.length);

    case DotnetDocumentKind.unknown:
      throw const FormatException(
        'This file is not a document this app can read.',
      );
  }
}

void _refuseRecorded(String? error) {
  final message = error?.trim() ?? '';
  if (message.isNotEmpty) throw FormatException(message);
}
