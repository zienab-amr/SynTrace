import 'package:flutter/material.dart';
import '../../../cubit/github/project_github_state.dart';

class GitHubIntegrationHeader extends StatelessWidget {
  final ProjectGitHubState state;
  final VoidCallback onRefresh;
  const GitHubIntegrationHeader({super.key, required this.state, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.account_tree_outlined,
            color: theme.colorScheme.primary,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GitHub Integration',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Repository and synchronization',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),

        IconButton(
          tooltip: 'Refresh integration',
          onPressed: state.isBusy || state.isLoading || state.isRefreshing
              ? null
              : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}
