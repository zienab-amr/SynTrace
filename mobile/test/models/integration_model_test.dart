import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/settings/data/models/integration_model.dart';

void main() {
  group('IntegrationModel', () {
    test('copyWith updates status correctly', () {
      const original = IntegrationModel(
        type: IntegrationType.jira,
        name: 'Jira',
        description: 'Sync',
        status: IntegrationStatus.disconnected,
      );
      final updated = original.copyWith(status: IntegrationStatus.connected);
      expect(updated.status, IntegrationStatus.connected);
      expect(updated.name, 'Jira');
    });
  });
}