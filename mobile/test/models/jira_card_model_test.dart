import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/data/models/jira_card_model.dart';

void main() {
  group('JiraCardModel Tests', () {
    test('fromJson correctly parses a JSON map', () {
      final json = {
        'issueKey': 'SYNT-123',
        'summary': 'Fix login bug',
        'status': 'In Progress',
        'statusCategory': 'in_progress',
        'priority': 'High',
        'issueType': 'Bug',
        'assigneeName': 'Rodaina',
        'url': 'https://jira.com/SYNT-123',
      };

      final model = JiraCardModel.fromJson(json);

      expect(model.issueKey, 'SYNT-123');
      expect(model.summary, 'Fix login bug');
      expect(model.status, 'In Progress');
      expect(model.priority, 'High');
      expect(model.assigneeName, 'Rodaina');
    });

    test('copyWith creates a new instance with updated fields', () {
      const original = JiraCardModel(
        issueKey: 'SYNT-123',
        summary: 'Fix login bug',
        status: 'In Progress',
        statusCategory: 'in_progress',
        priority: 'High',
        issueType: 'Bug',
        url: 'https://jira.com',
      );

      final updated = original.copyWith(status: 'Done', priority: 'Low');

      expect(updated.status, 'Done');
      expect(updated.priority, 'Low');
      expect(updated.issueKey, original.issueKey);
    });
  });
}