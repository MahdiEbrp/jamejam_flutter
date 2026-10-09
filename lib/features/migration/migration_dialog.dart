/// migration — see doc/migration.md and AGENTS.md
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../ganjoor/ganjoor_controller.dart';
import '../haftkhan/haftkhan_controller.dart';
import '../raz/vault_controller.dart';
import '../taqvim/taqvim_controller.dart';
import 'dotnet_migration.dart';
import 'migration_import.dart';

const Key migrationTextBoxKey = Key('migration.text');

const Key migrationPasteKey = Key('migration.paste');

const Key migrationImportKey = Key('migration.import');

const Key migrationPreviewKey = Key('migration.preview');

const Key migrationResultKey = Key('migration.result');

Future<void> showMigrationDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const MigrationDialog());

class MigrationDialog extends StatefulWidget {
  /// Creates the dialog.
  const MigrationDialog({super.key});

  @override
  State<MigrationDialog> createState() => _MigrationDialogState();
}

class _MigrationDialogState extends State<MigrationDialog> {
  final TextEditingController _text = TextEditingController();
  var _busy = false;
  String? _result;
  bool _failed = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Names a detected document in the reader's language.
  String _describe(AppLocalizations l10n, DotnetDocument document) {
    if (document.problem == DotnetDocumentProblem.notJson) {
      return l10n.migrationNotJson;
    }
    if (document.kind == DotnetDocumentKind.unknown) {
      return l10n.migrationNotADocument;
    }

    final parts = <String>[
      switch (document.kind) {
        DotnetDocumentKind.haftKhanBackup => l10n.migrationKindHaftKhan,
        DotnetDocumentKind.ganjoorBackup => l10n.migrationKindGanjoor,
        DotnetDocumentKind.razBackup => l10n.migrationKindRaz,
        DotnetDocumentKind.taqvimCalendar => l10n.migrationKindTaqvim,
        DotnetDocumentKind.unknown => l10n.migrationNotADocument,
      },
    ];
    final version = document.version;
    if (version != null) parts.add(l10n.migrationVersion(version));

    final counts = document.counts;
    void add(String key, String Function(int) format) {
      final value = counts[key];
      if (value != null && value > 0) parts.add(format(value));
    }

    add('tasks', l10n.migrationTasks);
    add('links', l10n.migrationLinks);
    add('accounts', l10n.migrationAccounts);
    add('transactions', l10n.migrationTransactions);
    add('budgets', l10n.migrationBudgets);
    add('events', l10n.migrationEvents);

    return parts.join(' · ');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    setState(() {
      _text.text = data?.text ?? '';
      _result = null;
      _failed = false;
    });
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final document = DotnetMigration.inspect(_text.text);
    final kindLabel = _describe(l10n, document);

    setState(() {
      _busy = true;
      _result = null;
      _failed = false;
    });

    try {
      final outcome = await importDotnetDocument(
        _text.text,
        haftKhan: context.read<HaftKhanController>(),
        ganjoor: context.read<GanjoorController>(),
        raz: context.read<VaultController>(),
        taqvim: context.read<TaqvimController>(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = l10n.migrationResult(switch (outcome.kind) {
          DotnetDocumentKind.haftKhanBackup => l10n.migrationKindHaftKhan,
          DotnetDocumentKind.ganjoorBackup => l10n.migrationKindGanjoor,
          DotnetDocumentKind.razBackup => l10n.migrationKindRaz,
          DotnetDocumentKind.taqvimCalendar => l10n.migrationKindTaqvim,
          DotnetDocumentKind.unknown => l10n.migrationNotADocument,
        }, outcome.imported);
      });
    } catch (error) {
      // The parser's or the rail's own message, because those are the pinned contract.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
        _result = '$kindLabel — $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final document = DotnetMigration.inspect(_text.text);

    return AlertDialog(
      title: Text(l10n.migrationTitle),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.migrationSubtitle, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                key: migrationTextBoxKey,
                controller: _text,
                minLines: 4,
                maxLines: 10,
                onChanged: (_) => setState(() {
                  _result = null;
                  _failed = false;
                }),
                decoration: InputDecoration(
                  labelText: l10n.migrationTextLabel,
                  hintText: l10n.migrationTextHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _text.text.trim().isEmpty
                    ? l10n.migrationNothing
                    : _describe(l10n, document),
                key: migrationPreviewKey,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: document.isImportable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_result != null) ...[
                const SizedBox(height: 8),
                Text(
                  _result!,
                  key: migrationResultKey,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _failed
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
              const Divider(height: 24),
              for (final note in [
                l10n.migrationNoteHaftKhan,
                l10n.migrationNoteGanjoor,
                l10n.migrationNoteRaz,
                l10n.migrationNoteTaqvim,
                l10n.migrationNoteLocal,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $note', style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: migrationPasteKey,
          onPressed: _busy ? null : _paste,
          child: Text(l10n.migrationPaste),
        ),
        FilledButton(
          key: migrationImportKey,
          onPressed: _busy || !document.isImportable ? null : _import,
          child: Text(l10n.migrationImport),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
