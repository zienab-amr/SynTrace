import 'package:flutter/material.dart';
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Row 1: Type Icon + Key + Priority ───
                Row(
                  children: [
                    // Type Icon
                    Icon(
                      _getTypeIcon(),
                      size: 14,
                      color: _getTypeColor(),
                    ),
                    const SizedBox(width: 6),

                    // Issue Key
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

                    // Priority Badge
                    _buildPriorityBadge(theme),
                  ],
                ),

                const SizedBox(height: 10),

                // ─── Row 2: Summary ───
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

                // ─── Row 3: Status + Assignee ───
                Row(
                  children: [
                    // Status
                    _buildStatusBadge(theme),

                    const Spacer(),

                    // Assignee
                    if (card.assigneeName != null) ...[
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
                    ],

                    const SizedBox(width: 8),

                    // Open Link
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

  // ═══════════════════════════════════════════════════════
  // Priority Badge
  // ═══════════════════════════════════════════════════════
  Widget _buildPriorityBadge(ThemeData theme) {
    final color = _getPriorityColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_upward, size: 10, color: color),
          const SizedBox(width: 2),
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

  // ═══════════════════════════════════════════════════════
  // Status Badge
  // ═══════════════════════════════════════════════════════
  Widget _buildStatusBadge(ThemeData theme) {
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

  // ═══════════════════════════════════════════════════════
  // Colors & Icons
  // ═══════════════════════════════════════════════════════
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
      default:
        return Icons.task_alt;
    }
  }

  Color _getPriorityColor() {
    switch (card.priority.toLowerCase()) {
      case 'highest':
      case 'critical':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'low':
      case 'lowest':
        return AppColors.textMuted;
      default:
        return AppColors.primary;
    }
  }

  Color _getStatusColor() {
    switch (card.statusCategory.toLowerCase()) {
      case 'done':
        return AppColors.secondary;
      case 'in_progress':
        return AppColors.primary;
      case 'blocked':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }
}