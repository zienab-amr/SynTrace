import 'package:flutter/material.dart';

import 'package:syntrace/core/theme/app_theme_extension.dart';

class DashboardFeedback extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DashboardFeedback({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = context.appText;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 21, color: colors.textSecondary),
          ),

          const SizedBox(height: 14),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                fontSize: 12,
                height: 1.6,
                color: colors.textSecondary,
              ),
            ),
          ),

          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 6),

            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                minimumSize: const Size(0, 48),
              ),
              child: Text(
                actionLabel!,
                style: text.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
