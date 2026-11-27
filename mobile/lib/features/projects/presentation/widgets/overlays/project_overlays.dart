import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/commits_list_view.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/detail_overlay.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/health_overlay_content.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/prs_list_view.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/tasks_list_view.dart';

class ProjectOverlays {
  ProjectOverlays._();

  static void showHealth(BuildContext context, String projectId) {
    DetailOverlay.show(
      context: context,
      title: 'Project Health',
      child: HealthOverlayContent(projectId: projectId),
    );
  }

  static void showTasks(BuildContext context, String projectId) {
    DetailOverlay.show(
      context: context,
      title: 'Tasks',
      child: TasksListView(projectId: projectId),
    );
  }

  static void showBlocked(BuildContext context, String projectId) {
    DetailOverlay.show(
      context: context,
      title: 'Blocked Tasks',
      child: TasksListView(projectId: projectId, filterStatus: 'blocked'),
    );
  }

  static void showPRs(BuildContext context, String projectId) {
    DetailOverlay.show(
      context: context,
      title: 'Pull Requests',
      child: PRsListView(projectId: projectId),
    );
  }

  static void showCommits(BuildContext context, String projectId) {
    DetailOverlay.show(
      context: context,
      title: 'Commits',
      child: CommitsListView(projectId: projectId),
    );
  }
}
