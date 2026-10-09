/// soroush — see doc/soroush.md and AGENTS.md
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../settings/setting_keys.dart';
import '../settings/settings_controller.dart';
import 'soroush_controller.dart';
import 'soroush_registry.dart';

const Key promptFieldKey = ValueKey('soroush.promptField');

const Key apiKeyFieldKey = ValueKey('soroush.apiKeyField');

class SoroushPage extends StatefulWidget {
  const SoroushPage({super.key});

  @override
  State<SoroushPage> createState() => _SoroushPageState();
}

class _SoroushPageState extends State<SoroushPage> {
  final TextEditingController _prompt = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<SoroushController>().refreshKeyState();
    });
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SoroushController>();
    final history = controller.history;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.soroushSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const _ApiKeyCard(),
        const SizedBox(height: 16),
        _PromptCard(controller: _prompt, sending: controller.isSending),
        const SizedBox(height: 16),
        if (history.isEmpty)
          SectionCard(
            title: l10n.soroushHistory,
            icon: Icons.history,
            child: EmptyState(
              message: l10n.soroushHistoryEmpty,
              icon: Icons.history,
            ),
          )
        else
          SectionCard(
            title: l10n.soroushHistory,
            icon: Icons.history,
            trailing: IconButton(
              tooltip: l10n.soroushClearHistory,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              onPressed: () {
                controller.clearHistory();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(l10n.soroushHistoryCleared)),
                  );
              },
            ),
            child: Column(
              children: [
                for (final record in history) _HistoryTile(record: record),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const _ProviderCard(),
      ],
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.controller, required this.sending});

  final TextEditingController controller;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final soroush = context.read<SoroushController>();

    return SectionCard(
      title: l10n.soroushSend,
      icon: Icons.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: promptFieldKey,
            controller: controller,
            minLines: 2,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: l10n.soroushPromptHint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _send(context, soroush),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: sending ? null : () => _send(context, soroush),
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(l10n.soroushSend),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _send(BuildContext context, SoroushController soroush) async {
    final prompt = controller.text.trim();
    if (prompt.isEmpty || soroush.isSending) return;
    await soroush.send(prompt);
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final AiCallRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = record.result;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                record.isSuccess ? Icons.person_outline : Icons.error_outline,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  record.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              record.error ?? result?.content ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: record.isSuccess ? null : theme.colorScheme.error,
              ),
            ),
          ),
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.soroushMeta(
                  result.provider,
                  result.model ?? '—',
                  result.attempts,
                  result.duration.inMilliseconds,
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<SettingsController>();

    final providerName =
        settings.value(SettingKeys.soroushProvider) ??
        SoroushProviders.openAiCompatible;
    final provider = SoroushProviders.resolve(providerName);
    final endpoint =
        settings.value(SettingKeys.soroushEndpoint) ?? provider.defaultEndpoint;
    final model =
        settings.value(SettingKeys.soroushModel) ?? provider.defaultModel;

    return SectionCard(
      title: l10n.soroushProviders,
      subtitle: l10n.soroushApiKeyHint,
      icon: Icons.cloud_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: SoroushProviders.canonical.contains(providerName)
                ? providerName
                : SoroushProviders.openAiCompatible,
            decoration: InputDecoration(labelText: l10n.soroushProvider),
            items: [
              for (final name in SoroushProviders.canonical)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) async {
              if (value == null) return;
              await settings.set(SettingKeys.soroushProvider, value);
            },
          ),
          const SizedBox(height: 12),
          _InlineTextSetting(
            label: l10n.soroushModel,
            keyName: SettingKeys.soroushModel,
            fallback: model,
          ),
          const SizedBox(height: 12),
          _InlineTextSetting(
            label: l10n.soroushEndpoint,
            keyName: SettingKeys.soroushEndpoint,
            fallback: endpoint,
          ),
        ],
      ),
    );
  }
}

class _InlineTextSetting extends StatefulWidget {
  const _InlineTextSetting({
    required this.label,
    required this.keyName,
    required this.fallback,
  });

  final String label;
  final String keyName;
  final String fallback;

  @override
  State<_InlineTextSetting> createState() => _InlineTextSettingState();
}

class _InlineTextSettingState extends State<_InlineTextSetting> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.fallback,
  );

  @override
  void didUpdateWidget(covariant _InlineTextSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fallback != oldWidget.fallback &&
        _controller.text.trim() != widget.fallback) {
      _controller.text = widget.fallback;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: l10n.commonSave,
          icon: const Icon(Icons.check, size: 18),
          onPressed: () => context.read<SettingsController>().set(
            widget.keyName,
            _controller.text.trim(),
          ),
        ),
      ),
      onSubmitted: (value) =>
          context.read<SettingsController>().set(widget.keyName, value.trim()),
    );
  }
}

class _ApiKeyCard extends StatefulWidget {
  const _ApiKeyCard();

  @override
  State<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<_ApiKeyCard> {
  final TextEditingController _key = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SoroushController>();

    return SectionCard(
      title: l10n.soroushApiKey,
      subtitle: l10n.soroushApiKeyHint,
      icon: Icons.key_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: apiKeyFieldKey,
                  controller: _key,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: 'sk-…',
                    suffixIcon: IconButton(
                      tooltip: _obscure
                          ? l10n.soroushShowKey
                          : l10n.soroushHideKey,
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final error = await controller.saveApiKey(_key.text);
                  _key.clear();
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(error ?? l10n.soroushApiKeySaved)),
                    );
                },
                child: Text(l10n.commonSave),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.commonRemove,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await controller.clearApiKey();
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(l10n.soroushApiKeyCleared)),
                    );
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatusChip(
            label: controller.hasKey
                ? l10n.soroushKeyConfigured(controller.apiKeyMasked)
                : l10n.soroushKeyMissing,
            icon: controller.hasKey
                ? Icons.check_circle_outline
                : Icons.info_outline,
            color: controller.hasKey
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }
}
