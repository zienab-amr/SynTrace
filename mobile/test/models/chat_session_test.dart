import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/data/models/chat_session.dart';

void main() {
  group('ChatSession', () {
    test('toJson/fromJson roundtrip works', () {
      final original = ChatSession(
        id: '1',
        title: 'Test',
        lastMessageAt: DateTime(2026, 1, 1),
        preview: 'Hi',
      );
      final json = original.toJson();
      final restored = ChatSession.fromJson(json);
      expect(restored.title, 'Test');
      expect(restored.preview, 'Hi');
    });
  });
}