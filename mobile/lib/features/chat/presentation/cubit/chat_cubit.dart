import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/services/chat_local_storage_service.dart';
import 'package:syntrace/features/chat/data/models/chat_error.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/data/models/chat_session.dart';
import 'package:syntrace/features/chat/data/models/jira_card_model.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatInitial());

  String? _lastFailedMessage;

  Future<void> loadChat() async {
    emit(const ChatLoading());

    try {
      final cachedSessions = await ChatLocalStorageService.instance.loadSessions();
      
      if (cachedSessions != null && cachedSessions.isNotEmpty) {
        emit(ChatLoaded(sessions: cachedSessions));
      } else {
        emit(const ChatLoaded(sessions: []));
      }
    } catch (e) {
      _emitError(ChatErrorType.unknown);
    }
  }

  Future<void> openSession(ChatSession session) async {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;

    try {
      final cachedMessages = await ChatLocalStorageService.instance.loadMessages(session.id);

      emit(current.copyWith(
        currentSessionId: session.id,
        messages: cachedMessages ?? [],
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

    String sessionId = current.currentSessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    List<ChatSession> updatedSessions = List.from(current.sessions);

    if (current.currentSessionId == null) {
      final newSession = ChatSession(
        id: sessionId,
        title: text.length > 20 ? '${text.substring(0, 20)}...' : text,
        lastMessageAt: DateTime.now(),
      );
      updatedSessions.insert(0, newSession);
      await ChatLocalStorageService.instance.saveSessions(updatedSessions);
    }

    final userMessage = ChatMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.user,
      content: text,
      timestamp: DateTime.now(),
    );

    emit(current.copyWith(
      sessions: updatedSessions,
      currentSessionId: sessionId,
      messages: [...current.messages, userMessage],
      isSending: true,
      clearError: true,
    ));

    _lastFailedMessage = text;

    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.askAssistant,
        data: {'question': text},
      );

      if (response.statusCode == 200) {
        final dynamic data = response.data;
        String aiResponseText = '';
        List<JiraCardModel> jiraCards = [];

        if (data is Map) {
          aiResponseText = data['answer']?.toString() ?? 'No response received.';
          if (aiResponseText.contains('links: [')) {
            aiResponseText = aiResponseText.split('links: [').first.trim();
          }
          if (data['links'] is List) {
            final links = data['links'] as List;
            for (var link in links) {
              if (link is Map) {
                jiraCards.add(JiraCardModel(
                  issueKey: link['key']?.toString() ?? 'LINK',
                  summary: 'Jira Ticket Reference', 
                  status: 'Open',
                  statusCategory: 'todo',
                  priority: 'Medium',
                  issueType: 'Task',
                  url: link['url']?.toString() ?? '',
                ));
              }
            }
          }
        } else {
          aiResponseText = data.toString();
        }

        final aiMessageId = 'ai-${DateTime.now().millisecondsSinceEpoch}';
        final aiMessage = ChatMessage(
          id: aiMessageId,
          role: ChatRole.ai,
          content: '',
          timestamp: DateTime.now(),
          isStreaming: true,
          jiraCards: jiraCards,
        );

        final currentState = state as ChatLoaded;
        emit(currentState.copyWith(
          messages: [...currentState.messages, aiMessage],
          isSending: false,
          isStreaming: true,
        ));

        await _streamResponse(
          sessionId: sessionId,
          messageId: aiMessageId,
          fullText: aiResponseText,
        );
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } on DioException catch (e) {
      _emitError(ChatErrorType.network, failedText: text);
    } catch (e) {
      _emitError(ChatErrorType.unknown, failedText: text);
    }
  }

  Future<void> _streamResponse({
    required String sessionId,
    required String messageId,
    required String fullText,
  }) async {
    final chunks = _splitIntoChunks(fullText);
    String accumulated = '';

    for (final chunk in chunks) {
      await Future.delayed(const Duration(milliseconds: 20));

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
        return m.copyWith(content: fullText, isStreaming: false);
      }
      return m;
    }).toList();

    await ChatLocalStorageService.instance.saveMessages(sessionId, completedMessages);

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

    emit(current.copyWith(messages: messages, clearError: true, isSending: false));
    await sendMessage(failedText);
  }

  void deleteFailedMessage() {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;

    final messages = List<ChatMessage>.from(current.messages);
    if (messages.isNotEmpty && messages.last.hasError) {
      messages.removeLast();
    }
    
    if (current.currentSessionId != null) {
      ChatLocalStorageService.instance.saveMessages(current.currentSessionId!, messages);
    }

    emit(current.copyWith(messages: messages, clearError: true));
    _lastFailedMessage = null;
  }

  void dismissError() {
    if (state is! ChatLoaded) return;
    emit((state as ChatLoaded).copyWith(clearError: true));
  }

  void clearChat() {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    if (current.currentSessionId != null) {
      ChatLocalStorageService.instance.saveMessages(current.currentSessionId!, []);
    }
    emit(current.copyWith(messages: [], clearError: true));
  }

  void _emitError(ChatErrorType type, {String? failedText}) {
    if (state is! ChatLoaded) {
      emit(ChatErrorState(ChatError.fromType(type).message));
      return;
    }
    final current = state as ChatLoaded;
    emit(current.copyWith(
      error: ChatError.fromType(type, failedText: failedText ?? _lastFailedMessage),
      isSending: false,
      isStreaming: false,
    ));
  }
}