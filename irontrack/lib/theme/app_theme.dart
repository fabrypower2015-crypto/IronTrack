import 'package:flutter/material.dart';

/// Estensione sicura per gestire la trasparenza su tutte le versioni di Flutter.
extension ColorAlphaExt on Color {
  Color alphaPct(double opacity) {
    final clamped = opacity.clamp(0.0, 1.0);
    return withAlpha((clamped * 255).round());
  }
}

class AppAccentOption {
  final String id;
  final String name;
  final Color color;

  const AppAccentOption(this.id, this.name, this.color);
}

class AppTheme {
  static const List<AppAccentOption> accentOptions = [
    AppAccentOption('orange', 'Arancio Energia', Color(0xFFFF5722)),
    AppAccentOption('blue', 'Blu Elettrico', Color(0xFF2563EB)),
    AppAccentOption('emerald', 'Verde Smeraldo', Color(0xFF10B981)),
    AppAccentOption('crimson', 'Rosso Forza', Color(0xFFDC2626)),
    AppAccentOption('purple', 'Viola Titanio', Color(0xFF7C3AED)),
    AppAccentOption('amber', 'Oro Record', Color(0xFFD97706)),
    AppAccentOption('teal', 'Ottanio Tecnico', Color(0xFF0D9488)),
    AppAccentOption('slate', 'Acciaio Scuro', Color(0xFF475569)),
  ];

  static Color accentColorById(String id) {
    return accentOptions
        .firstWhere(
          (e) => e.id == id,
          orElse: () => accentOptions.first,
        )
        .color;
  }

  static ThemeData buildTheme({
    required Brightness brightness,
    required Color seedColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final scaffoldBg =
        isDark ? const Color(0xFF0E1117) : const Color(0xFFF5F7FA);
    final cardBg = isDark ? const Color(0xFF171C26) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardTheme(
        color: cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colorScheme.outlineVariant.alphaPct(isDark ? 0.25 : 0.55),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBg,
        elevation: 0,
        indicatorColor: colorScheme.primary.alphaPct(0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF202634)
            : colorScheme.surfaceContainerHighest.alphaPct(0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.alphaPct(0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.8,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.alphaPct(0.35),
        thickness: 1,
      ),
    );
  }
}