import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_radius.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool selected;
  final bool showBorder;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.selected = false,
    this.showBorder = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final shape = RoundedRectangleBorder(
      borderRadius: AppRadius.large,
      side: showBorder || selected
          ? BorderSide(
              color: selected ? scheme.primary : colors.border,
              width: selected ? 1.5 : 1,
            )
          : BorderSide.none,
    );

    final content = Padding(padding: padding, child: child);

    return Padding(
      padding: margin,
      child: Material(
        color: backgroundColor ?? (selected ? colors.selected : colors.surface),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                customBorder: shape,
                hoverColor: scheme.primary.withValues(alpha: 0.04),
                child: content,
              ),
      ),
    );
  }
}
