import 'package:flutter/material.dart';
import '../core/theme_constants.dart';
import '../core/color_tokens.dart';

/// The toolbox palette and Material 3 theme pair.
///
/// Seeded from Anahita's water-teal with a Ganjoor gold accent, so every service shares one
/// visual identity; features only choose semantic roles, never raw colours.
abstract final class AppTheme {
  /// Primary seed — the teal of Anahita (water) and of Persian tilework.
  static const Color seed = Color(ColorTokens.seedHex);

  /// The UI font family. Vazirmatn covers Latin *and* Persian, so switching locale never
  /// changes the typeface — and Persian text keeps correct RTL metrics instead of falling
  /// back to a font that was never designed for it.
  static const String fontFamily = 'Vazirmatn';

  /// Secondary accent — the gold of a Ganjoor coin.
  static const Color accent = Color(ColorTokens.accentHex);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      secondary: accent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        elevation: ThemeConstants.elevationAppBar,
        scrolledUnderElevation: ThemeConstants.elevationAppBarScrolled,
      ),
      cardTheme: CardThemeData(
        elevation: ThemeConstants.elevationCard,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.borderRadiusCard),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: ThemeConstants.fillAlpha),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.borderRadiusInput),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.borderRadiusInput),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.borderRadiusInput),
          borderSide: BorderSide(color: scheme.primary, width: ThemeConstants.inputBorderWidthFocused),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(ThemeConstants.borderRadiusListTile)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: ThemeConstants.dividerSpace,
        thickness: ThemeConstants.dividerThickness,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeConstants.borderRadiusSnackBar)),
      ),
    );
  }
}
