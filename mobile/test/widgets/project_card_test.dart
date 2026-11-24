import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/projects/data/models/project_api_model.dart';
import 'package:syntrace/features/projects/presentation/widgets/project_card.dart';

void main() {
  Future<void> pumpProjectCard(
    WidgetTester tester,
    ProjectApiModel project, {
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectCard(
            project: project,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'ProjectCard displays linked Jira status',
    (tester) async {
      const project = ProjectApiModel(
        id: 'p1',
        name: 'ERP Platform',
        clientId: 'c1',
        jiraProjectId: 'jira1',
        status: ProjectApiStatus.inProgress,
      );

      await pumpProjectCard(tester, project);

      expect(find.text('ERP Platform'), findsOneWidget);
      expect(find.text('Jira Linked'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
    },
  );

  testWidgets(
    'ProjectCard handles missing description',
    (tester) async {
      const project = ProjectApiModel(
        id: 'p2',
        name: 'Test Project',
        clientId: 'c1',
      );

      await pumpProjectCard(tester, project);

      expect(
        find.text('No description provided.'),
        findsOneWidget,
      );

      expect(find.text('Jira Not Linked'), findsOneWidget);
    },
  );

  testWidgets(
    'ProjectCard hides unknown project status',
    (tester) async {
      const project = ProjectApiModel(
        id: 'p3',
        name: 'Test Project',
        clientId: 'c1',
        status: ProjectApiStatus.unknown,
      );

      await pumpProjectCard(tester, project);

      expect(find.text('Not Available'), findsNothing);
    },
  );

  testWidgets(
    'ProjectCard triggers onTap callback',
    (tester) async {
      bool tapped = false;

      const project = ProjectApiModel(
        id: 'p4',
        name: 'Clickable Project',
        clientId: 'c1',
      );

      await pumpProjectCard(
        tester,
        project,
        onTap: () => tapped = true,
      );

      await tester.tap(find.byType(ProjectCard));
      await tester.pump();

      expect(tapped, isTrue);
    },
  );
}