import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/presentation/widgets/chat_input.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('ChatInput', () {
    // ═══════════════════════════════════════════════════
    // Test 1: Renders text field
    // ═══════════════════════════════════════════════════
    testWidgets('renders text field', (tester) async {
      await tester.pumpWidget(wrap(
        ChatInput(onSend: (_) {}),
      ));

      expect(find.byType(TextField), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 2: Typing text enables send button
    // ═══════════════════════════════════════════════════
    testWidgets('typing enables send button', (tester) async {
      await tester.pumpWidget(wrap(
        ChatInput(onSend: (_) {}),
      ));

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      // الـ Send button (Material) موجود
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 3: Tapping send calls callback
    // ═══════════════════════════════════════════════════
    testWidgets('tapping send calls onSend', (tester) async {
      String sentText = '';

      await tester.pumpWidget(wrap(
        ChatInput(onSend: (text) => sentText = text),
      ));

      await tester.enterText(find.byType(TextField), 'Hello AI');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      expect(sentText, 'Hello AI');
    });

    // ═══════════════════════════════════════════════════
    // Test 4: Field cleared after send
    // ═══════════════════════════════════════════════════
    testWidgets('field is cleared after send', (tester) async {
      await tester.pumpWidget(wrap(
        ChatInput(onSend: (_) {}),
      ));

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    // ═══════════════════════════════════════════════════
    // Test 5: Loading shows spinner
    // ═══════════════════════════════════════════════════
    testWidgets('shows spinner when loading', (tester) async {
      await tester.pumpWidget(wrap(
        ChatInput(
          onSend: (_) {},
          isLoading: true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 6: Disabled input
    // ═══════════════════════════════════════════════════
    testWidgets('input disabled when enabled is false', (tester) async {
      await tester.pumpWidget(wrap(
        ChatInput(
          onSend: (_) {},
          enabled: false,
        ),
      ));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, false);
    });
  });
}