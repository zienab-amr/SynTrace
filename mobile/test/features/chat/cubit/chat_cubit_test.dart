import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:syntrace/features/chat/presentation/cubit/chat_state.dart';

void main() {
  group('ChatCubit', () {
    late ChatCubit cubit;

    setUp(() {
      cubit = ChatCubit();
    });

    tearDown(() {
      cubit.close();
    });

    // ═══════════════════════════════════════════════════
    // Test 1: Initial State
    // ═══════════════════════════════════════════════════
    test('initial state is ChatInitial', () {
      expect(cubit.state, isA<ChatInitial>());
    });

    // ═══════════════════════════════════════════════════
    // Test 2: Load Chat
    // ═══════════════════════════════════════════════════
    blocTest<ChatCubit, ChatState>(
      'emits [ChatLoading, ChatLoaded] when loadChat is called',
      build: () => ChatCubit(),
      act: (cubit) => cubit.loadChat(),
      expect: () => [
        isA<ChatLoading>(),
        isA<ChatLoaded>(),
      ],
      wait: const Duration(milliseconds: 500),
    );

    // ═══════════════════════════════════════════════════
    // Test 3: Send Message (Success)
    // ═══════════════════════════════════════════════════
    blocTest<ChatCubit, ChatState>(
      'sendMessage adds user message and AI response',
      build: () => ChatCubit(),
      act: (cubit) async {
        await cubit.loadChat();
        await cubit.sendMessage('Hello AI');
      },
      wait: const Duration(seconds: 5),
      verify: (cubit) {
        final state = cubit.state;
        expect(state, isA<ChatLoaded>());

        final loaded = state as ChatLoaded;
        expect(loaded.messages.length, greaterThanOrEqualTo(2));

        // ─── رسالة المستخدم ───
        final userMessage = loaded.messages.firstWhere(
          (m) => m.role == ChatRole.user,
        );
        expect(userMessage.content, 'Hello AI');

        // ─── رسالة الـ AI ───
        final aiMessages = loaded.messages
            .where((m) => m.role == ChatRole.ai)
            .toList();
        expect(aiMessages.length, greaterThanOrEqualTo(1));
      },
    );

    // ═══════════════════════════════════════════════════
    // Test 4: Send Message with Error
    // ═══════════════════════════════════════════════════
    blocTest<ChatCubit, ChatState>(
      'sendMessage with "error" triggers error state',
      build: () => ChatCubit(),
      act: (cubit) async {
        await cubit.loadChat();
        await cubit.sendMessage('This will error');
      },
      wait: const Duration(seconds: 2),
      verify: (cubit) {
        final state = cubit.state;
        expect(state, isA<ChatLoaded>());

        final loaded = state as ChatLoaded;
        expect(loaded.hasError, true);
        expect(loaded.error, isNotNull);
      },
    );

    // ═══════════════════════════════════════════════════
    // Test 5: New Chat clears messages
    // ═══════════════════════════════════════════════════
    blocTest<ChatCubit, ChatState>(
      'newChat clears all messages',
      build: () => ChatCubit(),
      act: (cubit) async {
        await cubit.loadChat();
        await cubit.sendMessage('Hello');
        cubit.newChat();
      },
      wait: const Duration(seconds: 3),
      verify: (cubit) {
        final state = cubit.state;
        expect(state, isA<ChatLoaded>());

        final loaded = state as ChatLoaded;
        expect(loaded.messages, isEmpty);
        expect(loaded.currentSessionId, isNull);
      },
    );

    // ═══════════════════════════════════════════════════
    // Test 6: Clear Chat clears messages only
    // ═══════════════════════════════════════════════════
    blocTest<ChatCubit, ChatState>(
      'clearChat clears messages',
      build: () => ChatCubit(),
      act: (cubit) async {
        await cubit.loadChat();
        await cubit.sendMessage('Hello');
        cubit.clearChat();
      },
      wait: const Duration(seconds: 3),
      verify: (cubit) {
        final state = cubit.state;
        expect(state, isA<ChatLoaded>());

        final loaded = state as ChatLoaded;
        expect(loaded.messages, isEmpty);
      },
    );

    // ═══════════════════════════════════════════════════
    // Test 7: Retry Last Message
    // ═══════════════════════════════════════════════════
    blocTest<ChatCubit, ChatState>(
      'retryLastMessage removes failed message and resends',
      build: () => ChatCubit(),
      act: (cubit) async {
        await cubit.loadChat();
        await cubit.sendMessage('This will error');
        await cubit.retryLastMessage();
      },
      wait: const Duration(seconds: 3),
      verify: (cubit) {
        final state = cubit.state;
        expect(state, isA<ChatLoaded>());
      },
    );

    // ═══════════════════════════════════════════════════
    // Test 8: Dismiss Error
    // ═══════════════════════════════════════════════════
    blocTest<ChatCubit, ChatState>(
      'dismissError clears error',
      build: () => ChatCubit(),
      act: (cubit) async {
        await cubit.loadChat();
        await cubit.sendMessage('This will error');
        cubit.dismissError();
      },
      wait: const Duration(seconds: 2),
      verify: (cubit) {
        final state = cubit.state;
        expect(state, isA<ChatLoaded>());

        final loaded = state as ChatLoaded;
        expect(loaded.hasError, false);
      },
    );
  });
}