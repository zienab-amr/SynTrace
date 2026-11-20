import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/developers/data/models/developer_model.dart';

void main() {
  group('DeveloperModel', () {
    test('fromJson parses names and initials correctly', () {
      final json = {
        'id': 'd1',
        'firstName': 'Rodaina',
        'lastName': 'Mohamed',
        'email': 'r@x.com',
        'role': 'Developer',
      };
      final model = DeveloperModel.fromJson(json);
      expect(model.name, 'Rodaina Mohamed');
      expect(model.initials, 'RM');
    });
  });
}