import 'package:flutter/material.dart';
import 'package:syntrace/core/models/project_model.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';
import 'package:syntrace/shared/widgets/risk_badge.dart';
import 'package:syntrace/shared/widgets/team_avatars.dart';

/// ═══════════════════════════════════════════════════════════
/// ProjectCard
/// 
/// كارد المشروع — مع Hover Effect على الويب
/// ═══════════════════════════════════════════════════════════
class ProjectCard extends StatefulWidget {
  final ProjectModel project;
  final ProjectStats? stats;
  final List<UserModel> members;
  final VoidCallback? onTap;

  const ProjectCard({
    super.key,
    required this.project,
    this.stats,
    this.members = const [],
    this.onTap,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withOpacity(0.5);

    final project = widget.project;
    final stats = widget.stats;
    final members = widget.members;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isHovered ? 1.015 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHovered
                      ? AppColors.primary.withOpacity(0.5)
                      : theme.dividerColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Header: Title + Risk ───
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project.description ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (stats != null) ...[
                        const SizedBox(width: 8),
                        RiskBadge(level: _mapRisk(stats.risk)),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ─── Sprint + Progress ───
                  if (stats != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Sprint ${project.currentSprint} of ${project.totalSprints} · ${_formatDate(project.sprintEnd)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(stats.progress * 100).toInt()}%',
                          style: TextStyle(
                            color: stats.progress > 0.5
                                ? AppColors.secondary
                                : AppColors.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stats.progress,
                        minHeight: 4,
                        backgroundColor: theme.dividerColor,
                        valueColor: AlwaysStoppedAnimation(
                          stats.progress > 0.5
                              ? AppColors.secondary
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ─── Stats Row ───
                  if (stats != null) ...[
                    Row(
                      children: [
                        _StatItem(
                          label: 'Health',
                          value: '${stats.healthPercent}%',
                          color: stats.healthPercent > 80
                              ? AppColors.secondary
                              : stats.healthPercent > 60
                                  ? AppColors.warning
                                  : AppColors.error,
                        ),
                        _StatItem(
                          label: 'Tasks',
                          value: '${stats.openTasks}',
                          color: AppColors.primary,
                        ),
                        _StatItem(
                          label: 'Blocked',
                          value: '${stats.blockedTasks}',
                          color: AppColors.error,
                        ),
                        _StatItem(
                          label: 'PRs',
                          value: '${stats.pullRequests}',
                          color: AppColors.primaryLight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── Team + Commits ───
                  Row(
                    children: [
                      if (members.isNotEmpty)
                        TeamAvatars(
                          users: members,
                          maxVisible: 3,
                          size: 32,
                        ),
                      const Spacer(),
                      if (stats != null)
                        Text(
                          '${stats.commitsCount} commits',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════
  RiskLevel _mapRisk(ProjectRisk risk) {
    return switch (risk) {
      ProjectRisk.high => RiskLevel.high,
      ProjectRisk.medium => RiskLevel.medium,
      ProjectRisk.low => RiskLevel.low,
    };
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'ends ${date.day} ${months[date.month - 1]}';
  }
}

// ═══════════════════════════════════════════════════════════
// Stat Item
// ═══════════════════════════════════════════════════════════
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}