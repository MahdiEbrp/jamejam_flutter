/// raz — see doc/raz.md and AGENTS.md
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/date_only.dart';
import '../../l10n/generated/app_localizations.dart';
import 'models.dart';
import 'raz_defaults.dart';
import 'strength_meter.dart';
import 'vault_controller.dart';

const Key razPassphraseFieldKey = Key('raz.passphrase');

const Key razUnlockButtonKey = Key('raz.unlock');

const Key razCreateButtonKey = Key('raz.create');

const Key razStoredPassphraseButtonKey = Key('raz.stored');

const Key razForgetPassphraseButtonKey = Key('raz.forget');

const Key razLockButtonKey = Key('raz.lock');

const Key razSearchFieldKey = Key('raz.search');

const Key razAddButtonKey = Key('raz.add');

const Key razRefreshButtonKey = Key('raz.refresh');

const Key razUndoButtonKey = Key('raz.undo');

const Key razAuditButtonKey = Key('raz.audit');

const Key razAiAuditButtonKey = Key('raz.ai.audit');

const Key razAskFieldKey = Key('raz.ai.question');

const Key razAskButtonKey = Key('raz.ai.ask');

const Key razExportButtonKey = Key('raz.export');

const Key razImportButtonKey = Key('raz.import');

const Key razTransferFieldKey = Key('raz.transfer');

const Key razFavoritesFilterKey = Key('raz.filter.favorites');

const Key razWeakFilterKey = Key('raz.filter.weak');

const Key razExpiredFilterKey = Key('raz.filter.expired');

class RazPage extends StatefulWidget {
  /// Creates the screen; the controller comes from the provider graph.
  const RazPage({super.key});

  @override
  State<RazPage> createState() => _RazPageState();
}

class _RazPageState extends State<RazPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<VaultController>();
      await controller.initialise();
      if (!mounted || controller.isUnlocked) return;
      // The CLI accepted the passphrase from the environment or the keychain; a GUI
      // can do the same before showing the form.
      await controller.unlockWithStoredPassphrase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VaultController>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.razTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          l10n.razSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (controller.error != null) ...[
          _ErrorCard(message: controller.error!),
          const SizedBox(height: 12),
        ],
        if (!controller.isUnlocked)
          _LockCard(controller: controller, l10n: l10n)
        else ...[
          _Toolbar(controller: controller, l10n: l10n),
          const SizedBox(height: 12),
          if (controller.stats != null) ...[
            _AuditCard(stats: controller.stats!, l10n: l10n),
            const SizedBox(height: 12),
          ],
          if (controller.aiAnswer != null) ...[
            _AnswerCard(
              answer: controller.aiAnswer!,
              l10n: l10n,
              onClear: controller.clearAiAnswer,
            ),
            const SizedBox(height: 12),
          ],
          _EntryList(controller: controller, l10n: l10n),
          const SizedBox(height: 12),
          _AiCoachCard(controller: controller, l10n: l10n),
        ],
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockCard extends StatefulWidget {
  const _LockCard({required this.controller, required this.l10n});

  final VaultController controller;
  final AppLocalizations l10n;

  @override
  State<_LockCard> createState() => _LockCardState();
}

class _LockCardState extends State<_LockCard> {
  late final TextEditingController _passphrase = TextEditingController();
  bool _hasStored = false;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    unawaited(_readStoredFlag());
  }

  Future<void> _readStoredFlag() async {
    final value = await widget.controller.hasStoredPassphrase;
    if (mounted) setState(() => _hasStored = value);
  }

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = widget.l10n;
    final fresh = !controller.isInitialized;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fresh ? l10n.razCreateTitle : l10n.razUnlockTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.razPassphraseHint),
            const SizedBox(height: 12),
            TextField(
              key: razPassphraseFieldKey,
              controller: _passphrase,
              obscureText: true,
              onChanged: (_) => controller.touch(),
              decoration: InputDecoration(
                labelText: l10n.razPassphrase,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (!fresh)
              CheckboxListTile(
                value: _remember,
                onChanged: (value) => setState(() => _remember = value ?? true),
                title: Text(l10n.razRememberPassphrase),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: fresh ? razCreateButtonKey : razUnlockButtonKey,
                  onPressed: controller.busy
                      ? null
                      : () => runRazAction(context, () async {
                          final passphrase = _passphrase.text;
                          if (fresh) {
                            await controller.createVault(passphrase);
                            return l10n.razVaultCreated;
                          }

                          await controller.unlock(passphrase);
                          if (_remember) {
                            await controller.rememberPassphrase(passphrase);
                          }

                          return l10n.razUnlocked;
                        }),
                  icon: Icon(fresh ? Icons.add_moderator : Icons.lock_open),
                  label: Text(fresh ? l10n.razCreate : l10n.razUnlock),
                ),
                if (_hasStored && !fresh)
                  OutlinedButton.icon(
                    key: razStoredPassphraseButtonKey,
                    onPressed: controller.busy
                        ? null
                        : () => runRazAction(context, () async {
                            final unlocked = await controller
                                .unlockWithStoredPassphrase();
                            return unlocked
                                ? l10n.razUnlocked
                                : l10n.razNoStoredPassphrase;
                          }),
                    icon: const Icon(Icons.key),
                    label: Text(l10n.razUseStoredPassphrase),
                  ),
                if (_hasStored && !fresh)
                  TextButton.icon(
                    key: razForgetPassphraseButtonKey,
                    onPressed: controller.busy
                        ? null
                        : () => runRazAction(context, () async {
                            await controller.forgetPassphrase();
                            setState(() => _hasStored = false);
                            return l10n.razPassphraseForgotten;
                          }),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.razForgetPassphrase),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.razLocalOnly,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatefulWidget {
  const _Toolbar({required this.controller, required this.l10n});

  final VaultController controller;
  final AppLocalizations l10n;

  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> {
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.search,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = widget.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                key: razSearchFieldKey,
                controller: _search,
                onChanged: (value) => controller.setSearch(value),
                decoration: InputDecoration(
                  labelText: l10n.razSearch,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            FilterChip(
              key: razFavoritesFilterKey,
              selected: controller.favoritesOnly,
              onSelected: (_) => controller.toggleFavorites(),
              label: Text(l10n.razFilterFavorites),
            ),
            FilterChip(
              key: razWeakFilterKey,
              selected: controller.weakOnly,
              onSelected: (_) => controller.toggleWeakOnly(),
              label: Text(l10n.razFilterWeak),
            ),
            FilterChip(
              key: razExpiredFilterKey,
              selected: controller.expiredOnly,
              onSelected: (_) => controller.toggleExpired(),
              label: Text(l10n.razFilterExpired),
            ),
            FilledButton.icon(
              key: razAddButtonKey,
              onPressed: controller.busy
                  ? null
                  : () => showRazEntryDialog(context, controller: controller),
              icon: const Icon(Icons.add),
              label: Text(l10n.razAddEntry),
            ),
            OutlinedButton.icon(
              key: razRefreshButtonKey,
              onPressed: controller.busy ? null : () => controller.refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRefresh),
            ),
            OutlinedButton.icon(
              key: razUndoButtonKey,
              onPressed: controller.busy
                  ? null
                  : () => runRazAction(context, () async {
                      final restored = await controller.undo();
                      return restored ? l10n.razUndone : l10n.razNothingToUndo;
                    }),
              icon: const Icon(Icons.undo),
              label: Text(l10n.commonUndo),
            ),
            OutlinedButton.icon(
              key: razAuditButtonKey,
              onPressed: controller.busy
                  ? null
                  : () => runRazAction(context, () async {
                      await controller.audit();
                      return l10n.razAuditDone;
                    }),
              icon: const Icon(Icons.policy_outlined),
              label: Text(l10n.razAudit),
            ),
            OutlinedButton.icon(
              key: razAiAuditButtonKey,
              onPressed: controller.busy
                  ? null
                  : () =>
                        runRazAction(context, () async => controller.aiAudit()),
              icon: const Icon(Icons.psychology_outlined),
              label: Text(l10n.razAiAudit),
            ),
            OutlinedButton.icon(
              key: razExportButtonKey,
              onPressed: controller.busy
                  ? null
                  : () => runRazAction(context, () async {
                      final bundle = await controller.exportBackup();
                      await Clipboard.setData(ClipboardData(text: bundle));
                      return l10n.razExported;
                    }),
              icon: const Icon(Icons.save_alt),
              label: Text(l10n.razExport),
            ),
            OutlinedButton.icon(
              key: razImportButtonKey,
              onPressed: controller.busy
                  ? null
                  : () => showRazImportDialog(context, controller: controller),
              icon: const Icon(Icons.file_download_outlined),
              label: Text(l10n.razImport),
            ),
            TextButton.icon(
              key: razLockButtonKey,
              onPressed: () async {
                controller.lock();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.razLocked)));
              },
              icon: const Icon(Icons.lock),
              label: Text(l10n.razLock),
            ),
          ],
        ),
        if (controller.tagFilter != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(
                label: Text(l10n.razTagFilter(controller.tagFilter!)),
                onDeleted: () => controller.setTagFilter(null),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.stats, required this.l10n});

  final VaultAuditStats stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assessment_outlined),
                const SizedBox(width: 8),
                Text(l10n.razAuditTitle, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Stat(
                  label: l10n.razStatEntries,
                  value: '${stats.totalEntries}',
                ),
                _Stat(label: l10n.razStatWeak, value: '${stats.weakCount}'),
                _Stat(label: l10n.razStatReused, value: '${stats.reusedCount}'),
                _Stat(
                  label: l10n.razStatExpired,
                  value: '${stats.expiredCount}',
                ),
                _Stat(
                  label: l10n.razStatExpiringSoon,
                  value: '${stats.expiringSoonCount}',
                ),
                _Stat(label: l10n.razStatOld, value: '${stats.oldCount}'),
                _Stat(
                  label: l10n.razStatAverageLength,
                  value: '${stats.averageSecretLength}',
                ),
                _Stat(
                  label: l10n.razStatUnique,
                  value: '${stats.uniqueSecrets}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.l10n,
    required this.onClear,
  });

  final String answer;
  final AppLocalizations l10n;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.razCoachTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close),
                tooltip: l10n.commonClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(answer),
        ],
      ),
    ),
  );
}

class _AiCoachCard extends StatefulWidget {
  const _AiCoachCard({required this.controller, required this.l10n});

  final VaultController controller;
  final AppLocalizations l10n;

  @override
  State<_AiCoachCard> createState() => _AiCoachCardState();
}

class _AiCoachCardState extends State<_AiCoachCard> {
  late final TextEditingController _question = TextEditingController();

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final l10n = widget.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.razCoachTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(l10n.razCoachSubtitle),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: razAskFieldKey,
                    controller: _question,
                    onChanged: (_) => controller.touch(),
                    decoration: InputDecoration(
                      labelText: l10n.razCoachQuestion,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: razAskButtonKey,
                  onPressed: controller.busy
                      ? null
                      : () => runRazAction(
                          context,
                          () async => controller.ask(_question.text),
                        ),
                  child: Text(l10n.razAsk),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.controller, required this.l10n});

  final VaultController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (controller.entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.razNoEntries),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (final entry in controller.entries)
            _EntryTile(entry: entry, controller: controller, l10n: l10n),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.controller,
    required this.l10n,
  });

  final RazEntry entry;
  final VaultController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final revealed = controller.revealedSecret == entry.secret;
    final totp = controller.totpEntryId == entry.id ? controller.totp : null;
    final strength = StrengthMeter.score(entry.secret);

    return ListTile(
      key: ValueKey('raz-entry-${entry.id}'),
      leading: Icon(entry.favorite ? Icons.star : Icons.vpn_key_outlined),
      title: Text(entry.title.isEmpty ? l10n.razUntitled : entry.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  revealed ? entry.secret : '•' * strength.score.clamp(1, 8),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: revealed ? 'monospace' : null,
                  ),
                ),
              ),
              Text(
                strength.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              if (entry.username.isNotEmpty) Text(entry.username),
              if (entry.url.isNotEmpty) Text(entry.url),
              if (entry.expiresOn != null)
                Text(l10n.razExpiresOn(entry.expiresOn!.format())),
              for (final tag in entry.tagList)
                ActionChip(
                  label: Text(tag),
                  onPressed: () => controller.setTagFilter(tag),
                ),
            ],
          ),
          if (totp != null)
            Text(
              l10n.razTotpValue(totp.code, totp.secondsRemaining),
              style: theme.textTheme.titleMedium,
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            key: ValueKey('raz-reveal-${entry.id}'),
            tooltip: revealed ? l10n.razHideSecret : l10n.razRevealSecret,
            onPressed: () => controller.reveal(revealed ? null : entry.id),
            icon: Icon(revealed ? Icons.visibility_off : Icons.visibility),
          ),
          IconButton(
            key: ValueKey('raz-totp-${entry.id}'),
            tooltip: l10n.razTotpRefresh,
            onPressed: () => controller.refreshTotp(entry.id),
            icon: const Icon(Icons.timer_outlined),
          ),
          IconButton(
            key: ValueKey('raz-copy-${entry.id}'),
            tooltip: l10n.razCopySecret,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: entry.secret));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.commonCopied)));
            },
            icon: const Icon(Icons.copy_all),
          ),
          IconButton(
            key: ValueKey('raz-edit-${entry.id}'),
            tooltip: l10n.commonEdit,
            onPressed: () => showRazEntryDialog(
              context,
              controller: controller,
              existing: entry,
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: ValueKey('raz-delete-${entry.id}'),
            tooltip: l10n.commonDelete,
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.razDeleteTitle),
        content: Text(l10n.razDeleteMessage(entry.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('raz.delete.confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await runRazAction(context, () async {
      await controller.deleteEntry(entry.id);
      return l10n.razEntryDeleted;
    });
  }
}

Future<void> showRazEntryDialog(
  BuildContext context, {
  required VaultController controller,
  RazEntry? existing,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) =>
      _EntryDialog(controller: controller, existing: existing),
);

Future<void> showRazImportDialog(
  BuildContext context, {
  required VaultController controller,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => _ImportDialog(controller: controller),
);

Future<void> runRazAction(
  BuildContext context,
  Future<String> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final message = await action();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(razErrorText(error))));
  }
}

String razErrorText(Object error) => switch (error) {
  RazException(:final message) => message,
  VaultFailure(:final message) => message,
  _ => error.toString(),
};

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.controller, this.existing});

  final VaultController controller;
  final RazEntry? existing;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late final TextEditingController _title;
  late final TextEditingController _secret;
  late final TextEditingController _username;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late final TextEditingController _tags;
  late final TextEditingController _expires;
  late final TextEditingController _totpSeed;
  late final TextEditingController _totpDigits;
  late final TextEditingController _totpPeriod;
  late bool _favorite;
  late bool _reveal;
  late TotpAlgorithm _totpAlgorithm;

  /// The digits/period an edited entry already carries, or the defaults when it has none.
  ///
  /// `raz edit` does the same thing: a stored value below the minimum (a "no TOTP" entry
  /// keeps zeros) is replaced by the default rather than sent back to the validator.
  int get existingDigits =>
      (widget.existing?.totpDigits ?? 0) >= RazDefaults.minTotpDigits
      ? widget.existing!.totpDigits
      : RazDefaults.defaultTotpDigits;

  /// The period an edited entry already carries, or the default.
  int get existingPeriod =>
      (widget.existing?.totpPeriodSeconds ?? 0) >=
          RazDefaults.minTotpPeriodSeconds
      ? widget.existing!.totpPeriodSeconds
      : RazDefaults.defaultTotpPeriodSeconds;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _secret = TextEditingController(text: existing?.secret ?? '');
    _username = TextEditingController(text: existing?.username ?? '');
    _url = TextEditingController(text: existing?.url ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _tags = TextEditingController(text: existing?.tags ?? '');
    _expires = TextEditingController(text: existing?.expiresOn?.toIso() ?? '');
    _totpSeed = TextEditingController(text: existing?.totpSeed ?? '');
    _totpDigits = TextEditingController(text: '$existingDigits');
    _totpPeriod = TextEditingController(text: '$existingPeriod');
    _favorite = existing?.favorite ?? false;
    _totpAlgorithm = existing?.totpAlgorithm ?? TotpAlgorithm.none;
    _reveal = false;
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _secret,
      _username,
      _url,
      _notes,
      _tags,
      _expires,
      _totpSeed,
      _totpDigits,
      _totpPeriod,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller;
    final isNew = widget.existing == null;

    return AlertDialog(
      title: Text(isNew ? l10n.razAddEntry : l10n.razEditEntry),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('raz.field.title'),
                controller: _title,
                decoration: InputDecoration(
                  labelText: l10n.razFieldTitle,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('raz.field.secret'),
                      controller: _secret,
                      obscureText: !_reveal,
                      decoration: InputDecoration(
                        labelText: l10n.razFieldSecret,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('raz.field.reveal'),
                    onPressed: () => setState(() => _reveal = !_reveal),
                    icon: Icon(
                      _reveal ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                  IconButton(
                    key: const Key('raz.field.generate'),
                    tooltip: l10n.razGenerate,
                    onPressed: () => setState(() {
                      _secret.text = controller.generate();
                      _reveal = true;
                    }),
                    icon: const Icon(Icons.casino_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('raz.field.username'),
                controller: _username,
                decoration: InputDecoration(
                  labelText: l10n.razFieldUsername,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('raz.field.url'),
                controller: _url,
                decoration: InputDecoration(
                  labelText: l10n.razFieldUrl,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('raz.field.notes'),
                controller: _notes,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.razFieldNotes,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('raz.field.tags'),
                controller: _tags,
                decoration: InputDecoration(
                  labelText: l10n.razFieldTags,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('raz.field.expires'),
                controller: _expires,
                decoration: InputDecoration(
                  labelText: l10n.razFieldExpires,
                  hintText: 'yyyy-MM-dd',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('raz.field.totp'),
                      controller: _totpSeed,
                      decoration: InputDecoration(
                        labelText: l10n.razFieldTotpSeed,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      key: const Key('raz.field.totpDigits'),
                      controller: _totpDigits,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.razFieldTotpDigits,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      key: const Key('raz.field.totpPeriod'),
                      controller: _totpPeriod,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.razFieldTotpPeriod,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<TotpAlgorithm>(
                    key: const Key('raz.field.totpAlgorithm'),
                    value: _totpAlgorithm,
                    onChanged: (value) => setState(
                      () => _totpAlgorithm = value ?? TotpAlgorithm.none,
                    ),
                    items: [
                      for (final algorithm in TotpAlgorithm.values)
                        DropdownMenuItem(
                          value: algorithm,
                          child: Text(algorithm.name),
                        ),
                    ],
                  ),
                ],
              ),
              SwitchListTile(
                value: _favorite,
                onChanged: (value) => setState(() => _favorite = value),
                title: Text(l10n.razFieldFavorite),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('raz.field.submit'),
          onPressed: () => _submit(context),
          child: Text(isNew ? l10n.razAddEntry : l10n.commonSave),
        ),
      ],
    );
  }

  /// The digits field as a number, or null when the user left it alone.
  int? get _typedDigits => int.tryParse(_totpDigits.text.trim());

  /// The period field as a number, or null when the user left it alone.
  int? get _typedPeriod => int.tryParse(_totpPeriod.text.trim());

  Future<void> _submit(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final expires = _expires.text.trim();

    DateOnly? expiresOn;
    if (expires.isNotEmpty) {
      try {
        expiresOn = DateOnly.parseIso(expires);
      } on FormatException {
        setState(() => _expires.text = '');
        messenger.showSnackBar(SnackBar(content: Text(l10n.razInvalidDate)));
        return;
      }
    }

    final controller = widget.controller;
    final existing = widget.existing;
    try {
      if (existing == null) {
        await controller.addEntry(
          title: _title.text,
          secret: _secret.text,
          username: _username.text,
          url: _url.text,
          notes: _notes.text,
          tags: _tags.text,
          totpSeed: _totpSeed.text,
          totpAlgorithm: _totpAlgorithm,
          totpDigits: _typedDigits,
          totpPeriodSeconds: _typedPeriod,
          expiresOn: expiresOn,
          favorite: _favorite,
        );
      } else {
        await controller.updateEntry(
          existing.copyWith(
            title: _title.text,
            secret: _secret.text,
            username: _username.text,
            url: _url.text,
            notes: _notes.text,
            tags: _tags.text,
            totpSeed: _totpSeed.text,
            totpAlgorithm: _totpAlgorithm,
            totpDigits: _typedDigits ?? existingDigits,
            totpPeriodSeconds: _typedPeriod ?? existingPeriod,
            expiresOn: expiresOn,
            clearExpiresOn: expiresOn == null,
            favorite: _favorite,
          ),
        );
      }

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? l10n.razEntryAdded : l10n.razEntrySaved,
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(razErrorText(error))));
    }
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.controller});

  final VaultController controller;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _bundle = TextEditingController();

  @override
  void dispose() {
    _bundle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.razImportTitle),
      content: SizedBox(
        width: 520,
        child: TextField(
          key: razTransferFieldKey,
          controller: _bundle,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: l10n.razImportBundle,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('raz.import.submit'),
          onPressed: () async {
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            try {
              final imported = await widget.controller.importBackup(
                _bundle.text,
              );
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.razImported(imported))),
              );
            } catch (error) {
              messenger.showSnackBar(
                SnackBar(content: Text(razErrorText(error))),
              );
            }
          },
          child: Text(l10n.razImport),
        ),
      ],
    );
  }
}

String razGenerateFor(VaultController controller, [PasswordPolicy? policy]) =>
    controller.generate(policy ?? const PasswordPolicy());
