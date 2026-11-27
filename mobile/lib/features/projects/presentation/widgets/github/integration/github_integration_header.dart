import 'package:flutter/material.dart';

import '../../../cubit/github/project_github_state.dart';

class GitHubIntegrationHeader extends StatelessWidget {
  final ProjectGitHubState state;
  final VoidCallback onRefresh;

  const GitHubIntegrationHeader({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isBusy = state.isBusy || state.isLoading || state.isRefreshing;

    return Row(
      children: [
        Icon(
          Icons.account_tree_outlined,
          size: 19,
          color: theme.colorScheme.primary,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            'GitHub Integration',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        IconButton(
          tooltip: 'Refresh integration',
          onPressed: isBusy ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 19),
        ),
      ],
    );
  }
}
