import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/anahita/weather_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/divan/divan_page.dart';
import '../features/ganjoor/ganjoor_page.dart';
import '../features/greeter/greeter_page.dart';
import '../features/haftkhan/haftkhan_page.dart';
import '../features/raz/raz_page.dart';
import '../features/settings/settings_page.dart';
import '../features/soroush/soroush_page.dart';
import '../features/sync/sync_page.dart';
import '../features/taqvim/taqvim_page.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_navigation.dart';

/// One entry in the shell's navigation, pairing a route id with its screen.
class AppDestination {
  const AppDestination({
    required this.id,
    required this.icon,
    required this.label,
    required this.builder,
    this.ready = true,
  });

  /// Stable route id (also used by the dashboard tiles).
  final String id;

  /// Rail / drawer icon.
  final IconData icon;

  /// Localized label.
  final String Function(AppLocalizations l10n) label;

  /// Builds the screen body (the shell owns the Scaffold and AppBar).
  final Widget Function() builder;

  /// False for steps that are catalogued but not implemented yet.
  final bool ready;
}

/// The application shell: one Scaffold, responsive navigation, and the nine steps.
///
/// Wide layouts get a `NavigationRail`; narrow ones get a drawer. Both render the same
/// destination list and both are laid out automatically right-to-left in Persian, because
/// directionality comes from the locale rather than from hard-coded alignment.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  /// Every destination, in navigation order.
  static List<AppDestination> destinations() => [
    AppDestination(
      id: 'dashboard',
      icon: Icons.home_outlined,
      label: (l10n) => l10n.navDashboard,
      builder: () => const DashboardPage(),
    ),
    AppDestination(
      id: 'greeter',
      icon: Icons.waving_hand_outlined,
      label: (l10n) => l10n.greeterTitle,
      builder: () => const GreeterPage(),
    ),
    AppDestination(
      id: 'haftkhan',
      icon: Icons.checklist_rtl,
      label: (l10n) => l10n.navHaftKhan,
      builder: () => const HaftKhanPage(),
    ),
    AppDestination(
      id: 'anahita',
      icon: Icons.wb_sunny_outlined,
      label: (l10n) => l10n.navAnahita,
      builder: () => const AnahitaPage(),
    ),
    AppDestination(
      id: 'ganjoor',
      icon: Icons.account_balance_wallet_outlined,
      label: (l10n) => l10n.navGanjoor,
      builder: () => const GanjoorPage(),
    ),
    AppDestination(
      id: 'raz',
      icon: Icons.lock_outline,
      label: (l10n) => l10n.navRaz,
      builder: () => const RazPage(),
    ),
    AppDestination(
      id: 'divan',
      icon: Icons.menu_book_outlined,
      label: (l10n) => l10n.navDivan,
      builder: () => const DivanPage(),
    ),
    AppDestination(
      id: 'sync',
      icon: Icons.sync,
      label: (l10n) => l10n.navSync,
      builder: () => const SyncPage(),
    ),
    AppDestination(
      id: 'taqvim',
      icon: Icons.calendar_month_outlined,
      label: (l10n) => l10n.navTaqvim,
      builder: () => const TaqvimPage(),
    ),
    AppDestination(
      id: 'soroush',
      icon: Icons.auto_awesome,
      label: (l10n) => l10n.soroushTitle,
      builder: () => const SoroushPage(),
    ),
    AppDestination(
      id: 'settings',
      icon: Icons.tune,
      label: (l10n) => l10n.settingsTitle,
      builder: () => const SettingsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigation = context.watch<AppNavigation>();
    final destinations = AppShell.destinations();

    var index = destinations.indexWhere((d) => d.id == navigation.current);
    if (index < 0) index = 0;
    final destination = destinations[index];
    final body = destination.builder();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final title = destination.label(l10n);

        if (!wide) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            drawer: Drawer(
              child: SafeArea(
                child: _NavigationList(
                  destinations: destinations,
                  selectedIndex: index,
                  l10n: l10n,
                  onSelected: (selected) {
                    Navigator.of(context).pop();
                    navigation.open(selected.id);
                  },
                ),
              ),
            ),
            body: body,
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _Rail(
                destinations: destinations,
                selectedIndex: index,
                l10n: l10n,
                extended: constraints.maxWidth >= 1240,
                onSelected: (selected) => navigation.open(selected.id),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Scaffold(
                  appBar: AppBar(title: Text(title)),
                  body: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.destinations,
    required this.selectedIndex,
    required this.l10n,
    required this.extended,
    required this.onSelected,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final AppLocalizations l10n;
  final bool extended;
  final ValueChanged<AppDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: extended,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => onSelected(destinations[index]),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Icon(
          Icons.grid_view_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            label: Text(destination.label(l10n)),
          ),
      ],
    );
  }
}

class _NavigationList extends StatelessWidget {
  const _NavigationList({
    required this.destinations,
    required this.selectedIndex,
    required this.l10n,
    required this.onSelected,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final AppLocalizations l10n;
  final ValueChanged<AppDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Icon(
                Icons.grid_view_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        for (var i = 0; i < destinations.length; i++)
          ListTile(
            selected: i == selectedIndex,
            leading: Icon(destinations[i].icon),
            title: Text(destinations[i].label(l10n)),
            trailing: destinations[i].ready
                ? null
                : Icon(
                    Icons.schedule,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
            onTap: () => onSelected(destinations[i]),
          ),
      ],
    );
  }
}
