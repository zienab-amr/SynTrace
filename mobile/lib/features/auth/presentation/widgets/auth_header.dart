import 'package:flutter/material.dart';
import 'package:syntrace/shared/widgets/logo_mark.dart';

class AuthHeader extends StatelessWidget 
{
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ═══ Logo ═══
        const LogoMark(size: 70),
        const SizedBox(height: 24),

        // ═══ Title ═══
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),

        // ═══ Subtitle ═══
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.55),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}