import '../models/dashboard_models.dart';

class MockDashboardData {
  static DashboardStats getStats() {
    return DashboardStats(
      activeProjects: 12,
      openTasks: 45,
      totalCommits: 1280,
      teamMembers: 8,
    );
  }

  static List<RecentActivity> getRecentActivities() {
    return [
      RecentActivity(
        id: '1',
        title: 'New Commit in ERP Platform',
        description: 'Ahmed Hassan pushed a fix for login bug.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        type: 'commit',
        targetId: 'proj-1', 
      ),
      RecentActivity(
        id: '2',
        title: 'Sprint 3 Planning',
        description: 'AI extracted 5 action items from the meeting.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: 'meeting',
        targetId: 'note-1',
      ),
      RecentActivity(
        id: '3',
        title: 'Task Blocked',
        description: 'Payment API integration is blocked by external dependency.',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        type: 'task',
        targetId: 'task-1', 
      ),
    ];
  }
}