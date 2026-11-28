import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();

  static const String _themeKey = 'syntrace_theme_mode';

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static Future<void> initialize() async {
    try {
      final savedMode = await _preferences.getString(_themeKey);

      themeMode.value = switch (savedMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (error) {
      debugPrint('Unable to load theme preference: $error');

      themeMode.value = ThemeMode.system;
    }
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;

    try {
      await _preferences.setString(_themeKey, mode.name);
    } catch (error) {
      debugPrint('Unable to save theme preference: $error');
    }
  }

  static Future<void> toggleTheme() {
    final currentMode = themeMode.value;

    final isDark =
        currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);

    return setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  static Future<void> useSystemTheme() {
    return setTheme(ThemeMode.system);
  }
}
