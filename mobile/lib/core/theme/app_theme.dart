import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_typography.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';
import 'app_theme_extension.dart';

class AppTheme {
  AppTheme._();

  static final ThemeData _light = _build(Brightness.light);
  static final ThemeData _dark = _build(Brightness.dark);

  static ThemeData get lightTheme => _light;
  static ThemeData get darkTheme => _dark;

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colors = isDark ? AppThemeExtension.dark : AppThemeExtension.light;

    final scheme =
        (isDark ? const ColorScheme.dark() : const ColorScheme.light())
            .copyWith(
              primary: isDark ? AppColors.actionDark : AppColors.actionLight,

              onPrimary: isDark ? AppColors.backgroundDark : Colors.white,

              secondary: isDark
                  ? AppColors.secondaryLight
                  : AppColors.secondaryDark,

              onSecondary: isDark ? AppColors.backgroundDark : Colors.white,

              surface: colors.surface,
              onSurface: colors.textPrimary,
              onSurfaceVariant: colors.textSecondary,

              surfaceDim: colors.canvas,
              surfaceBright: colors.surfaceElevated,

              surfaceContainerLowest: colors.canvas,
              surfaceContainerLow: colors.canvas,
              surfaceContainer: colors.surface,
              surfaceContainerHigh: colors.surfaceMuted,
              surfaceContainerHighest: colors.surfaceElevated,

              outline: colors.borderStrong,
              outlineVariant: colors.border,

              primaryContainer: colors.selected,
              onPrimaryContainer: isDark
                  ? AppColors.primaryLight
                  : AppColors.primaryDark,

              secondaryContainer: colors.surfaceMuted,
              onSecondaryContainer: colors.textPrimary,

              tertiary: colors.textSecondary,
              onTertiary: colors.canvas,
              tertiaryContainer: colors.surfaceMuted,
              onTertiaryContainer: colors.textPrimary,

              inverseSurface: colors.textPrimary,
              onInverseSurface: colors.canvas,

              error: colors.error,
              errorContainer: colors.errorSurface,
              onErrorContainer: colors.error,
              onError: isDark ? AppColors.backgroundDark : Colors.white,

              surfaceTint: Colors.transparent,
            );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    final textTheme = base.textTheme
        .copyWith(
          displayLarge: AppTextStyles.h1,
          displayMedium: AppTextStyles.h2,
          displaySmall: AppTextStyles.h3,
          headlineLarge: AppTextStyles.h1,
          headlineMedium: AppTextStyles.h2,
          headlineSmall: AppTextStyles.h3,
          titleLarge: AppTextStyles.sectionTitle,
          titleMedium: AppTextStyles.cardTitle,
          titleSmall: AppTextStyles.labelLarge,
          bodyLarge: AppTextStyles.bodyLarge,
          bodyMedium: AppTextStyles.bodyMedium,
          bodySmall: AppTextStyles.bodySmall,
          labelLarge: AppTextStyles.labelLarge,
          labelMedium: AppTextStyles.labelMedium,
          labelSmall: AppTextStyles.labelSmall,
        )
        .apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);

    final buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.medium);

    return base.copyWith(
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      cardColor: colors.surface,
      dividerColor: colors.border,

      extensions: [colors],

      textTheme: AppTypography.apply(textTheme),

      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h3.copyWith(color: colors.textPrimary),
        iconTheme: IconThemeData(color: colors.textSecondary, size: 22),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.large,
          side: BorderSide(color: colors.border),
        ),
      ),

      // Filled buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: buttonShape,
          textStyle: AppTypography.body(AppTextStyles.button),
        ),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: buttonShape,
          textStyle: AppTypography.body(AppTextStyles.button),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderStrong),
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: buttonShape,
          textStyle: AppTypography.body(AppTextStyles.button),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AppTypography.body(AppTextStyles.button),
          shape: buttonShape,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
        floatingLabelStyle: AppTextStyles.labelLarge.copyWith(
          color: scheme.primary,
        ),
        prefixIconColor: colors.textSecondary,
        suffixIconColor: colors.textSecondary,
        border: _inputBorder(colors.borderStrong),
        enabledBorder: _inputBorder(colors.borderStrong),
        focusedBorder: _inputBorder(scheme.primary, width: 1.5),
        disabledBorder: _inputBorder(colors.border),
        errorBorder: _inputBorder(colors.error),
        focusedErrorBorder: _inputBorder(colors.error, width: 1.5),
        errorStyle: AppTextStyles.bodySmall.copyWith(color: colors.error),
      ),

      // Icons
      iconTheme: IconThemeData(color: colors.textSecondary, size: 22),

      // Dividers
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),

      // Material 3 Navigation
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.selected,
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return AppTextStyles.labelSmall.copyWith(
            color: selected ? scheme.primary : colors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return IconThemeData(
            size: 22,
            color: selected ? scheme.primary : colors.textSecondary,
          );
        }),
      ),

      // Existing BottomNavigationBar compatibility
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: colors.textSecondary,
        selectedLabelStyle: AppTextStyles.labelSmall,
        unselectedLabelStyle: AppTextStyles.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.extraLarge),
        titleTextStyle: AppTextStyles.h3.copyWith(color: colors.textPrimary),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
      ),

      // Bottom sheets
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),

      // Snackbars
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.surfaceElevatedDark
            : AppColors.textPrimaryLight,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),

      // Progress
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: colors.surfaceMuted,
        circularTrackColor: colors.surfaceMuted,
      ),

      // Tabs
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.bodyMedium,
        indicatorColor: scheme.primary,
        dividerColor: colors.border,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.medium,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
