import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode state notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _key = 'theme_mode';
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(ThemeMode.light) {
    _loadThemeMode();
  }

  void _loadThemeMode() {
    final savedMode = _prefs.getString(_key);
    if (savedMode != null) {
      state = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == savedMode,
        orElse: () => ThemeMode.light,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_key, mode.toString());
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }
}

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  // This will be initialized in main.dart with actual SharedPreferences
  throw UnimplementedError('themeModeProvider must be overridden');
});
