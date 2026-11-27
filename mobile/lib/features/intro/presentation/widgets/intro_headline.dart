import 'package:flutter/material.dart';

class IntroHeadline extends StatelessWidget {
  const IntroHeadline({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 18, height: 1, color: scheme.primary),

            const SizedBox(width: 9),

            Text(
              'ENGINEERING INTELLIGENCE',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Every detail\nhas a '),
              TextSpan(
                text: 'why.',
                style: TextStyle(color: scheme.primary),
              ),
            ],
          ),
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.4,
            height: 1.18,
            color: scheme.onSurface,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'From the first decision to the last line '
          'of code. Everything is connected.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.65,
            fontWeight: FontWeight.w400,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
