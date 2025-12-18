import 'package:flutter/material.dart';

class AppTheme {
  // Color Palette - Deep Ocean Dark Theme
  static const Color backgroundDeepest = Color(0xFF0A0E17); // Main scaffold background
  static const Color surfaceDark = Color(0xFF111827); // Cards, Sidebar, NavigationRail
  static const Color primaryBlue = Color(0xFF2563EB); // Brand Blue
  static const Color secondaryGreen = Color(0xFF10B981); // Action Green
  static const Color textWhite = Color(0xFFFFFFFF); // Main text
  static const Color textGray = Color(0xFF9CA3AF); // Secondary text, unselected icons

  // Academic Blue color (for light theme)
  static const Color primaryColor = Color(0xFF1E3A8A);

  // Light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      primaryColor: primaryColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Dark theme configuration - Deep Ocean Dark Theme
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: primaryBlue,
      onPrimary: Colors.white,
      secondary: secondaryGreen,
      onSecondary: Colors.white,
      background: backgroundDeepest,
      surface: surfaceDark,
      onSurface: textWhite,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundDeepest,
      
      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDeepest,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textWhite),
      ),

      // NavigationRail Theme
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceDark,
        selectedIconTheme: const IconThemeData(color: primaryBlue),
        unselectedIconTheme: const IconThemeData(color: textGray),
        selectedLabelTextStyle: const TextStyle(color: primaryBlue),
        unselectedLabelTextStyle: const TextStyle(color: textGray),
        indicatorColor: Colors.transparent,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),

      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),

      // InputDecoration Theme (for Search Bar)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textGray),
        prefixIconColor: textGray,
      ),

      // Text Theme
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: textWhite),
        titleMedium: TextStyle(
          color: textWhite,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

