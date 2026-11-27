import 'package:flutter/material.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';
import 'github_repository_card.dart';

class GitHubRepositoryList extends StatelessWidget {
  final List<GitHubRepositoryOption> repositories;
  final int total;
  final Future<void> Function() onRefresh;
  final ValueChanged<GitHubRepositoryOption> onSelected;
  const GitHubRepositoryList({
    super.key,
    required this.repositories,
    required this.total,
    required this.onRefresh,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${repositories.length} of $total repositories',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

              physics: const AlwaysScrollableScrollPhysics(),

              itemCount: repositories.length,

              separatorBuilder: (_, _) => const SizedBox(height: 10),

              itemBuilder: (context, index) {
                final repository = repositories[index];

                return GitHubRepositoryCard(
                  repository: repository,
                  onTap: () {
                    onSelected(repository);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
