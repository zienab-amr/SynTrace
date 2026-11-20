import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/chat/data/models/jira_card_model.dart';

class JiraCardWidget extends StatelessWidget {
  final JiraCardModel card;
  final VoidCallback? onTap;

  const JiraCardWidget({
    super.key,
    required this.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (onTap != null) {
              onTap!();
            } else if (card.url.isNotEmpty) {
              final Uri url = Uri.parse(card.url);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getTypeIcon(),
                      size: 14,
                      color: _getTypeColor(),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      card.issueKey,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    _buildPriorityBadge(theme),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  card.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusBadge(theme),
                    const Spacer(),
                    if (card.assigneeName != null && card.assigneeName!.isNotEmpty) ...[
                      Icon(
                        Icons.person_outline,
                        size: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        card.assigneeName!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      Icons.open_in_new,
                      size: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(ThemeData theme) {
    if (card.priority.isEmpty || card.priority == 'None') {
      return const SizedBox.shrink();
    }
    final color = _getPriorityColor();
    final icon = _getPriorityIcon();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            card.priority,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    if (card.status.isEmpty || card.status == 'Unknown') {
      return const SizedBox.shrink();
    }
    final color = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        card.status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (card.issueType.toLowerCase()) {
      case 'bug':
        return AppColors.error;
      case 'story':
        return AppColors.secondary;
      case 'epic':
        return const Color(0xFF9B59B6);
      default:
        return AppColors.primary;
    }
  }

  IconData _getTypeIcon() {
    switch (card.issueType.toLowerCase()) {
      case 'bug':
        return Icons.bug_report_outlined;
      case 'story':
        return Icons.bookmark_outline;
      case 'epic':
        return Icons.bolt;
      case 'sub-task':
      case 'subtask':
        return Icons.call_split;
      default:
        return Icons.task_alt;
    }
  }

  Color _getPriorityColor() {
    switch (card.priority.toLowerCase()) {
      case 'highest':
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.teal;
      case 'lowest':
        return Colors.grey;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getPriorityIcon() {
    switch (card.priority.toLowerCase()) {
      case 'highest':
      case 'critical':
        return Icons.keyboard_double_arrow_up;
      case 'high':
        return Icons.arrow_upward;
      case 'medium':
        return Icons.drag_handle;
      case 'low':
        return Icons.arrow_downward;
      case 'lowest':
        return Icons.keyboard_double_arrow_down;
      default:
        return Icons.remove;
    }
  }

  Color _getStatusColor() {
    final status = card.status.toLowerCase();
    final category = card.statusCategory.toLowerCase();

    if (category == 'done' || status == 'done' || status == 'closed') {
      return Colors.green;
    }
    if (category == 'indeterminate' || status == 'in progress' || status == 'in_progress') {
      return Colors.blue;
    }
    if (status == 'blocked') {
      return Colors.red;
    }
    return Colors.grey;
  }
}