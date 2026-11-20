import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('MessageBubble displays user message text', (WidgetTester tester) async {
    final msg = ChatMessage(
      id: '1',
      role: ChatRole.user,
      content: 'Hello AI',
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MessageBubble(message: msg)),
      ),
    );

    expect(find.text('Hello AI'), findsOneWidget);
  });
}