import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/models/github_activity_model.dart';
import '../../../cubit/github_activity/github_activity_cubit.dart';
import '../../../cubit/github_activity/github_activity_state.dart';

import 'github_activity_card.dart';

class GitHubActivityList extends StatelessWidget {
  final GitHubActivityKind kind;
  final ValueChanged<GitHubActivityItem> onItemTap;

  const GitHubActivityList({
    super.key,
    required this.kind,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GitHubActivityCubit, GitHubActivityState>(
      builder: (context, state) {
        final cubit = context.read<GitHubActivityCubit>();

        switch (state.status) {
          case GitHubActivityStatus.initial:
          case GitHubActivityStatus.loading:
            return const Center(child: CircularProgressIndicator());

          case GitHubActivityStatus.failure:
            return _ActivityPlaceholder(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load activity',
              description: state.errorMessage ?? 'Something went wrong.',
              actionLabel: 'Try again',
              onAction: cubit.retry,
            );

          case GitHubActivityStatus.forbidden:
            return _ActivityPlaceholder(
              icon: Icons.lock_outline_rounded,
              title: 'Access restricted',
              description:
                  state.errorMessage ??
                  'You do not have access to this activity.',
              actionLabel: 'Check access',
              onAction: cubit.retry,
            );

          case GitHubActivityStatus.unavailable:
            return _ActivityPlaceholder(
              icon: Icons.link_off_rounded,
              title: 'Repository unavailable',
              description:
                  state.errorMessage ??
                  'No synchronized repository is available.',
              actionLabel: 'Refresh',
              onAction: cubit.refresh,
            );

          case GitHubActivityStatus.success:
            return _buildContent(context, state, cubit);
        }
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    GitHubActivityState state,
    GitHubActivityCubit cubit,
  ) {
    if (state.items.isEmpty) {
      return _ActivityPlaceholder(
        icon: kind == GitHubActivityKind.commit
            ? Icons.commit
            : Icons.call_split_rounded,
        title: 'No ${kind.label.toLowerCase()} yet',
        description:
            state.source != null && !state.source!.hasCompletedRequestedVersion
            ? 'Repository synchronization is in progress. '
                  'Refresh to check for imported activity.'
            : 'No activity has been returned '
                  'for this repository.',
        actionLabel: 'Refresh',
        onAction: cubit.refresh,
        isLoading: state.isRefreshing,
      );
    }

    return Column(
      children: [
        _ActivityListHeader(kind: kind, state: state, onRefresh: cubit.refresh),
        if (state.isRefreshing) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length + 1,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == state.items.length) {
                  return _PaginationFooter(
                    state: state,
                    onLoadMore: cubit.loadMore,
                  );
                }

                final item = state.items[index];

                return GitHubActivityCard(
                  key: ValueKey('${kind.apiValue}-${item.id}'),
                  item: item,
                  onTap: state.isRefreshing ? () {} : () => onItemTap(item),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityListHeader extends StatelessWidget {
  final GitHubActivityKind kind;
  final GitHubActivityState state;
  final VoidCallback onRefresh;

  const _ActivityListHeader({
    required this.kind,
    required this.state,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (state.source != null)
                  Text(
                    state.source!.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${state.items.length} loaded',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh activity',
            onPressed: state.isBusy ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  final GitHubActivityState state;
  final VoidCallback onLoadMore;

  const _PaginationFooter({required this.state, required this.onLoadMore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.paginationError != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              state.paginationError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.canLoadMore ? onLoadMore : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!state.hasMore) {
      return const SizedBox(height: 8);
    }

    return Center(
      child: OutlinedButton(
        onPressed: state.canLoadMore ? onLoadMore : null,
        child: const Text('Load more'),
      ),
    );
  }
}

class _ActivityPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isLoading;

  const _ActivityPlaceholder({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 32, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const CircularProgressIndicator()
            else
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}
