import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppGradients {
  AppGradients._();

  static LinearGradient signature(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [
              Color(0xFF1C304A),
              Color(0xFF121A26),
              AppColors.backgroundDark,
            ]
          : const [
              Color(0xFFE7EDF5),
              AppColors.backgroundLight,
              Color(0xFFF0EAE1),
            ],
    );
  }

  static LinearGradient action(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFFB8CEED), AppColors.actionDark]
          : const [Color(0xFF3E5D85), AppColors.primaryDark],
    );
  }

  static RadialGradient ambient(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RadialGradient(
      colors: [
        scheme.primary.withValues(alpha: 0.13),
        scheme.primary.withValues(alpha: 0.04),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }
}
