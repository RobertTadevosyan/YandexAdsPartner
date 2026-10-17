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

/// Provider accent colours. Yandex accounts keep AdPocket's original amber
/// and navy; AdMob accounts use Google's red, orange and blue. Only accent
/// roles change; backgrounds and text colours are shared.
@immutable
class BrandPalette extends ThemeExtension<BrandPalette> {
  /// Hero surfaces: the big Overview card, highlighted tiles, lock badge.
  final Color heroStart;
  final Color heroEnd;

  /// Text and icons on hero surfaces.
  final Color onHero;

  /// Buttons, selected chips, indicators, badges.
  final Color primary;
  final Color onPrimary;

  /// Selected navigation icon and text buttons, per brightness.
  final Color primaryOnLight;
  final Color primaryOnDark;
  final Color linkOnLight;
  final Color linkOnDark;

  final Color chartLine;
  final Color chartLineAlt;
  final Color positive;
  final Color negative;

  const BrandPalette({
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
    required this.primary,
    required this.onPrimary,
    required this.primaryOnLight,
    required this.primaryOnDark,
    required this.linkOnLight,
    required this.linkOnDark,
    required this.chartLine,
    required this.chartLineAlt,
    required this.positive,
    required this.negative,
  });

  static const yandex = BrandPalette(
    heroStart: Brand.amber,
    heroEnd: Brand.amberDark,
    onHero: Brand.navy,
    primary: Brand.amber,
    onPrimary: Brand.navy,
    primaryOnLight: Brand.navy,
    primaryOnDark: Brand.amber,
    linkOnLight: Color(0xFF8A6500),
    linkOnDark: Brand.amber,
    chartLine: Brand.chartLine,
    chartLineAlt: Brand.chartLineAlt,
    positive: Brand.positive,
    negative: Brand.negative,
  );

  /// Google colours as used across AdMob: red and orange for the hero, blue
  /// for actions and charts, green and red for changes.
  static const admob = BrandPalette(
    heroStart: Color(0xFFD93025),
    heroEnd: Color(0xFFF57C00),
    onHero: Colors.white,
    primary: Color(0xFF1A73E8),
    onPrimary: Colors.white,
    primaryOnLight: Color(0xFF1A73E8),
    primaryOnDark: Color(0xFF8AB4F8),
    linkOnLight: Color(0xFF1A73E8),
    linkOnDark: Color(0xFF8AB4F8),
    chartLine: Color(0xFF4285F4),
    chartLineAlt: Color(0xFFF57C00),
    positive: Color(0xFF34A853),
    negative: Color(0xFFEA4335),
  );

  static BrandPalette of(BuildContext context) =>
      Theme.of(context).extension<BrandPalette>() ?? yandex;

  @override
  BrandPalette copyWith() => this;

  @override
  BrandPalette lerp(ThemeExtension<BrandPalette>? other, double t) =>
      t < 0.5 || other is! BrandPalette ? this : other;
}

ThemeData _build(
  Brightness brightness, [
  BrandPalette p = BrandPalette.yandex,
]) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0277BD),
    onSecondary: isDark ? Brand.navy : Colors.white,
    tertiary: p.heroEnd,
    onTertiary: p.onHero,
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
    extensions: [p],
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
      indicatorColor: p.primary.withValues(alpha: isDark ? 0.25 : 0.35),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color:
              states.contains(WidgetState.selected)
                  ? (isDark ? p.primaryOnDark : p.primaryOnLight)
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
      indicatorColor: p.primary.withValues(alpha: isDark ? 0.25 : 0.35),
      selectedIconTheme: IconThemeData(
        color: isDark ? p.primaryOnDark : p.primaryOnLight,
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
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
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
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
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
        foregroundColor: isDark ? p.linkOnDark : p.linkOnLight,
        textStyle: TextStyle(
          fontFamily: _screenshotFont,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: p.primary,
      disabledColor: scheme.surfaceContainerHighest,
      side: BorderSide(color: scheme.outline),
      labelStyle: TextStyle(
        fontFamily: _screenshotFont,
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: _screenshotFont,
        color: p.onPrimary,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: p.onPrimary,
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
        borderSide: BorderSide(color: p.primary, width: 2),
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
        (s) => s.contains(WidgetState.selected) ? p.onPrimary : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : null,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: p.primary,
        selectedForegroundColor: p.onPrimary,
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
final ThemeData adMobDarkTheme = _build(Brightness.dark, BrandPalette.admob);
final ThemeData adMobLightTheme = _build(Brightness.light, BrandPalette.admob);

/// Kept for backwards compatibility.
final ThemeData adPocketTheme = adPocketDarkTheme;
