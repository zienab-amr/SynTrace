
import 'package:syntrace/features/notifications/data/models/jira_event_model.dart';

class MockJiraEvents {
  static List<JiraEventModel> getEvents() {
    return [
      JiraEventModel(
        id: '1',
        action: 'created',
        category: JiraEventCategory.issue,
        title: 'SYNT-45',
        description: 'Fix customer table schema',
        actorName: 'Zienab Amr',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      JiraEventModel(
        id: '2',
        action: 'commented on',
        category: JiraEventCategory.comment,
        title: 'BUG-12',
        description: 'Data corruption issue',
        actorName: 'Ahmed Kamal',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      JiraEventModel(
        id: '3',
        action: 'started',
        category: JiraEventCategory.sprint,
        title: 'Sprint 14',
        description: 'Q4 Core Features',
        actorName: 'Rodaina Mohamed',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      JiraEventModel(
        id: '4',
        action: 'logged time on',
        category: JiraEventCategory.worklog,
        title: 'SYNT-88',
        description: 'Implement OAuth Flow (2h 30m)',
        actorName: 'Martina Sameh',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      JiraEventModel(
        id: '5',
        action: 'updated',
        category: JiraEventCategory.project,
        title: 'ERP Platform',
        description: 'Changed project lead to Ahmed',
        actorName: 'Zienab Amr',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
      JiraEventModel(
        id: '6',
        action: 'created',
        category: JiraEventCategory.issueType,
        title: 'Epic',
        description: 'New issue type for large features',
        actorName: 'System Admin',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }
}