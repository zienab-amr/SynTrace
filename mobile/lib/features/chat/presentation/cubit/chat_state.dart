import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/chat/data/models/chat_error.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/data/models/chat_session.dart';

abstract class ChatState extends BaseState {
  const ChatState();
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatLoaded extends ChatState {
  final List<ChatSession> sessions;
  final List<ChatMessage> messages;
  final String? currentSessionId;
  final bool isSending;
  final bool isStreaming;
  final ChatError? error;

  const ChatLoaded({
    this.sessions = const [],
    this.messages = const [],
    this.currentSessionId,
    this.isSending = false,
    this.isStreaming = false,
    this.error,
  });

  ChatLoaded copyWith({
    List<ChatSession>? sessions,
    List<ChatMessage>? messages,
    String? currentSessionId,
    bool? isSending,
    bool? isStreaming,
    ChatError? error,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return ChatLoaded(
      sessions: sessions ?? this.sessions,
      messages: messages ?? this.messages,
      currentSessionId:
          clearSession ? null : (currentSessionId ?? this.currentSessionId),
      isSending: isSending ?? this.isSending,
      isStreaming: isStreaming ?? this.isStreaming,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get isBusy => isSending || isStreaming;
  bool get isEmpty => messages.isEmpty;
  bool get hasError => error != null;

  @override
  List<Object?> get props => [
        sessions,
        messages,
        currentSessionId,
        isSending,
        isStreaming,
        error,
      ];
}

class ChatErrorState extends ChatState {
  final String message;
  const ChatErrorState(this.message);

  @override
  List<Object?> get props => [message];
}