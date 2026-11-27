import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextTheme apply(TextTheme theme) {
    final body = GoogleFonts.interTextTheme(theme);

    return body.copyWith(
      displayLarge: _heading(theme.displayLarge),
      displayMedium: _heading(theme.displayMedium),
      displaySmall: _heading(theme.displaySmall),
      headlineLarge: _heading(theme.headlineLarge),
      headlineMedium: _heading(theme.headlineMedium),
      headlineSmall: _heading(theme.headlineSmall),
      titleLarge: _heading(theme.titleLarge),
      titleMedium: _heading(theme.titleMedium),
      titleSmall: _heading(theme.titleSmall),
    );
  }

  static TextStyle heading(TextStyle style) {
    return GoogleFonts.manrope(textStyle: style);
  }

  static TextStyle body(TextStyle style) {
    return GoogleFonts.inter(textStyle: style);
  }

  static TextStyle? _heading(TextStyle? style) {
    if (style == null) return null;

    return GoogleFonts.manrope(textStyle: style);
  }
}
