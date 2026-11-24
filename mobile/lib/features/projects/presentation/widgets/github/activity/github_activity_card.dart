import 'package:flutter/material.dart';

import '../../../../data/models/github_activity_model.dart';

class GitHubActivityCard extends StatelessWidget {
  final GitHubActivityItem item;
  final VoidCallback onTap;

  const GitHubActivityCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  IconData get _activityIcon {
    if (item.isCommit) return Icons.commit;
    if (item.isMerged) return Icons.merge_type;
    if (item.state == 'closed') return Icons.cancel_outlined;

    return Icons.call_split_rounded;
  }

  Color _statusColor(ColorScheme colors) {
    if (item.isCommit) return colors.primary;
    if (item.isMerged) return colors.tertiary;
    if (item.state == 'closed') return colors.error;
    if (item.draft) return colors.onSurfaceVariant;

    return colors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColor = _statusColor(colors);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_activityIcon, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.isCommit ? item.shortSha : '#${item.number}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActivityBadge(label: item.statusLabel, color: statusColor),
                  if (item.authorLogin != null && item.authorLogin!.isNotEmpty)
                    _ActivityBadge(
                      label: item.authorLogin!,
                      icon: Icons.person_outline,
                      color: colors.onSurfaceVariant,
                    ),
                  if (item.files.isNotEmpty)
                    _ActivityBadge(
                      label: item.filesMayBeIncomplete
                          ? '${item.files.length}+ files'
                          : '${item.files.length} files',
                      icon: Icons.description_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                ],
              ),
              if (!item.isCommit &&
                  item.headRef != null &&
                  item.baseRef != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.call_split,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${item.headRef} → ${item.baseRef}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (item.hasJiraEvidence) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: colors.outlineVariant),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...item.jira.map(
                      (issue) => _ActivityBadge(
                        label: issue.key,
                        icon: Icons.link_rounded,
                        color: colors.primary,
                      ),
                    ),
                    ...item.unresolvedJiraKeys.map(
                      (key) => _ActivityBadge(
                        label: key,
                        icon: Icons.link_off_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              if (item.displayDate != null) ...[
                const SizedBox(height: 12),
                Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(item.displayDate!.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _ActivityBadge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
