import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/features/chat/data/mock_chats.dart';
import 'package:syntrace/features/chat/data/models/chat_error.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/data/models/chat_session.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatInitial());

  String? _lastFailedMessage;

  Future<void> loadChat() async {
    emit(const ChatLoading());

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final sessions = MockChats.sessions;
      emit(ChatLoaded(sessions: sessions));
    } catch (e) {
      _emitError(ChatErrorType.unknown);
    }
  }

  Future<void> openSession(ChatSession session) async {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final messages = session.id == '1'
          ? MockChats.messages
          : MockChats.messages.take(2).toList();

      emit(current.copyWith(
        currentSessionId: session.id,
        messages: messages,
        isSending: false,
        isStreaming: false,
        clearError: true,
      ));
    } catch (e) {
      _emitError(ChatErrorType.unknown);
    }
  }

  void newChat() {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;

    emit(current.copyWith(
      messages: [],
      clearSession: true,
      isSending: false,
      isStreaming: false,
      clearError: true,
    ));
  }

  Future<void> sendMessage(String text) async {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;

    final shouldFail = text.toLowerCase().contains('error');

    final userMessage = ChatMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.user,
      content: text,
      timestamp: DateTime.now(),
      hasError: shouldFail,
    );

    emit(current.copyWith(
      messages: [...current.messages, userMessage],
      isSending: !shouldFail,
      clearError: true,
    ));

    _lastFailedMessage = text;

    if (shouldFail) {
      emit((state as ChatLoaded).copyWith(
        isSending: false,
        error: ChatError.fromType(
          ChatErrorType.network,
          failedText: text,
        ),
      ));
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 1500));

      final aiMessage = ChatMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        role: ChatRole.ai,
        content:
            'This is a mock response.\n\nYou asked: **"$text"**\n\nThe real AI will be connected soon.',
        timestamp: DateTime.now(),
      );

      final updated = state as ChatLoaded;

      emit(updated.copyWith(
        messages: [...updated.messages, aiMessage],
        isSending: false,
      ));
    } catch (e) {
      _emitError(ChatErrorType.unknown);
    }
  }

  Future<void> retryLastMessage() async {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;

    final failedText = _lastFailedMessage ?? current.error?.failedMessageText;
    if (failedText == null) return;

    final messages = List<ChatMessage>.from(current.messages);
    if (messages.isNotEmpty && messages.last.hasError) {
      messages.removeLast();
    }

    emit(current.copyWith(
      messages: messages,
      clearError: true,
      isSending: false,
    ));

    await sendMessage(failedText);
  }

  void deleteFailedMessage() {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;

    final messages = List<ChatMessage>.from(current.messages);
    if (messages.isNotEmpty && messages.last.hasError) {
      messages.removeLast();
    }

    emit(current.copyWith(
      messages: messages,
      clearError: true,
    ));

    _lastFailedMessage = null;
  }

  void dismissError() {
    if (state is! ChatLoaded) return;
    emit((state as ChatLoaded).copyWith(clearError: true));
  }

  void clearChat() {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    emit(current.copyWith(messages: [], clearError: true));
  }

  void _emitError(ChatErrorType type) {
    if (state is! ChatLoaded) {
      emit(ChatErrorState(ChatError.fromType(type).message));
      return;
    }
    final current = state as ChatLoaded;
    emit(current.copyWith(
      error: ChatError.fromType(
        type,
        failedText: _lastFailedMessage,
      ),
      isSending: false,
    ));
  }
}