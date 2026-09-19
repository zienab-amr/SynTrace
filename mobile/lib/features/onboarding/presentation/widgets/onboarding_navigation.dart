import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class OnboardingNavigation extends StatelessWidget {
  final bool canGoBack;
  final bool canGoNext;
  final bool isLastStep;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  const OnboardingNavigation({
    super.key,
    required this.canGoBack,
    required this.canGoNext,
    required this.isLastStep,
    required this.onBack,
    required this.onNext,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // ─── Back ───
          if (canGoBack)
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                foregroundColor:
                    theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),

          const Spacer(),

          // ─── Skip ───
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor:
                    theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              child: const Text('Skip'),
            ),

          if (onSkip != null) const SizedBox(width: 12),

          // ─── Next / Finish ───
          ElevatedButton(
            onPressed: canGoNext ? onNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLastStep ? 'Get Started' : 'Next',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isLastStep ? Icons.check : Icons.arrow_forward,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}