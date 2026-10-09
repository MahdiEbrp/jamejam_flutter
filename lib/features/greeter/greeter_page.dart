/// greeter — see doc/greeter.md and AGENTS.md
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../widgets/section_card.dart';
import 'greeter_controller.dart';

class GreeterPage extends StatefulWidget {
  const GreeterPage({super.key});

  @override
  State<GreeterPage> createState() => _GreeterPageState();
}

class _GreeterPageState extends State<GreeterPage> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<GreeterController>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.greeterSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.greeterNameLabel,
          icon: Icons.badge_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  hintText: l10n.greeterNameHint,
                  helperText: controller.defaultName.isEmpty
                      ? null
                      : '${l10n.greeterDefaultName}: ${controller.defaultName}',
                ),
                onSubmitted: (_) => controller.greetLocally(_name.text),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => controller.greetLocally(_name.text),
                      icon: const Icon(Icons.waving_hand_outlined, size: 18),
                      label: Text(l10n.greeterGreet),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => controller.greetWithAi(_name.text),
                      icon: controller.busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(l10n.greeterAiGreet),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await controller.saveDefaultName(_name.text);
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(l10n.greeterDefaultNameSaved)),
                    );
                },
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text('${l10n.commonSave} · ${l10n.greeterDefaultName}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (controller.error != null)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      controller.error!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (controller.greeting.isNotEmpty)
          SectionCard(
            title: controller.lastWasAi
                ? l10n.greeterAiGreet
                : l10n.greeterGreet,
            icon: controller.lastWasAi
                ? Icons.auto_awesome
                : Icons.chat_bubble_outline,
            trailing: IconButton(
              tooltip: l10n.commonCopy,
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(
                  ClipboardData(text: controller.greeting),
                );
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l10n.commonCopied)));
              },
            ),
            child: SelectableText(
              controller.greeting,
              style: theme.textTheme.headlineSmall,
            ),
          ),
      ],
    );
  }
}
