import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/presentation/widgets/typing_indicator.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('TypingIndicator', () {
    // ═══════════════════════════════════════════════════
    // Test 1: Renders correctly
    // ═══════════════════════════════════════════════════
    testWidgets('renders AI avatar', (tester) async {
      await tester.pumpWidget(wrap(const TypingIndicator()));
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 2: Shows "AI is thinking..." text
    // ═══════════════════════════════════════════════════
    testWidgets('shows thinking text', (tester) async {
      await tester.pumpWidget(wrap(const TypingIndicator()));
      await tester.pump();

      expect(find.text('AI is thinking...'), findsOneWidget);
    });

    // ═══════════════════════════════════════════════════
    // Test 3: Animation runs without error
    // ═══════════════════════════════════════════════════
    testWidgets('animation controller runs', (tester) async {
      await tester.pumpWidget(wrap(const TypingIndicator()));

      // انتظر شوية وشوف لو الأنيميشن شغالة
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AnimatedBuilder), findsWidgets);
    });
  });
}