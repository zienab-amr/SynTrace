import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/commits_list_view.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/detail_overlay.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/health_overlay_content.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/prs_list_view.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/tasks_list_view.dart';

/// ═══════════════════════════════════════════════════════════
/// ProjectOverlays
/// 
/// Helper مسؤول عن فتح الـ Overlays
/// ═══════════════════════════════════════════════════════════
class ProjectOverlays {
  ProjectOverlays._();

  static void showHealth(BuildContext context, String projectId) {
    final stats = MockProjectStats.forProject(projectId);
    DetailOverlay.show(
      context: context,
      title: 'Project Health',
      subtitle: '${stats.healthPercent}%',
      child: HealthOverlayContent(projectId: projectId),
    );
  }

  static void showTasks(BuildContext context, String projectId) {
    final tasks = MockTasks.getByProject(projectId);
    DetailOverlay.show(
      context: context,
      title: 'Tasks',
      subtitle: '${tasks.length} tasks',
      child: TasksListView(projectId: projectId),
    );
  }

 static void showBlocked(BuildContext context, String projectId) {
  final count = MockTasks.blockedCount(projectId);
  DetailOverlay.show(
    context: context,
    title: 'Blocked Tasks',
    subtitle: '$count blocked',
    child: TasksListView(
      projectId: projectId,
      filterStatus: 'blocked',  
    ),
  );
}

  static void showPRs(BuildContext context, String projectId) {
    final prs = MockPRs.getByProject(projectId);
    DetailOverlay.show(
      context: context,
      title: 'Pull Requests',
      subtitle: '${prs.length} PRs',
      child: PRsListView(projectId: projectId),
    );
  }

  static void showCommits(BuildContext context, String projectId) {
    final commits = MockCommits.getByProject(projectId);
    DetailOverlay.show(
      context: context,
      title: 'Commits',
      subtitle: '${commits.length} commits',
      child: CommitsListView(projectId: projectId),
    );
  }
}