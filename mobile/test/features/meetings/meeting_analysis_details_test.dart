import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/meetings/presentation/widgets/details/meeting_analysis_details.dart';

void main() {
  testWidgets('scope resolves server item IDs to their meeting text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MeetingAnalysisOverview(
            meeting: {
              'scope': {
                'agreed': ['item-1'],
                'outOfScope': ['unknown-id'],
              },
              'items': [
                {'id': 'item-1', 'text': 'Export monthly reports'},
              ],
            },
          ),
        ),
      ),
    );
    expect(find.text('Agreed scope'), findsOneWidget);
    expect(find.text('Export monthly reports'), findsOneWidget);
    expect(find.text('item-1'), findsNothing);
    expect(find.text('Out of scope'), findsNothing);
  });

  testWidgets('review badge and draft details reflect the AI response', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MeetingAnalysisItemDetails(
              item: {
                'needsReview': true,
                'acceptanceSaid': ['Export includes a date range'],
                'drafts': [
                  {
                    'title': 'Implement reports export',
                    'status': 'published',
                    'jiraKey': 'APP-42',
                    'subtasks': [
                      {'title': 'Build export endpoint'},
                    ],
                    'storyPoints': 3,
                  },
                ],
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Export includes a date range'), findsOneWidget);
    expect(find.text('published · APP-42'), findsOneWidget);
    await tester.tap(find.text('Implement reports export'));
    await tester.pumpAndSettle();
    expect(find.text('Build export endpoint'), findsOneWidget);
    expect(find.text('3 story points'), findsOneWidget);
  });
}
