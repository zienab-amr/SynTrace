import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/core/models/project_model.dart';

void main() {
  group('ProjectModel', () {
    test('fromJson parses correctly', () {
      final json = {'id': 'p1', 'name': 'ERP', 'status': 'active'};
      final model = ProjectModel.fromJson(json);
      expect(model.name, 'ERP');
      expect(model.status, ProjectStatus.active);
    });

    test('isActive returns true for active status', () {
      const project = ProjectModel(id: '1', name: 'Test', status: ProjectStatus.active);
      expect(project.isActive, isTrue);
    });
  });
}