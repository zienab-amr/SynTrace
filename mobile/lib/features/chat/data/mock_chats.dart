import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/data/models/chat_session.dart';
import 'package:syntrace/features/chat/data/models/jira_card_model.dart';

class MockChats {
  MockChats._();

  static List<ChatSession> get sessions => [
        ChatSession(
          id: '1',
          title: 'Sprint 14 delay analysis',
          lastMessageAt: DateTime.now().subtract(const Duration(minutes: 2)),
          preview: 'The ERP Platform project is at high risk...',
        ),
        ChatSession(
          id: '2',
          title: 'Recent commits for auth module',
          lastMessageAt: DateTime.now().subtract(const Duration(hours: 3)),
          preview: 'Here are the last 3 commits...',
        ),
        ChatSession(
          id: '3',
          title: 'Bug recurrence patterns',
          lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
          preview: 'BUG-12 has recurred 3 times...',
        ),
        ChatSession(
          id: '4',
          title: 'Dependency chain for Task #1847',
          lastMessageAt: DateTime.now().subtract(const Duration(days: 2)),
          preview: 'Checking permissions...',
        ),
      ];

  static List<ChatMessage> get messages => [
        ChatMessage(
          id: '1',
          role: ChatRole.user,
          content: 'Show me the dependency chain for Task #1847',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        ChatMessage(
          id: '2',
          role: ChatRole.ai,
          timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
          jiraCards: const [                          // ← ضيفي ده
                     MockJiraCards.synt45,
                     MockJiraCards.bug12,
                     MockJiraCards.synt47,
                     ],
          steps: const [
            ProgressStep(label: 'Checking permissions', isDone: true),
            ProgressStep(label: 'Searching engineering knowledge', isDone: true),
            ProgressStep(label: 'Exploring graph relationships', isDone: true),
            ProgressStep(label: 'Retrieving relevant documents', isDone: true),
            ProgressStep(label: 'Generating response', isDone: true),
          ],
          content: '''## Root Cause Analysis

The **ERP Platform** project is at a **high risk of delay** with **78% probability** for the current sprint.

### Primary Cause

The Flutter payment module implementation is currently **6 days behind schedule**. The core blocker is an unresolved dependency on the external Payment Provider API — integration credentials were not available at sprint start.

### Contributing Factors

**Payment API Dependency**

The external Payment Provider API keys were not provisioned by DevOps on Day 1 of the sprint.

**Team Capacity**

Two senior engineers were reassigned to the Auth module during this sprint.

### Recommended Actions

1. Escalate to DevOps for API key provisioning
2. Add a fallback mock provider for testing
3. Re-estimate the sprint scope''',
        ),
      ];


}

class MockJiraCards {
  MockJiraCards._();

  static const synt45 = JiraCardModel(
    issueKey: 'SYNT-45',
    summary: 'Fix Customer Table schema',
    status: 'In Progress',
    statusCategory: 'in_progress',
    priority: 'High',
    issueType: 'Task',
    assigneeName: 'Ahmed Kamal',
    url: 'https://syntrace.atlassian.net/browse/SYNT-45',
  );

  static const bug12 = JiraCardModel(
    issueKey: 'BUG-12',
    summary: 'Customer data corrupted',
    status: 'Blocked',
    statusCategory: 'blocked',
    priority: 'Highest',
    issueType: 'Bug',
    assigneeName: 'Nour Hassan',
    url: 'https://syntrace.atlassian.net/browse/BUG-12',
  );

  static const synt47 = JiraCardModel(
    issueKey: 'SYNT-47',
    summary: 'Add validation rules',
    status: 'Done',
    statusCategory: 'done',
    priority: 'Medium',
    issueType: 'Story',
    assigneeName: 'Mohamed Ali',
    url: 'https://syntrace.atlassian.net/browse/SYNT-47',
  );
}