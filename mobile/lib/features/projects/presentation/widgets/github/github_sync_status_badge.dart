import 'package:flutter/material.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';

class GitHubSyncStatusBadge extends StatelessWidget {
  final GitHubSyncStatus status;

  const GitHubSyncStatusBadge({super.key, required this.status});

  Color _getColor(ColorScheme colors) {
    switch (status) {
      case GitHubSyncStatus.notMapped:
        return colors.onSurfaceVariant;

      case GitHubSyncStatus.pending:
        return Colors.blue.shade600;

      case GitHubSyncStatus.retrying:
        return Colors.orange.shade700;

      case GitHubSyncStatus.synced:
        return Colors.green.shade600;

      case GitHubSyncStatus.unavailable:
        return colors.error;

      case GitHubSyncStatus.unknown:
        return colors.onSurfaceVariant;
    }
  }

  IconData _getIcon() {
    switch (status) {
      case GitHubSyncStatus.notMapped:
        return Icons.link_off_rounded;

      case GitHubSyncStatus.pending:
        return Icons.sync_rounded;

      case GitHubSyncStatus.retrying:
        return Icons.refresh_rounded;

      case GitHubSyncStatus.synced:
        return Icons.check_circle_outline_rounded;

      case GitHubSyncStatus.unavailable:
        return Icons.error_outline_rounded;

      case GitHubSyncStatus.unknown:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(Theme.of(context).colorScheme);

    return Semantics(
      label: 'GitHub sync status: ${status.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIcon(), size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
