import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static List<BoxShadow> subtle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.035),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> elevated(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
        blurRadius: 28,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> accent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return [
      BoxShadow(
        color: scheme.primary.withValues(alpha: 0.14),
        blurRadius: 20,
        offset: const Offset(0, 5),
      ),
    ];
  }
}
