import 'package:flutter/material.dart';

class GitHubPickerEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const GitHubPickerEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: theme.colorScheme.onSurfaceVariant),

            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
