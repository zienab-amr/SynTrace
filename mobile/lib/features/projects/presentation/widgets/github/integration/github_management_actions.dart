import 'package:flutter/material.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';
import '../../../cubit/github/project_github_state.dart';

class GitHubManagementActions extends StatelessWidget {
  final ProjectGitHubState state;
  final VoidCallback onSync;
  final VoidCallback onUnlink;
  const GitHubManagementActions({super.key, required this.state, required this.onSync, required this.onUnlink});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final isRetry = state.integration?.syncStatus == GitHubSyncStatus.retrying;

    final hasFreshStatus = state.status == ProjectGitHubRequestStatus.success;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: state.canRequestSync && hasFreshStatus
                ? onSync
                : null,

            icon: state.isSyncing
                ? _buildButtonLoader()
                : const Icon(Icons.sync_rounded),

            label: Text(
              state.isSyncing
                  ? 'Requesting synchronization...'
                  : isRetry
                  ? 'Retry Synchronization'
                  : 'Resync Repository',
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
            ),

            onPressed: state.canUnlink && hasFreshStatus
                ? onUnlink
                : null,

            icon: state.isUnlinking
                ? _buildButtonLoader()
                : const Icon(Icons.link_off_rounded),

            label: Text(
              state.isUnlinking ? 'Unlinking...' : 'Unlink Repository',
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildButtonLoader() {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
