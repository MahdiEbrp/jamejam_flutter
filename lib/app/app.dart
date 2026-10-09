import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/settings/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_shell.dart';
import 'app_theme.dart';

/// The root widget: locale, theme, and the shell.
///
/// Theme and locale are read from the settings store, so a user who switches to Persian in
/// the settings screen comes back to a Persian, right-to-left app after a restart — the
/// preference is a real setting, not a runtime flag.
class JameJamApp extends StatelessWidget {
  const JameJamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: settings.locale,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const AppShell(),
    );
  }
}
