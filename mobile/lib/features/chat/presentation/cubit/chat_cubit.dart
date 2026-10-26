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
      await Future.delayed(const Duration(milliseconds: 500));

      final aiMessageId = 'ai-${DateTime.now().millisecondsSinceEpoch}';
      final fullResponse =
          'This is a mock response.\n\nYou asked: **"$text"**\n\nThe real AI will be connected soon.';

      final aiMessage = ChatMessage(
        id: aiMessageId,
        role: ChatRole.ai,
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      final currentState = state as ChatLoaded;

      emit(currentState.copyWith(
        messages: [...currentState.messages, aiMessage],
        isSending: false,
        isStreaming: true,
      ));

      await _streamResponse(
        messageId: aiMessageId,
        fullText: fullResponse,
      );
    } catch (e) {
      _emitError(ChatErrorType.unknown);
    }
  }

  Future<void> _streamResponse({
    required String messageId,
    required String fullText,
  }) async {
    final chunks = _splitIntoChunks(fullText);
    String accumulated = '';

    for (final chunk in chunks) {
      await Future.delayed(const Duration(milliseconds: 30));

      accumulated += chunk;

      if (state is! ChatLoaded) return;
      final current = state as ChatLoaded;

      final updatedMessages = current.messages.map((m) {
        if (m.id == messageId) {
          return m.copyWith(content: accumulated);
        }
        return m;
      }).toList();

      emit(current.copyWith(messages: updatedMessages));
    }

    if (state is! ChatLoaded) return;
    final finalState = state as ChatLoaded;

    final completedMessages = finalState.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(
          content: fullText,
          isStreaming: false,
        );
      }
      return m;
    }).toList();

    emit(finalState.copyWith(
      messages: completedMessages,
      isStreaming: false,
    ));
  }

  List<String> _splitIntoChunks(String text) {
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);

      final isBreakChar = char == ' ' || char == '\n';
      final isChunkFull = buffer.length >= 3;

      if (isBreakChar || isChunkFull) {
        chunks.add(buffer.toString());
        buffer.clear();
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }

    return chunks;
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
      isStreaming: false,
    ));
  }
}