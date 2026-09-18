import 'package:flutter/material.dart';
import 'package:syntrace/features/splash/presentation/widgets/loading_dots.dart';

class SplashTitle extends StatelessWidget {
  const SplashTitle({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 15 * (1 - value)), 
                child: child,
              ),
            );
          },
          child: const Text(
            'SynTrace',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),

        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(opacity: value, child: child);
          },
          child: const Text(
            'NEVER LOSE THE WHY',
            style: TextStyle(
              color: Color(0xFF8892B0),
              fontSize: 11,
              letterSpacing: 4.0, 
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 40),

        // Loading Indicator 
         LoadingDots(),
      ],
    );
  }
}
