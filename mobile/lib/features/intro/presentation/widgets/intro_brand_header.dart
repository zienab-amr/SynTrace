import 'package:flutter/material.dart';
import 'package:syntrace/shared/widgets/logo_mark.dart';

class IntroBrandHeader extends StatelessWidget {
  const IntroBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        const LogoMark(size: 30),

        const SizedBox(width: 9),

        Text(
          'SynTrace',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}
