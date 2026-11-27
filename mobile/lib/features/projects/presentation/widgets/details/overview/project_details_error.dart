import 'package:flutter/material.dart';

class ProjectDetailsError extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  const ProjectDetailsError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.error,
            ),

            const SizedBox(height: 16),

            Text(
              'Unable to load project',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              message ?? 'Project information is unavailable.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
