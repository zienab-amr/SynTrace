import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('MessageBubble', () {
    // ═══════════════════════════════════════════════════
    // Test 1: User Message displays content
    // ═══════════════════════════════════════════════════
    testWidgets('displays user message content', (tester) async {
      final message = ChatMessage(
        id: '1',
        role: ChatRole.user,
        content: 'Hello AI',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(wrap(MessageBubble(message: message)));

      expect(find.text('Hello AI'), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 2: AI Message displays content
    // ═══════════════════════════════════════════════════
    testWidgets('displays AI message content', (tester) async {
      final message = ChatMessage(
        id: '2',
        role: ChatRole.ai,
        content: 'Hello User',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(wrap(MessageBubble(message: message)));

      expect(find.textContaining('Hello User'), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 3: Failed User Message shows error icon
    // ═══════════════════════════════════════════════════
    testWidgets('shows error icon for failed user message', (tester) async {
      final message = ChatMessage(
        id: '3',
        role: ChatRole.user,
        content: 'Failed message',
        timestamp: DateTime.now(),
        hasError: true,
      );

      await tester.pumpWidget(wrap(
        MessageBubble(
          message: message,
          onRetry: () {},
          onDelete: () {},
        ),
      ));

      expect(find.byIcon(Icons.priority_high), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 4: Failed AI Message shows error icon
    // ═══════════════════════════════════════════════════
    testWidgets('shows error icon for AI error message', (tester) async {
      final message = ChatMessage(
        id: '4',
        role: ChatRole.ai,
        content: 'Something went wrong',
        timestamp: DateTime.now(),
        hasError: true,
      );

      await tester.pumpWidget(wrap(MessageBubble(message: message)));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 5: Streaming message shows cursor
    // ═══════════════════════════════════════════════════
    testWidgets('shows blinking cursor when streaming', (tester) async {
      final message = ChatMessage(
        id: '5',
        role: ChatRole.ai,
        content: 'Streaming...',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      await tester.pumpWidget(wrap(MessageBubble(message: message)));
      await tester.pump();

      // الـ Cursor موجود (FadeTransition)
      expect(find.byType(FadeTransition), findsWidgets);
    });

    // ═══════════════════════════════════════════════════
    // Test 6: Empty streaming message shows cursor only
    // ═══════════════════════════════════════════════════
    testWidgets('empty streaming message shows cursor', (tester) async {
      final message = ChatMessage(
        id: '6',
        role: ChatRole.ai,
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      await tester.pumpWidget(wrap(MessageBubble(message: message)));
      await tester.pump();

      expect(find.byType(FadeTransition), findsWidgets);
    });
  });
}