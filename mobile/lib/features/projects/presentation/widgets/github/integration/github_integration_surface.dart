import 'package:flutter/material.dart';

class GitHubIntegrationSurface extends StatelessWidget {
  final Widget child;
  const GitHubIntegrationSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}
