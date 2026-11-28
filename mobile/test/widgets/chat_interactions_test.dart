import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/presentation/widgets/chat_input.dart';
import 'package:syntrace/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('a disabled send action still lets the user write a draft', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(
            enabled: false,
            onSend: (text, quotes) async {
              sent.add(text);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'My next question');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    expect(sent, isEmpty);
    expect(find.text('My next question'), findsOneWidget);
  });

  testWidgets('reply and copy work without selecting text first', (
    tester,
  ) async {
    const content = 'Reply example';
    String? reply;
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData')
        copied = call.arguments['text'] as String?;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: 'a',
              role: ChatRole.ai,
              content: content,
              timestamp: DateTime(2026),
            ),
            onReply: (text) => reply = text,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Reply to message'));
    await tester.tap(find.byTooltip('Copy message'));
    await tester.pump();
    expect(reply, content);
    expect(copied, content);
  });

  testWidgets('message direction follows the first strong script', (
    tester,
  ) async {
    for (final (message, direction) in [
      ('123 أهلًا في SynTrace', TextDirection.rtl),
      ('SynTrace supports تذاكر Jira', TextDirection.ltr),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: ChatMessage(
                id: 'a',
                role: ChatRole.ai,
                content: message,
                timestamp: DateTime(2026),
              ),
            ),
          ),
        ),
      );
      expect(
        Directionality.of(tester.element(find.byType(MarkdownBody))),
        direction,
      );
    }
  });
}
