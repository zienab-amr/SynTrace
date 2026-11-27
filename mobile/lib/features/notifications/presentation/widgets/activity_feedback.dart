import 'package:flutter/material.dart';

import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/core/theme/app_premium_icons.dart';
import 'package:syntrace/shared/widgets/app_icon.dart';

class ActivityFeedback extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ActivityFeedback({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = context.appText;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final size in [104.0, 82.0])
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.12),
                            width: 0.8,
                          ),
                        ),
                      ),

                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surfaceMuted,
                      ),
                      alignment: Alignment.center,
                      child: AppIcon(
                        AppPremiumIcons.activity,
                        size: 27,
                        strokeWidth: 1.4,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: colors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.6,
                  color: colors.textSecondary,
                ),
              ),

              if (onRetry != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
