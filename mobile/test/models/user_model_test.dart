import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/core/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('initials generates correct initials', () {
      const user = UserModel(id: '1', name: 'Ahmed Hassan', email: 'a@b.com', role: UserRole.developer);
      expect(user.initials, 'AH');
    });
  });
}