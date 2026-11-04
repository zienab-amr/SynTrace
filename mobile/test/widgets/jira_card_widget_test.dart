import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/data/models/jira_card_model.dart';
import 'package:syntrace/features/chat/presentation/widgets/jira_card_widget.dart';

void main() {
  testWidgets('JiraCardWidget displays the issue details correctly', (WidgetTester tester) async {
    const testCard = JiraCardModel(
      issueKey: 'SYNT-999',
      summary: 'Refactor payment module',
      status: 'To Do',
      statusCategory: 'todo',
      priority: 'Medium',
      issueType: 'Task',
      assigneeName: 'Ahmed',
      url: 'https://jira.com/SYNT-999',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: JiraCardWidget(card: testCard),
        ),
      ),
    );

    expect(find.text('SYNT-999'), findsOneWidget);
    expect(find.text('Refactor payment module'), findsOneWidget);
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Ahmed'), findsOneWidget);
  });
}