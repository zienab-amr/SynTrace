import 'package:flutter/material.dart';

import 'package:syntrace/core/theme/app_premium_icons.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/shared/widgets/app_icon.dart';

class IntroActions extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  const IntroActions({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: onGetStarted,
            style: FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Get started',
                    textAlign: TextAlign.center,
                    style: context.appText.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                PositionedDirectional(
                  end: 0,
                  child: AppIcon(
                    AppPremiumIcons.forward,
                    size: 19,
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 5),

        TextButton(
          onPressed: onSignIn,
          style: TextButton.styleFrom(
            foregroundColor: colors.textPrimary,
            minimumSize: const Size(100, 48),
          ),
          child: Text(
            'Sign in',
            style: context.appText.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
