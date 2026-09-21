import 'package:flutter/material.dart';

/// When rendering store screenshots from widget tests the component text
/// styles must name a real font, otherwise the test harness draws boxes.
/// Null on devices, so runtime behaviour is unchanged.
const String? _screenshotFont =
    bool.fromEnvironment('STORE_SHOTS') ? 'Roboto' : null;

/// Brand palette: Yandex amber on deep navy.
class Brand {
  static const amber = Color(0xFFFFC107);
  static const amberDark = Color(0xFFFFB300);
  static const navy = Color(0xFF102840);
  static const navyCard = Color(0xFF1A334D);
  static const navyCardAlt = Color(0xFF223E5C);
  static const lightBg = Color(0xFFF5F6F8);
  static const lightCard = Colors.white;
  static const positive = Color(0xFF34C759);
  static const negative = Color(0xFFFF5A5F);
  static const chartLine = Color(0xFFFFC107);
  static const chartLineAlt = Color(0xFF4FC3F7);
}

ThemeData _build(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: Brand.amber,
    onPrimary: Brand.navy,
    secondary: isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0277BD),
    onSecondary: isDark ? Brand.navy : Colors.white,
    tertiary: Brand.amberDark,
    onTertiary: Brand.navy,
    error: const Color(0xFFFF6B6B),
    onError: Colors.white,
    surface: isDark ? Brand.navyCard : Brand.lightCard,
    onSurface: isDark ? Colors.white : const Color(0xFF14213D),
    surfaceContainerHighest:
        isDark ? Brand.navyCardAlt : const Color(0xFFE9ECF1),
    onSurfaceVariant:
        isDark ? const Color(0xFFB8C4D6) : const Color(0xFF5B6B82),
    outline: isDark ? const Color(0xFF3B5478) : const Color(0xFFC9D2DE),
    outlineVariant: isDark ? const Color(0xFF2B4160) : const Color(0xFFE1E6EC),
    inverseSurface: isDark ? Colors.white : Brand.navy,
    onInverseSurface: isDark ? Brand.navy : Colors.white,
  );

  final scaffoldBg = isDark ? Brand.navy : Brand.lightBg;
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: scaffoldBg,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _screenshotFont,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: Brand.amber.withValues(alpha: isDark ? 0.25 : 0.35),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color:
              states.contains(WidgetState.selected)
                  ? (isDark ? Brand.amber : Brand.navy)
                  : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: _screenshotFont,
          fontSize: 12,
          fontWeight:
              states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
          color:
              states.contains(WidgetState.selected)
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: Brand.amber.withValues(alpha: isDark ? 0.25 : 0.35),
      selectedIconTheme: IconThemeData(
        color: isDark ? Brand.amber : Brand.navy,
      ),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        fontFamily: _screenshotFont,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: _screenshotFont,
        fontSize: 12,
        color: scheme.onSurfaceVariant,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Brand.amber,
        foregroundColor: Brand.navy,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: TextStyle(
          fontFamily: _screenshotFont,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.amber,
        foregroundColor: Brand.navy,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: TextStyle(
          fontFamily: _screenshotFont,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? Brand.amber : const Color(0xFF8A6500),
        textStyle: TextStyle(
          fontFamily: _screenshotFont,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: Brand.amber,
      disabledColor: scheme.surfaceContainerHighest,
      side: BorderSide(color: scheme.outline),
      labelStyle: TextStyle(
        fontFamily: _screenshotFont,
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: _screenshotFont,
        color: Brand.navy,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: Brand.navy,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Brand.amber, width: 2),
      ),
      labelStyle: TextStyle(
        fontFamily: _screenshotFont,
        color: scheme.onSurfaceVariant,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scaffoldBg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: _screenshotFont,
        color: scheme.onInverseSurface,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Brand.navy : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Brand.amber : null,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Brand.amber,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: Brand.amber,
        selectedForegroundColor: Brand.navy,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: TextStyle(
        fontFamily: _screenshotFont,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        fontSize: 13,
      ),
      dataTextStyle: TextStyle(
        fontFamily: _screenshotFont,
        color: scheme.onSurface,
        fontSize: 13,
      ),
      headingRowColor: WidgetStateProperty.all(scheme.surfaceContainerHighest),
      dividerThickness: 0.6,
      horizontalMargin: 12,
      columnSpacing: 20,
    ),
  );
}

final ThemeData adPocketDarkTheme = _build(Brightness.dark);
final ThemeData adPocketLightTheme = _build(Brightness.light);

/// Kept for backwards compatibility.
final ThemeData adPocketTheme = adPocketDarkTheme;
