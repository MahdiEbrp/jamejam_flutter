/// sync — see doc/sync.md and AGENTS.md
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../widgets/adaptive_layout.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import 'sync_controller.dart';
import 'sync_models.dart';

const Key syncDeviceNameKey = Key('sync.device.name');

const Key syncDeviceSaveKey = Key('sync.device.save');

const Key syncDeviceIdKey = Key('sync.device.id');

const Key syncClearFeedbackKey = Key('sync.feedback.clear');

Key syncUrlFieldKey(String id) => Key('sync.$id.url');

Key syncSaveUrlKey(String id) => Key('sync.$id.save');

Key syncModeKey(String id) => Key('sync.$id.mode');

Key syncRunKey(String id) => Key('sync.$id.run');

Key syncReportKey(String id) => Key('sync.$id.report');

Key syncTargetKey(String id) => Key('sync.$id.card');

const Key syncConfirmPushKey = Key('sync.confirm.push');

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final Map<String, TextEditingController> _urls = {};
  final Map<String, SyncMode> _modes = {};
  final TextEditingController _deviceName = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    for (final controller in _urls.values) {
      controller.dispose();
    }
    _deviceName.dispose();
    super.dispose();
  }

  /// Seeds the fields from the controller once the identity has been read.
  ///
  /// The controllers are page-owned and pushed into the fields on every rebuild: a
  /// `TextFormField(initialValue:)` would swallow typed text as soon as the controller
  /// notified, which is exactly the bug the earlier phases hit.
  void _seed(SyncController controller) {
    if (_seeded) return;
    _seeded = true;
    _deviceName.text = controller.deviceName;
    for (final target in controller.targets) {
      _urls[target.id] = TextEditingController(
        text: controller.effectiveUrlFor(target.id),
      );
      _modes[target.id] = SyncMode.merge;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SyncController>();
    _seed(controller);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.syncTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(l10n.syncIntro, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (controller.error != null)
          _Feedback(
            key: const Key('sync.feedback.error'),
            message: controller.error!,
            icon: Icons.error_outline,
            tone: Theme.of(context).colorScheme.error,
          ),
        if (controller.message != null)
          _Feedback(
            key: const Key('sync.feedback.message'),
            message: controller.message!,
            icon: Icons.check_circle_outline,
            tone: Theme.of(context).colorScheme.primary,
            onClear: controller.clearFeedback,
            clearKey: syncClearFeedbackKey,
            clearLabel: l10n.syncDismiss,
          ),
        const SizedBox(height: 8),
        _deviceCard(context, l10n, controller),
        const SizedBox(height: 12),
        for (final target in controller.targets) ...[
          _targetCard(context, l10n, controller, target.id, target.settingKey),
          const SizedBox(height: 12),
        ],
        _rulesCard(context, l10n, controller),
      ],
    );
  }

  // ── This device ──

  Widget _deviceCard(
    BuildContext context,
    AppLocalizations l10n,
    SyncController controller,
  ) {
    final theme = Theme.of(context);
    return SectionCard(
      title: l10n.syncDeviceTitle,
      subtitle: l10n.syncDeviceHint,
      icon: Icons.phonelink_lock_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldActionFlow(
            field: TextField(
              key: syncDeviceNameKey,
              controller: _deviceName,
              decoration: InputDecoration(
                labelText: l10n.syncDeviceName,
                isDense: true,
              ),
            ),
            actions: [
              FilledButton.tonal(
                key: syncDeviceSaveKey,
                onPressed: controller.busy
                    ? null
                    : () => _flash(
                        () => controller.saveDeviceName(_deviceName.text),
                      ),
                child: Text(l10n.syncSave),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.syncDeviceId, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          SelectableText(
            controller.hasIdentity ? controller.deviceId : '—',
            key: syncDeviceIdKey,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          if (!controller.hasIdentity)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l10n.syncDeviceIdPending,
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          StatusChip(
            label: controller.hasToken
                ? l10n.syncTokenSet
                : l10n.syncTokenMissing,
            color: controller.hasToken
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            icon: controller.hasToken
                ? Icons.key_outlined
                : Icons.key_off_outlined,
          ),
        ],
      ),
    );
  }

  // ── One service ──

  Widget _targetCard(
    BuildContext context,
    AppLocalizations l10n,
    SyncController controller,
    String id,
    String settingKey,
  ) {
    final theme = Theme.of(context);
    final outcome = controller.outcomeFor(id);
    final mode = _modes[id] ?? SyncMode.merge;

    return SectionCard(
      key: syncTargetKey(id),
      title: _titleFor(context, id),
      subtitle: l10n.syncServiceTag(id, settingKey),
      icon: Icons.sync_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: syncUrlFieldKey(id),
            controller: _urls[id],
            decoration: InputDecoration(
              labelText: l10n.syncUrl,
              hintText: 'https://…',
              helperText: controller.environmentOverrides
                  ? l10n.syncEnvOverride(controller.environmentUrl)
                  : null,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          FieldActionFlow(
            field: DropdownButtonFormField<SyncMode>(
              key: syncModeKey(id),
              initialValue: mode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.syncMode,
                isDense: true,
              ),
              items: [
                for (final value in SyncMode.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(_modeLabel(l10n, value)),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _modes[id] = value ?? SyncMode.merge),
            ),
            actions: [
              OutlinedButton(
                key: syncSaveUrlKey(id),
                onPressed: controller.busy
                    ? null
                    : () => _flash(
                        () => controller.saveUrl(id, _urls[id]?.text ?? ''),
                      ),
                child: Text(l10n.syncSaveUrl),
              ),
              FilledButton.icon(
                key: syncRunKey(id),
                onPressed: controller.busy ? null : () => _run(controller, id),
                icon: const Icon(Icons.sync, size: 18),
                label: Text(l10n.syncRun),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_modeHint(l10n, mode), style: theme.textTheme.bodySmall),
          if (outcome != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                StatusChip(
                  label: _modeLabel(l10n, outcome.mode),
                  color: theme.colorScheme.primary,
                  icon: outcome.firstSync
                      ? Icons.auto_mode
                      : Icons.check_circle_outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    outcome.summary,
                    key: syncReportKey(id),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── The rules the protocol keeps ──

  Widget _rulesCard(
    BuildContext context,
    AppLocalizations l10n,
    SyncController controller,
  ) {
    final theme = Theme.of(context);
    return SectionCard(
      title: l10n.syncRulesTitle,
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rule(Icons.lock_outline, l10n.syncRuleHttps),
          _rule(Icons.key_outlined, l10n.syncRuleToken),
          _rule(Icons.merge_type, l10n.syncRuleConverge),
          _rule(Icons.extension_outlined, l10n.syncRuleRaz),
          const SizedBox(height: 4),
          Text(
            l10n.syncProtocol,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _rule(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );

  // ── Behaviour ──

  /// Runs one exchange, asking before a push would overwrite a differing remote.
  Future<void> _run(SyncController controller, String id) async {
    final mode = _modes[id] ?? SyncMode.merge;
    // The field doubles as the CLI's `--url`: whatever it holds is what this run uses, and
    // "Save URL" is what makes it outlive the run.
    await _flash(
      () => controller.run(id, mode: mode, url: _urls[id]?.text ?? ''),
    );
    if (!mounted) return;

    final error = controller.error;
    if (error == null || mode != SyncMode.push) return;
    // Both wordings exist in the ported services: the engine says "Pushing replaces them",
    // the task store says "pushing replaces them" — the rule is the same one.
    if (!error.toLowerCase().contains('pushing replaces them')) return;

    // The CLI's `--force`, as a question: the same gate, answered before the write.
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syncOverwriteTitle),
        content: Text(error, key: syncConfirmPushKey),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.syncCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.syncOverwrite),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _flash(
      () => controller.run(
        id,
        mode: mode,
        force: true,
        url: _urls[id]?.text ?? '',
      ),
    );
  }

  /// Runs an action and surfaces the controller's own line in a snack bar.
  Future<void> _flash(Future<void> Function() action) async {
    final controller = context.read<SyncController>();
    final messenger = ScaffoldMessenger.of(context);
    await action();
    if (!mounted) return;
    final message = controller.error == null ? controller.message : null;
    if (message == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _titleFor(BuildContext context, String id) {
    final controller = context.read<SyncController>();
    for (final target in controller.targets) {
      if (target.id == id) return target.title(AppLocalizations.of(context));
    }
    return id;
  }

  static String _modeLabel(AppLocalizations l10n, SyncMode mode) =>
      switch (mode) {
        SyncMode.merge => l10n.syncModeMerge,
        SyncMode.pull => l10n.syncModePull,
        SyncMode.push => l10n.syncModePush,
      };

  static String _modeHint(AppLocalizations l10n, SyncMode mode) =>
      switch (mode) {
        SyncMode.merge => l10n.syncModeMergeHint,
        SyncMode.pull => l10n.syncModePullHint,
        SyncMode.push => l10n.syncModePushHint,
      };
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.message,
    required this.icon,
    required this.tone,
    this.onClear,
    this.clearKey,
    this.clearLabel,
    super.key,
  });

  final String message;
  final IconData icon;
  final Color tone;
  final VoidCallback? onClear;
  final Key? clearKey;
  final String? clearLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          if (onClear != null)
            TextButton(
              key: clearKey,
              onPressed: onClear,
              child: Text(clearLabel ?? ''),
            ),
        ],
      ),
    );
  }
}
