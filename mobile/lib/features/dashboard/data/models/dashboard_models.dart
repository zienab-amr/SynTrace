class DashboardStats {
  final int activeProjects;
  final int openTasks;
  final int totalCommits;
  final int teamMembers;

  DashboardStats({
    required this.activeProjects,
    required this.openTasks,
    required this.totalCommits,
    required this.teamMembers,
  });
}

class RecentActivity {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final String type; // 'commit', 'task', 'meeting'
  final String? targetId;

  RecentActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    this.targetId,
  });
}