// This file includes all 7 common UI design style themes as Flutter ColorScheme and ThemeData

import 'package:flutter/material.dart';

final ColorScheme yaAdsPartnerColorScheme = const ColorScheme(
  brightness: Brightness.light,

  // Branding
  primary: Color(0xFFFFC107),              // Golden yellow (used for chart/symbol)
  onPrimary: Color(0xFF102840),            // Deep navy for contrast

  // Secondary (accent or lighter yellow)
  secondary: Color(0xFFFFD54F),            // Light amber
  onSecondary: Color(0xFF102840),          // Deep navy again

  // Backgrounds
  // ignore: deprecated_member_use
  background: Color(0xFF102840),     
  // ignore: deprecated_member_use      // Navy blue
  onBackground: Colors.white,              // High contrast

  surface: Color(0xFF1A334D),              // Slightly lighter navy for cards
  onSurface: Colors.white,

  // Error
  error: Color(0xFFD32F2F),
  onError: Colors.white,

  // Tertiary (optional: orange-tinted yellow for CTA highlights)
  tertiary: Color(0xFFFFB300),
  onTertiary: Color(0xFF102840),
);

final ThemeData yaAdsPartnerTheme = ThemeData(
  colorScheme: yaAdsPartnerColorScheme,
  useMaterial3: true,
  // ignore: deprecated_member_use
  scaffoldBackgroundColor: yaAdsPartnerColorScheme.background,

  appBarTheme: AppBarTheme(
    backgroundColor: yaAdsPartnerColorScheme.primary,
    foregroundColor: yaAdsPartnerColorScheme.onPrimary,
    elevation: 2,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: yaAdsPartnerColorScheme.onPrimary,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: yaAdsPartnerColorScheme.primary,
      foregroundColor: yaAdsPartnerColorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),

  chipTheme: ChipThemeData(
    backgroundColor: yaAdsPartnerColorScheme.surface,
    selectedColor: yaAdsPartnerColorScheme.primary,
    disabledColor: Colors.grey.shade300,
    labelStyle: TextStyle(
      color: yaAdsPartnerColorScheme.onSurface,
      fontWeight: FontWeight.w500,
    ),
    secondaryLabelStyle: TextStyle(
      color: yaAdsPartnerColorScheme.onPrimary,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    brightness: Brightness.light,
  ),
);

