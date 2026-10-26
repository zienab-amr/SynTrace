import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/data/models/jira_card_model.dart';
import 'package:syntrace/features/chat/presentation/widgets/jira_card_widget.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('JiraCardWidget', () {
    final mockCard = JiraCardModel(
      issueKey: 'SYNT-45',
      summary: 'Fix Customer Table schema',
      status: 'In Progress',
      statusCategory: 'in_progress',
      priority: 'High',
      issueType: 'Task',
      assigneeName: 'Ahmed Kamal',
      url: 'https://jira.example.com/SYNT-45',
    );

    // ═══════════════════════════════════════════════════
    // Test 1: Displays issue key
    // ═══════════════════════════════════════════════════
    testWidgets('displays issue key', (tester) async {
      await tester.pumpWidget(wrap(JiraCardWidget(card: mockCard)));

      expect(find.text('SYNT-45'), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 2: Displays summary
    // ═══════════════════════════════════════════════════
    testWidgets('displays issue summary', (tester) async {
      await tester.pumpWidget(wrap(JiraCardWidget(card: mockCard)));

      expect(find.text('Fix Customer Table schema'), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 3: Displays status
    // ═══════════════════════════════════════════════════
    testWidgets('displays status badge', (tester) async {
      await tester.pumpWidget(wrap(JiraCardWidget(card: mockCard)));

      expect(find.text('In Progress'), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 4: Displays priority
    // ═══════════════════════════════════════════════════
    testWidgets('displays priority', (tester) async {
      await tester.pumpWidget(wrap(JiraCardWidget(card: mockCard)));

      expect(find.text('High'), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 5: Displays assignee
    // ═══════════════════════════════════════════════════
    testWidgets('displays assignee name', (tester) async {
      await tester.pumpWidget(wrap(JiraCardWidget(card: mockCard)));

      expect(find.text('Ahmed Kamal'), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 6: Bug type uses bug icon
    // ═══════════════════════════════════════════════════
    testWidgets('bug type shows bug icon', (tester) async {
      final bugCard = mockCard.copyWith(issueType: 'Bug');

      await tester.pumpWidget(wrap(JiraCardWidget(card: bugCard)));

      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 7: Task type uses task icon
    // ═══════════════════════════════════════════════════
    testWidgets('task type shows task icon', (tester) async {
      await tester.pumpWidget(wrap(JiraCardWidget(card: mockCard)));

      expect(find.byIcon(Icons.task_alt), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 8: onTap callback is called
    // ═══════════════════════════════════════════════════
    testWidgets('onTap callback is triggered', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(wrap(
        JiraCardWidget(
          card: mockCard,
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(JiraCardWidget));
      expect(tapped, true);
    });
  });
}