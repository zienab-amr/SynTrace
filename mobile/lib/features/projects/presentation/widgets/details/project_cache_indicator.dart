import 'package:flutter/material.dart';

class ProjectCacheIndicator extends StatelessWidget {
  final bool isRefreshing;

  const ProjectCacheIndicator({super.key, required this.isRefreshing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (isRefreshing)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else
            Icon(Icons.storage_rounded, size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              isRefreshing
                  ? 'Updating project...'
                  : 'Showing saved project details',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
