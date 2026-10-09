/// dashboard — see doc/dashboard.md and AGENTS.md
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_navigation.dart';
import '../../core/fa_format.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import 'toolbox_catalog.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = ToolboxStep.all();
    final ready = ToolboxStep.readyCount();
    final navigation = context.read<AppNavigation>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // A `Wrap` rather than a `Row`: at a large text scale on a phone the progress badge
        // has to fall onto its own line instead of pushing the title past the viewport.
        // `test/app/accessibility_test.dart` pins the result at 1.0, 1.3 and 1.6.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Icon(Icons.grid_view_rounded, color: theme.colorScheme.primary),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dashboardWelcome,
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    l10n.appTagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            StatusChip(
              label: FaFormat.at(
                l10n.localeName,
                l10n.dashboardProgress(ready, steps.length),
              ),
              icon: Icons.trending_up,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 620
                ? 3
                : constraints.maxWidth > 400
                ? 2
                : 1;
            // A labelled region: a screen reader announces "the toolbox steps" once and
            // then reads the tiles, instead of landing on nine anonymous buttons.
            return Semantics(
              label: l10n.a11yToolboxGrid,
              container: true,
              explicitChildNodes: true,
              child: GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  for (final step in steps)
                    _StepTile(
                      step: step,
                      onTap: step.isReady
                          ? () => navigation.open(step.id)
                          : null,
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.appTitle,
          icon: Icons.info_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.settingsSubtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                l10n.appTagline,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, this.onTap});

  final ToolboxStep step;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    step.icon,
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  const Spacer(),
                  StatusChip(
                    label: enabled
                        ? l10n.dashboardReady
                        : l10n.dashboardPlanned,
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                FaFormat.at(l10n.localeName, l10n.dashboardStep(step.number)),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                step.name(l10n),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
