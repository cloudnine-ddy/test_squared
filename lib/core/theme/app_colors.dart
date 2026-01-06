import 'package:flutter/material.dart';

/// Centralized color configuration for TestSquared
///
/// To change the entire app's color theme, simply modify the three
/// primary colors below and the entire app will update accordingly.
class AppColors {
  // ============================================================
  // PRIMARY COLOR PALETTE
  // Change these three colors to update the entire app theme
  // ============================================================

  /// Primary color - Navy Blue
  /// Used for: Headers, primary text, main CTAs
  static const Color primary = Color(0xFF203655);

  /// Background color - Cream
  /// Used for: Main backgrounds, light sections
  static const Color background = Color(0xFFF6F1E5);

  /// Accent color - Tan/Beige
  /// Used for: Cards, secondary sections, highlights
  static const Color accent = Color(0xFFC9B896);

  // ============================================================
  // DERIVED COLORS (automatically generated from primary palette)
  // ============================================================

  /// Lighter shade of primary (for hover states, borders)
  static const Color primaryLight = Color(0xFF2D4D7C);

  /// Darker shade of primary (for pressed states, dark text)
  static const Color primaryDark = Color(0xFF162538);

  /// Very light accent (for subtle backgrounds)
  static const Color accentLight = Color(0xFFE5DBC9);

  /// Darker accent (for borders, text on light backgrounds)
  static const Color accentDark = Color(0xFFB5A479);

  // ============================================================
  // SEMANTIC COLORS
  // ============================================================

  /// Main text color
  static const Color textPrimary = Color(0xFF203655);

  /// Secondary text color (lighter, for descriptions)
  static const Color textSecondary = Color(0xFF5A6B82);

  /// Text on dark backgrounds
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Success color (for positive actions, achievements)
  static const Color success = Color(0xFF10B981);

  /// Warning color (for cautions, important notices)
  static const Color warning = Color(0xFFF59E0B);

  /// Error color (for errors, destructive actions)
  static const Color error = Color(0xFFEF4444);

  /// Info color (for informational messages)
  static const Color info = Color(0xFF3B82F6);

  // ============================================================
  // SURFACE COLORS
  // ============================================================

  /// Card background - warm white with slight tan tint
  static const Color surface = Color(0xFFFFFBF5);

  /// Elevated surface - tan/beige for sidebar, cards
  static const Color surfaceElevated = Color(0xFFE5DBC9);

  /// Warm sidebar color
  static const Color sidebar = Color(0xFFD4C8B3);

  /// Border color
  static const Color border = Color(0xFFE5DDD0);

  /// Divider color
  static const Color divider = Color(0xFFF0EBE0);

  // ============================================================
  // SPECIAL COLORS
  // ============================================================

  /// Shadow color for cards and elevated elements
  static Color shadow = const Color(0xFF203655).withValues(alpha: 0.1);

  /// Overlay color for modals and dialogs
  static Color overlay = const Color(0xFF000000).withValues(alpha: 0.5);

  /// Hover state color
  static Color hover = const Color(0xFF203655).withValues(alpha: 0.05);

  /// Pressed state color
  static Color pressed = const Color(0xFF203655).withValues(alpha: 0.1);

  // ============================================================
  // GRADIENT DEFINITIONS
  // ============================================================

  /// Primary gradient (navy to lighter navy)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accent gradient (tan to lighter tan)
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Background gradient (subtle cream variation)
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
