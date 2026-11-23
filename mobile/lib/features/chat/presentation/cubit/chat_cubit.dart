import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/features/chat/data/models/chat_error.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/data/models/chat_session.dart';
import 'package:syntrace/features/chat/data/models/jira_card_model.dart';
import 'chat_state.dart';
import 'package:uuid/uuid.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatInitial());

  String? _lastFailedMessage;
  String? _currentConversationId;
  String? _activeMessageId;
  CancelToken? _cancelToken;

  Future<void> loadChat() async {
    emit(const ChatLoading());
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.getConversations);
      if (response.statusCode == 200 && response.data is List) {
        final sessions = (response.data as List)
            .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
            .toList();
        emit(ChatLoaded(sessions: sessions));
      } else {
        emit(const ChatLoaded(sessions: []));
      }
    } catch (e) {
      emit(const ChatLoaded(sessions: []));
    }
  }

  Future<void> openSession(ChatSession session) async {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    
    _currentConversationId = session.id;

    emit(current.copyWith(
      currentSessionId: session.id,
      isSending: true,
      clearError: true,
      messages: [],
    ));

    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.getConversationMessages(session.id),
      );

      if (response.statusCode == 200 && response.data is List) {
        final messages = (response.data as List).map((e) {
          final map = e as Map<String, dynamic>;
          final userMsg = ChatMessage(
            id: map['id']?.toString() ?? '',
            role: ChatRole.user,
            content: map['question']?.toString() ?? '',
            timestamp: DateTime.now(),
          );
          final aiMsg = ChatMessage(
            id: 'ai-${map['id']}',
            role: ChatRole.ai,
            content: map['answer']?.toString() ?? '',
            timestamp: DateTime.now(),
          );
          return [userMsg, aiMsg];
        }).expand((e) => e).toList();

        emit(current.copyWith(messages: messages, isSending: false));
      } else {
        emit(current.copyWith(isSending: false));
      }
    } catch (e) {
      emit(current.copyWith(isSending: false));
      _handleDioError(e, 'Failed to load messages');
    }
  }

  void newChat() {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    _currentConversationId = null;
    _activeMessageId = null;
    emit(current.copyWith(
      messages: [],
      clearSession: true,
      isSending: false,
      clearError: true,
    ));
  }

  Future<void> sendMessage(String text) async {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;

    String messageId = const Uuid().v4();
    final userMessage = ChatMessage(
      id: messageId,
      role: ChatRole.user,
      content: text,
      timestamp: DateTime.now(),
    );

    bool isAppend = current.isSending && _activeMessageId != null;

    if (!isAppend) {
      _activeMessageId = messageId;
    }

    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('New message sent');
    }
    _cancelToken = CancelToken();

    emit(current.copyWith(
      messages: [...current.messages, userMessage],
      isSending: true,
      clearError: true,
    ));

    _lastFailedMessage = text;

    try {
      final Map<String, dynamic> data = {'question': text};
      if (_currentConversationId != null) {
        data['conversationId'] = _currentConversationId;
      }
      if (isAppend) {
        data['appendToMessageId'] = _activeMessageId;
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.askAssistant,
        data: data,
        cancelToken: _cancelToken, 
        options: Options(receiveTimeout: const Duration(seconds: 110)),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        String aiResponseText = '';
        List<JiraCardModel> jiraCards = [];
        
        if (responseData is Map) {
          String? newConversationId = responseData['conversationId']?.toString();
          if (newConversationId != null) {
            _currentConversationId = newConversationId;
          }

          aiResponseText = responseData['answer']?.toString() ?? 'No response received.';
          
          if (responseData['links'] is List) {
            final links = responseData['links'] as List;
            for (var link in links) {
              if (link is Map) {
                jiraCards.add(JiraCardModel(
                  issueKey: link['key']?.toString() ?? '',
                  summary: link['summary']?.toString() ?? '',
                  status: link['status']?.toString() ?? '',
                  statusCategory: link['statusCategory']?.toString() ?? '',
                  priority: link['priority']?.toString() ?? '',
                  issueType: link['type']?.toString() ?? '',
                  url: link['url']?.toString() ?? '',
                ));
              }
            }
          }
        } else {
          aiResponseText = responseData.toString();
        }

        final aiMessageId = 'ai-${const Uuid().v4()}';
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

        await _streamResponse(messageId: aiMessageId, fullText: aiResponseText);
        _activeMessageId = null;
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      _handleDioError(e, text);
    }
  }

  void _handleDioError(dynamic e, String failedText) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        _emitError(ChatErrorType.network, failedText: failedText);
      } else if (e.type == DioExceptionType.receiveTimeout) {
        _emitError(ChatErrorType.timeout, failedText: failedText);
      } else {
        final status = e.response?.statusCode;
        if (status == 401) {
          _emitError(ChatErrorType.unauthorized, failedText: failedText);
        } else if (status == 403) {
          _emitError(ChatErrorType.forbidden, failedText: failedText);
        } else if (status == 400) {
          _emitError(ChatErrorType.badRequest, failedText: failedText);
        } else if (status != null && status >= 500) {
          _emitError(ChatErrorType.server, failedText: failedText);
        } else {
          _emitError(ChatErrorType.unknown, failedText: failedText);
        }
      }
    } else {
      _emitError(ChatErrorType.unknown, failedText: failedText);
    }
  }

  Future<void> editMessage(String messageId, String newText) async {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;

    int index = current.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    List<ChatMessage> updatedMessages = current.messages.sublist(0, index);

    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.user,
      content: newText,
      timestamp: DateTime.now(),
    );

    emit(current.copyWith(
      messages: [...updatedMessages, userMessage],
      isSending: true,
      clearError: true,
    ));

    try {
      final Map<String, dynamic> data = {
        'question': newText,
        'editedMessageId': messageId,
      };
      if (_currentConversationId != null) {
        data['conversationId'] = _currentConversationId;
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.askAssistant,
        data: data,
        options: Options(receiveTimeout: const Duration(seconds: 110)),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        String aiResponseText = responseData['answer']?.toString() ?? '';
        
        final aiMessage = ChatMessage(
          id: 'ai-${const Uuid().v4()}',
          role: ChatRole.ai,
          content: aiResponseText,
          timestamp: DateTime.now(),
        );

        final currentState = state as ChatLoaded;
        emit(currentState.copyWith(
          messages: [...currentState.messages, aiMessage],
          isSending: false,
        ));
      }
    } catch (e) {
      _handleDioError(e, newText);
    }
  }

  Future<void> deleteConversation(String id) async {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;

    try {
      await ApiClient.instance.delete(ApiEndpoints.deleteConversation(id));
      final updatedSessions = current.sessions.where((s) => s.id != id).toList();
      if (current.currentSessionId == id) {
        newChat();
      }
      emit((state as ChatLoaded).copyWith(sessions: updatedSessions));
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
    
    if (messages.isNotEmpty && messages.last.role == ChatRole.user) {
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

    emit(current.copyWith(messages: messages, clearError: true));
    _lastFailedMessage = null;
  }

  void dismissError() {
    if (state is! ChatLoaded) return;
    emit((state as ChatLoaded).copyWith(clearError: true));
  }

  void clearChat() {
    newChat();
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