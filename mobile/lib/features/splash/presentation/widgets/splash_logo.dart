import 'package:flutter/material.dart';

class SplashLogo extends StatelessWidget {
  const SplashLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final safeValue = value.clamp(0.0, 1.0);

        return Transform.scale(
          scale: 0.7 + (safeValue * 0.3),
          child: Opacity(
            opacity: safeValue,
            child: child,
          ),
        );
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFF00D2FF).withOpacity(0.25)
                  : const Color(0xFF3B82F6).withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Image.asset(
        'assets/icons/icon_dark.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}