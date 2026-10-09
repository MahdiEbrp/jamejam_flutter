/// dashboard — see doc/dashboard.md and AGENTS.md
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

enum StepStatus {
  /// Implemented and usable.
  ready,

  /// Scheduled for a later phase of the conversion.
  planned,
}

class ToolboxStep {
  const ToolboxStep({
    required this.number,
    required this.id,
    required this.icon,
    required this.name,
    required this.status,
  });

  /// Step number in the original toolbox (1…10).
  final int number;

  /// Stable route id used by the app shell.
  final String id;

  /// Icon shown on the tile.
  final IconData icon;

  /// Localized name.
  final String Function(AppLocalizations l10n) name;

  /// Where this step stands.
  final StepStatus status;

  /// True when the shell can navigate to it.
  bool get isReady => status == StepStatus.ready;

  /// The full catalog, in step order.
  static List<ToolboxStep> all() => [
    ToolboxStep(
      number: 1,
      id: 'greeter',
      icon: Icons.waving_hand_outlined,
      name: (l10n) => l10n.greeterTitle,
      status: StepStatus.ready,
    ),
    ToolboxStep(
      number: 2,
      id: 'soroush',
      icon: Icons.auto_awesome,
      name: (l10n) => l10n.soroushTitle,
      status: StepStatus.ready,
    ),
    ToolboxStep(
      number: 3,
      id: 'settings',
      icon: Icons.tune,
      name: (l10n) => l10n.settingsTitle,
      status: StepStatus.ready,
    ),
    ToolboxStep(
      number: 4,
      id: 'haftkhan',
      icon: Icons.checklist_rtl,
      name: (l10n) => l10n.navHaftKhan,
      status: StepStatus.ready,
    ),
    ToolboxStep(
      number: 5,
      id: 'anahita',
      icon: Icons.wb_sunny_outlined,
      name: (l10n) => l10n.navAnahita,
      status: StepStatus.ready,
    ),
    ToolboxStep(
      number: 6,
      id: 'ganjoor',
      icon: Icons.account_balance_wallet_outlined,
      name: (l10n) => l10n.navGanjoor,
      status: StepStatus.ready,
    ),
    ToolboxStep(
      number: 7,
      id: 'raz',
      icon: Icons.lock_outline,
      name: (l10n) => l10n.navRaz,
      status: StepStatus.ready,
    ),
    ToolboxStep(
      number: 8,
      id: 'divan',
      icon: Icons.menu_book_outlined,
      name: (l10n) => l10n.navDivan,
      status: StepStatus.ready,
    ),
    ToolboxStep(
      number: 9,
      id: 'sync',
      icon: Icons.sync,
      name: (l10n) => l10n.navSync,
      status: StepStatus.ready,
    ),
    ToolboxStep(
      number: 10,
      id: 'taqvim',
      icon: Icons.calendar_month_outlined,
      name: (l10n) => l10n.navTaqvim,
      status: StepStatus.ready,
    ),
  ];

  /// How many steps are implemented in this build.
  static int readyCount() => all().where((step) => step.isReady).length;
}
