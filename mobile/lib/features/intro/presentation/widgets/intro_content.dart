import 'package:flutter/material.dart';

import 'package:syntrace/core/theme/app_theme_extension.dart';

class IntroContent extends StatelessWidget {
  const IntroContent({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = context.appText;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(width: 18, height: 1, color: scheme.primary),

            const SizedBox(width: 9),

            Flexible(
              child: Text(
                'ENGINEERING INTELLIGENCE',
                style: text.labelSmall?.copyWith(
                  fontSize: 9,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Text.rich(
          TextSpan(
            text: 'Every detail\nhas a ',
            children: [
              TextSpan(
                text: 'why.',
                style: TextStyle(color: scheme.primary),
              ),
            ],
          ),
          style: text.headlineLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
            height: 1.15,
            color: colors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: Text(
            'Connect decisions, code and context.',
            style: text.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
