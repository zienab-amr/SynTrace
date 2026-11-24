import 'package:flutter/material.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';

class GitHubRepositoryCard extends StatelessWidget {
  final GitHubRepositoryOption repository;
  final VoidCallback onTap;

  const GitHubRepositoryCard({super.key, required this.repository, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),

      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(14),

          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,

                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),

                child: Icon(
                  repository.isPrivate
                      ? Icons.lock_outline_rounded
                      : Icons.public_rounded,
                  color: colors.primary,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repository.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildVisibilityBadge(context),

                        if (repository.defaultBranch?.isNotEmpty ?? false)
                          _buildBranchBadge(context),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityBadge(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return _buildBadge(
      label: repository.isPrivate ? 'Private' : 'Public',

      icon: repository.isPrivate ? Icons.lock_outline : Icons.public,

      color: colors.onSurfaceVariant,
    );
  }

  Widget _buildBranchBadge(BuildContext context) {
    return _buildBadge(
      label: repository.defaultBranch!,
      icon: Icons.account_tree_outlined,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),

          const SizedBox(width: 4),

          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
