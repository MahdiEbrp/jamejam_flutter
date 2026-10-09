/// settings — see doc/settings.md and AGENTS.md
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../migration/migration_dialog.dart';
import 'setting_keys.dart';
import 'settings_controller.dart';
import 'settings_store.dart';

const Key settingsMigrateKey = Key('settings.migrate');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = context.read<SettingsController>();
      if (!controller.isLoaded) await controller.load();
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SettingsController>();

    final query = _filter.text.trim().toLowerCase();
    final entries = query.isEmpty
        ? controller.entries
        : controller.entries
              .where(
                (entry) =>
                    entry.key.toLowerCase().contains(query) ||
                    entry.value.toLowerCase().contains(query),
              )
              .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.settingsSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.commonRefresh,
              onPressed: controller.isBusy ? null : controller.load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: l10n.commonClear,
              onPressed: controller.entries.isEmpty ? null : _confirmClearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PreferencesCard(controller: controller),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.settingsTitle,
          icon: Icons.tune,
          trailing: FilledButton.tonalIcon(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.commonAdd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _filter,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.settingsSearchHint,
                  isDense: true,
                  suffixIcon: _filter.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.settingsClearFilter,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _filter.clear(),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (controller.entries.isEmpty)
                EmptyState(message: l10n.settingsEmpty, icon: Icons.tune)
              else if (entries.isEmpty)
                EmptyState(
                  message: l10n.settingsNoMatch,
                  icon: Icons.search_off,
                )
              else
                ...entries.map(
                  (entry) => _SettingTile(
                    entry: entry,
                    onEdit: () => _showAddDialog(
                      context,
                      initialKey: entry.key,
                      initialValue: entry.value,
                    ),
                    onRemove: () => _remove(context, entry.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Phase 12's migration door: a user arriving from the .NET build has files on disk
        // and nothing in this app yet. It lives here because settings is where a toolbox
        // keeps data management.
        SectionCard(
          title: l10n.migrationTitle,
          subtitle: l10n.migrationSubtitle,
          icon: Icons.move_down_outlined,
          // The button lives in the body rather than in `trailing`: a card header is one
          // `Row`, and a long localized label up there has nothing to reflow into on a phone.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: settingsMigrateKey,
                onPressed: () => showMigrationDialog(context),
                icon: const Icon(Icons.input, size: 18),
                label: Text(l10n.settingsMigrate),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.migrationNoteLocal,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, String key) async {
    final l10n = AppLocalizations.of(context);
    final controller = context.read<SettingsController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsRemoveTitle),
        content: Text(key),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.remove(key);
    if (!context.mounted) return;
    _snack(context, l10n.settingsRemoved);
  }

  Future<void> _confirmClearAll() async {
    final l10n = AppLocalizations.of(context);
    final controller = context.read<SettingsController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsClearAllTitle),
        content: Text(l10n.settingsClearAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonClear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final count = await controller.clear();
    if (!mounted) return;
    _snack(context, l10n.settingsCleared(count));
  }

  Future<void> _showAddDialog(
    BuildContext context, {
    String initialKey = '',
    String initialValue = '',
  }) async {
    final l10n = AppLocalizations.of(context);
    final controller = context.read<SettingsController>();

    // The dialog owns its controllers: Flutter disposes them when the route is fully
    // removed. Disposing them here would race the exit animation and crash on rebuild.
    final draft = await showDialog<SettingDraft>(
      context: context,
      builder: (_) => SettingEditorDialog(
        initialKey: initialKey,
        initialValue: initialValue,
      ),
    );
    if (draft == null || !context.mounted) return;

    final refusal = await controller.set(draft.key, draft.value);
    if (!context.mounted) return;
    _snack(context, refusal ?? l10n.settingsSaved, isError: refusal != null);
  }

  void _snack(BuildContext context, String message, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? scheme.errorContainer : null,
        ),
      );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: l10n.settingsTitle,
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreferenceRow(
            label: l10n.settingsTheme,
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto, size: 18),
                  tooltip: l10n.settingsThemeSystem,
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode, size: 18),
                  tooltip: l10n.settingsThemeLight,
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode, size: 18),
                  tooltip: l10n.settingsThemeDark,
                ),
              ],
              selected: {controller.themeMode},
              onSelectionChanged: (selection) =>
                  controller.setThemeMode(selection.first),
            ),
          ),
          const SizedBox(height: 12),
          _PreferenceRow(
            label: l10n.settingsLanguage,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'system',
                  icon: const Icon(Icons.language, size: 18),
                  tooltip: l10n.settingsLanguageSystem,
                ),
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'fa', label: Text('فا')),
              ],
              selected: {controller.locale?.languageCode ?? 'system'},
              onSelectionChanged: (selection) => controller.setLocale(
                selection.first == 'system' ? null : Locale(selection.first),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        child,
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.entry,
    required this.onEdit,
    required this.onRemove,
  });

  final SettingsEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        entry.key,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        entry.value.isEmpty ? '—' : entry.value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onEdit,
      trailing: IconButton(
        tooltip: AppLocalizations.of(context).commonRemove,
        icon: const Icon(Icons.close, size: 18),
        onPressed: onRemove,
      ),
    );
  }
}

class SettingDraft {
  const SettingDraft(this.key, this.value);

  final String key;
  final String value;
}

class SettingEditorDialog extends StatefulWidget {
  const SettingEditorDialog({
    this.initialKey = '',
    this.initialValue = '',
    super.key,
  });

  final String initialKey;
  final String initialValue;

  @override
  State<SettingEditorDialog> createState() => _SettingEditorDialogState();
}

class _SettingEditorDialogState extends State<SettingEditorDialog> {
  late final TextEditingController _key = TextEditingController(
    text: widget.initialKey,
  );
  late final TextEditingController _value = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settingsAddTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _key,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.settingsKeyLabel,
                hintText: SettingKeys.wellKnown.first,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _value,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(labelText: l10n.settingsValueLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(SettingDraft(_key.text.trim(), _value.text)),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
