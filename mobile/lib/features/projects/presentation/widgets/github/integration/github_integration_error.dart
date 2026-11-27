import 'package:flutter/material.dart';
import '../../../cubit/github/project_github_state.dart';
import 'github_integration_surface.dart';

class GitHubIntegrationError extends StatelessWidget {
  final ProjectGitHubState state;
  final VoidCallback onRefresh;
  const GitHubIntegrationError({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GitHubIntegrationSurface(
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: theme.colorScheme.error,
          ),

          const SizedBox(height: 12),

          Text(
            'Unable to load GitHub integration',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),

          const SizedBox(height: 8),

          Text(
            state.errorMessage ?? 'Please try again.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: state.isBusy || state.isRefreshing ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
