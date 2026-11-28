import 'package:flutter/material.dart';
import 'app_colors.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceElevated;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color selected;
  final Color success;
  final Color warning;
  final Color error;
  final Color successSurface;
  final Color warningSurface;
  final Color errorSurface;
  final Color infoSurface;

  const AppThemeExtension({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.selected,
    required this.success,
    required this.warning,
    required this.error,
    required this.successSurface,
    required this.warningSurface,
    required this.errorSurface,
    required this.infoSurface,
  });

  static const light = AppThemeExtension(
    canvas: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    surfaceMuted: AppColors.surfaceMutedLight,
    surfaceElevated: AppColors.surfaceElevatedLight,
    border: AppColors.borderLight,
    borderStrong: AppColors.borderStrongLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    selected: AppColors.selectedLight,
    success: AppColors.successLightForeground,
    warning: AppColors.warningLightForeground,
    error: AppColors.errorLightForeground,
    successSurface: AppColors.successSurfaceLight,
    warningSurface: AppColors.warningSurfaceLight,
    errorSurface: AppColors.errorSurfaceLight,
    infoSurface: AppColors.infoSurfaceLight,
  );

  static const dark = AppThemeExtension(
    canvas: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    surfaceMuted: AppColors.surfaceMutedDark,
    surfaceElevated: AppColors.surfaceElevatedDark,
    border: AppColors.borderDark,
    borderStrong: AppColors.borderStrongDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    selected: AppColors.selectedDark,
    success: AppColors.successDarkForeground,
    warning: AppColors.warningDarkForeground,
    error: AppColors.errorDarkForeground,
    successSurface: AppColors.successSurfaceDark,
    warningSurface: AppColors.warningSurfaceDark,
    errorSurface: AppColors.errorSurfaceDark,
    infoSurface: AppColors.infoSurfaceDark,
  );

  @override
  AppThemeExtension copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? selected,
    Color? success,
    Color? warning,
    Color? error,
    Color? successSurface,
    Color? warningSurface,
    Color? errorSurface,
    Color? infoSurface,
  }) {
    return AppThemeExtension(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      selected: selected ?? this.selected,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      successSurface: successSurface ?? this.successSurface,
      warningSurface: warningSurface ?? this.warningSurface,
      errorSurface: errorSurface ?? this.errorSurface,
      infoSurface: infoSurface ?? this.infoSurface,
    );
  }

  @override
  AppThemeExtension lerp(covariant AppThemeExtension? other, double t) {
    if (other == null) return this;

    Color blend(Color a, Color b) => Color.lerp(a, b, t)!;

    return AppThemeExtension(
      canvas: blend(canvas, other.canvas),
      surface: blend(surface, other.surface),
      surfaceMuted: blend(surfaceMuted, other.surfaceMuted),
      surfaceElevated: blend(surfaceElevated, other.surfaceElevated),
      border: blend(border, other.border),
      borderStrong: blend(borderStrong, other.borderStrong),
      textPrimary: blend(textPrimary, other.textPrimary),
      textSecondary: blend(textSecondary, other.textSecondary),
      selected: blend(selected, other.selected),
      success: blend(success, other.success),
      warning: blend(warning, other.warning),
      error: blend(error, other.error),
      successSurface: blend(successSurface, other.successSurface),
      warningSurface: blend(warningSurface, other.warningSurface),
      errorSurface: blend(errorSurface, other.errorSurface),
      infoSurface: blend(infoSurface, other.infoSurface),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeExtension get appColors {
    final theme = Theme.of(this);

    return theme.extension<AppThemeExtension>() ??
        (theme.brightness == Brightness.dark
            ? AppThemeExtension.dark
            : AppThemeExtension.light);
  }

  TextTheme get appText => Theme.of(this).textTheme;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
