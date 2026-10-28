import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ─── Icon ───
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.2),
                AppColors.secondary.withOpacity(0.2),
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.rocket_launch_outlined,
              size: 64,
              color: AppColors.primary,
            ),
          ),
        ),

        const SizedBox(height: 32),

        Text(
          'Welcome to SynTrace!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          "Let's set up your workspace in just a few steps.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}