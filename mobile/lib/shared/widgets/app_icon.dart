import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:syntrace/core/theme/app_premium_icons.dart';

class AppIcon extends StatelessWidget {
  final AppIconData icon;
  final double? size;
  final Color? color;
  final double strokeWidth;
  final String? semanticLabel;

  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 1.7,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    final resolvedColor = color ?? iconTheme.color ?? scheme.onSurfaceVariant;

    final resolvedSize = size ?? iconTheme.size ?? 24;

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: HugeIcon(
        icon: icon,
        size: resolvedSize,
        color: resolvedColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}
