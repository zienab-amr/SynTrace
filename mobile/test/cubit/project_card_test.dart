import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/core/models/project_model.dart';
import 'package:syntrace/features/projects/presentation/widgets/project_card.dart';

void main() {
  testWidgets('ProjectCard displays project name and description', (WidgetTester tester) async {
    const project = ProjectModel(
      id: 'p1',
      name: 'ERP Platform',
      description: 'Main system',
      status: ProjectStatus.active,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProjectCard(project: project)),
      ),
    );

    expect(find.text('ERP Platform'), findsOneWidget);
    expect(find.text('Main system'), findsOneWidget);
  });
}