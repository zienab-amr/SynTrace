import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);

  static void setTheme(ThemeMode mode) {
    themeMode.value = mode;
  }

  static void toggleTheme() {
    if (themeMode.value == ThemeMode.dark) {
      themeMode.value = ThemeMode.light;
    } else {
      themeMode.value = ThemeMode.dark;
    }
  }

  static void useSystemTheme() {
    themeMode.value = ThemeMode.system;
  }
}