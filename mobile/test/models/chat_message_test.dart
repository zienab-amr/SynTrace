import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('copyWith updates content correctly', () {
      final original = ChatMessage(
        id: '1',
        role: ChatRole.ai,
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      );
      final updated = original.copyWith(content: 'Hello', isStreaming: false);
      expect(updated.content, 'Hello');
      expect(updated.isStreaming, isFalse);
    });
  });
}