import 'package:flutter/material.dart';

import 'package:syntrace/core/theme/app_premium_icons.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

import 'app_icon.dart';

class AppIconButton extends StatelessWidget {
  final AppIconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double iconSize;
  final Color? color;
  final bool selected;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.iconSize = 23,
    this.color,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final foreground =
        color ?? (selected ? scheme.primary : colors.textSecondary);

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: colors.textSecondary.withValues(alpha: 0.4),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Builder(
        builder: (context) {
          return AppIcon(
            icon,
            size: iconSize,
            color: IconTheme.of(context).color,
            strokeWidth: selected ? 1.9 : 1.7,
          );
        },
      ),
    );
  }
}
