import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/shared/widgets/logo_mark.dart';

import '../widgets/intro_actions.dart';
import '../widgets/intro_artwork.dart';
import '../widgets/intro_content.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 18, 26, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _IntroBrand(),

                            const SizedBox(height: 12),

                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 220,
                                ),
                                child: const IntroArtwork(),
                              ),
                            ),

                            const SizedBox(height: 18),

                            const _IntroReveal(child: IntroContent()),

                            const SizedBox(height: 32),

                            _IntroReveal(
                              child: IntroActions(
                                onGetStarted: () {
                                  context.push(AppRoutes.signup);
                                },
                                onSignIn: () {
                                  context.push(AppRoutes.login);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroBrand extends StatelessWidget {
  const _IntroBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const LogoMark(size: 28),

        const SizedBox(width: 8),

        Text(
          'SynTrace',
          style: context.appText.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
            color: context.appColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _IntroReveal extends StatelessWidget {
  final Widget child;

  const _IntroReveal({required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}
