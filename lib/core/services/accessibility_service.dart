import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  // Font size settings
  double _fontSizeMultiplier = 1.0;
  static const double minFontSize = 0.8;
  static const double maxFontSize = 1.5;
  static const String _fontSizeKey = 'accessibility_font_size';

  // High contrast mode
  bool _highContrastMode = false;
  static const String _highContrastKey = 'accessibility_high_contrast';

  // Dyslexia-friendly font
  bool _dyslexiaFriendlyFont = false;
  static const String _dyslexiaFontKey = 'accessibility_dyslexia_font';

  // Reduce animations
  bool _reduceAnimations = false;
  static const String _reduceAnimationsKey = 'accessibility_reduce_animations';

  // Getters
  double get fontSizeMultiplier => _fontSizeMultiplier;
  bool get highContrastMode => _highContrastMode;
  bool get dyslexiaFriendlyFont => _dyslexiaFriendlyFont;
  bool get reduceAnimations => _reduceAnimations;

  /// Initialize from saved preferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSizeMultiplier = prefs.getDouble(_fontSizeKey) ?? 1.0;
    _highContrastMode = prefs.getBool(_highContrastKey) ?? false;
    _dyslexiaFriendlyFont = prefs.getBool(_dyslexiaFontKey) ?? false;
    _reduceAnimations = prefs.getBool(_reduceAnimationsKey) ?? false;
    notifyListeners();
  }

  /// Set font size multiplier
  Future<void> setFontSizeMultiplier(double value) async {
    if (value < minFontSize || value > maxFontSize) return;
    _fontSizeMultiplier = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, value);
    notifyListeners();
  }

  /// Toggle high contrast mode
  Future<void> toggleHighContrast() async {
    _highContrastMode = !_highContrastMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, _highContrastMode);
    notifyListeners();
  }

  /// Toggle dyslexia-friendly font
  Future<void> toggleDyslexiaFont() async {
    _dyslexiaFriendlyFont = !_dyslexiaFriendlyFont;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dyslexiaFontKey, _dyslexiaFriendlyFont);
    notifyListeners();
  }

  /// Toggle reduce animations
  Future<void> toggleReduceAnimations() async {
    _reduceAnimations = !_reduceAnimations;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reduceAnimationsKey, _reduceAnimations);
    notifyListeners();
  }

  /// Reset all settings to default
  Future<void> resetToDefaults() async {
    _fontSizeMultiplier = 1.0;
    _highContrastMode = false;
    _dyslexiaFriendlyFont = false;
    _reduceAnimations = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fontSizeKey);
    await prefs.remove(_highContrastKey);
    await prefs.remove(_dyslexiaFontKey);
    await prefs.remove(_reduceAnimationsKey);
    
    notifyListeners();
  }

  /// Get adjusted font size
  double getAdjustedFontSize(double baseFontSize) {
    return baseFontSize * _fontSizeMultiplier;
  }

  /// Get text style with accessibility adjustments
  TextStyle getAdjustedTextStyle(TextStyle baseStyle) {
    var style = baseStyle.copyWith(
      fontSize: baseStyle.fontSize != null 
          ? baseStyle.fontSize! * _fontSizeMultiplier 
          : null,
    );

    if (_dyslexiaFriendlyFont) {
      style = style.copyWith(
        fontFamily: 'OpenDyslexic', // You'll need to add this font
        letterSpacing: 0.5,
      );
    }

    return style;
  }

  /// Get animation duration (reduced if setting enabled)
  Duration getAnimationDuration(Duration baseDuration) {
    if (_reduceAnimations) {
      return Duration.zero;
    }
    return baseDuration;
  }
}
