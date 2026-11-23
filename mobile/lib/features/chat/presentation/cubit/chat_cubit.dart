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

  final Uuid _uuid = const Uuid();

  String? _lastFailedMessage;
  List<String> _lastFailedQuotes = const [];
  String? _currentConversationId;
  CancelToken? _cancelToken;
  DateTime? _requestStartedAt;
  String? _firstClientMessageId;
  List<String> _turnQuotes = [];
  bool _isTurnActive = false;
  int _generation = 0;
  int _conversationVersion = 0;


  List<String> _parseQuotes(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  List<ChatMessage> _parseHistory(List data) {
    return data.expand((e) {
      final map = e as Map<String, dynamic>;
      return [
        ChatMessage(
          id: map['id']?.toString() ?? '',
          role: ChatRole.user,
          content: map['question']?.toString() ?? '',
          timestamp: DateTime.now(),
          quotedExcerpts: _parseQuotes(map['quotedExcerpts']),
        ),
        ChatMessage(
          id: 'ai-${map['id']}',
          role: ChatRole.ai,
          content: map['answer']?.toString() ?? '',
          timestamp: DateTime.now(),
        ),
      ];
    }).toList();
  }


  Future<void> loadChat() async {
    _invalidatePendingRequests();
    emit(const ChatLoading());
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.getConversations);
      if (response.statusCode == 200 && response.data is List) {
        final sessions = (response.data as List)
            .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
            .toList();
        if (isClosed) return;
        emit(ChatLoaded(sessions: sessions));
      } else {
        if (isClosed) return;
        emit(const ChatLoaded(sessions: []));
      }
    } catch (e) {
      if (isClosed) return;
      emit(const ChatLoaded(sessions: []));
    }
  }

  Future<void> openSession(ChatSession session) async {
    if (state is! ChatLoaded) return;
    _invalidatePendingRequests();
    final generation = _generation;
    _currentConversationId = session.id;
    final current = state as ChatLoaded;

    emit(current.copyWith(
      currentSessionId: session.id,
      messages: [],
      isSending: true,
      isStreaming: false,
      clearError: true,
    ));

    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.getConversationMessages(session.id),
      );
      if (generation != _generation || isClosed) return;

      final latest = state;
      if (latest is! ChatLoaded) return;

      if (response.statusCode == 200 && response.data is List) {
        emit(latest.copyWith(
          messages: _parseHistory(response.data as List),
          isSending: false,
          isStreaming: false,
        ));
      } else {
        emit(latest.copyWith(isSending: false, isStreaming: false));
      }
    } catch (e) {
      if (generation != _generation || isClosed) return;
      final latest = state;
      if (latest is ChatLoaded) {
        emit(latest.copyWith(isSending: false, isStreaming: false));
      }
      _handleDioError(e, 'Failed to load messages');
    }
  }

  void newChat() {
    if (state is! ChatLoaded) return;
    _invalidatePendingRequests();
    _currentConversationId = null;
    _lastFailedMessage = null;
    _lastFailedQuotes = const [];
    final current = state as ChatLoaded;
    emit(current.copyWith(
      messages: [],
      clearSession: true,
      isSending: false,
      isStreaming: false,
      clearError: true,
    ));
  }

  // ───────────────────────── Send / Append ─────────────────────────

  Future<void> sendMessage(String text, {List<String> quotedExcerpts = const []}) async {
    if (state is! ChatLoaded || text.trim().isEmpty) return;

    final current = state as ChatLoaded;
    final clientId = _uuid.v4();
    final isAppend = _isTurnActive && _firstClientMessageId != null;

    if (!isAppend) {
      _firstClientMessageId = clientId;
      _turnQuotes = [];
    }

    for (final q in quotedExcerpts) {
      if (!_turnQuotes.contains(q)) _turnQuotes.add(q);
    }
    final mergedQuotes = List<String>.from(_turnQuotes);

    final userMessage = ChatMessage(
      id: clientId,
      role: ChatRole.user,
      content: text,
      timestamp: DateTime.now(),
      quotedExcerpts: quotedExcerpts,
    );

    _lastFailedMessage = text;
    _lastFailedQuotes = quotedExcerpts;

    emit(current.copyWith(
      messages: [...current.messages, userMessage],
      isSending: true,
      clearError: true,
    ));

    if (isAppend) {
      final convVer = _conversationVersion;
      var iterations = 0;
      while (iterations < 10) {
        iterations++;
        final startedAt = _requestStartedAt;
        if (startedAt == null) break;
        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed >= const Duration(milliseconds: 300)) break;
        await Future.delayed(const Duration(milliseconds: 300) - elapsed);
        if (convVer != _conversationVersion || isClosed) return;
      }
    }

    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _generation++;
      _cancelToken!.cancel('Superseded by newer message');
      _cancelToken = null;
    }
    _requestStartedAt = null;

    _isTurnActive = true;
    final generation = _generation;

    await _sendRequest(
      question: text,
      clientMessageId: clientId,
      appendToMessageId: isAppend ? _firstClientMessageId : null,
      quotedExcerpts: mergedQuotes,
      generation: generation,
    );
  }

  Future<void> _sendRequest({
    required String question,
    required String clientMessageId,
    String? appendToMessageId,
    List<String> quotedExcerpts = const [],
    required int generation,
    bool isRetryAfterConflict = false,
  }) async {
    final token = CancelToken();
    _cancelToken = token;
    _requestStartedAt = DateTime.now();

    try {
      final data = <String, dynamic>{
        'question': question,
        'clientMessageId': clientMessageId,
      };
      if (quotedExcerpts.isNotEmpty) data['quotedExcerpts'] = quotedExcerpts;
      if (_currentConversationId != null) data['conversationId'] = _currentConversationId;
      if (appendToMessageId != null) data['appendToMessageId'] = appendToMessageId;

      final response = await ApiClient.instance.post(
        ApiEndpoints.askAssistant,
        data: data,
        cancelToken: token,
        options: Options(receiveTimeout: const Duration(seconds: 110)),
      );

      if (generation != _generation || isClosed) return;

      await _processSuccess(
        response: response,
        clientMessageId: clientMessageId,
        generation: generation,
      );
    } on DioException catch (e) {
      if (generation != _generation || isClosed) return;
      if (e.type == DioExceptionType.cancel) return;

      if (e.response?.statusCode == 409 && !isRetryAfterConflict) {
        await _handleConflict(
          question: question,
          clientMessageId: clientMessageId,
          quotedExcerpts: quotedExcerpts,
        );
        return;
      }

      _resetTurnState();
      _lastFailedMessage = question;
      _handleDioError(e, question);
    } catch (e) {
      if (generation != _generation || isClosed) return;
      _resetTurnState();
      _lastFailedMessage = question;
      _handleDioError(e, question);
    }
  }

  Future<void> _processSuccess({
    required Response response,
    required String clientMessageId,
    required int generation,
  }) async {
    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    final responseData = response.data;
    String aiResponseText = '';
    final jiraCards = <JiraCardModel>[];

    if (responseData is Map) {
      final newConversationId = responseData['conversationId']?.toString();
      if (newConversationId != null && newConversationId.isNotEmpty) {
        _currentConversationId = newConversationId;
      }
      _useServerMessageId(_firstClientMessageId ?? clientMessageId, responseData['messageId']?.toString());
      aiResponseText = responseData['answer']?.toString() ?? 'No response received.';
      if (responseData['links'] is List) {
        for (final link in responseData['links'] as List) {
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

    _resetTurnState();

    final aiMessageId = 'ai-${_uuid.v4()}';
    final aiMessage = ChatMessage(
      id: aiMessageId,
      role: ChatRole.ai,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
      jiraCards: jiraCards,
    );

    final latest = state;
    if (latest is! ChatLoaded) return;

    emit(latest.copyWith(
      messages: [...latest.messages, aiMessage],
      isSending: true,
      isStreaming: true,
    ));

    await _streamResponse(
      messageId: aiMessageId,
      fullText: aiResponseText,
      generation: generation,
    );
  }

  Future<void> _handleConflict({
    required String question,
    required String clientMessageId,
    required List<String> quotedExcerpts,
  }) async {
    // نحتفظ برسالة الـ user المحلية عشان ما تختفيش بعد الـ refresh
    final before = state;
    ChatMessage? pending;
    if (before is ChatLoaded) {
      for (final m in before.messages) {
        if (m.id == clientMessageId) pending = m;
      }
    }

    await _refreshConversationFromBackend(pendingMessage: pending);

    _isTurnActive = true;
    _firstClientMessageId = clientMessageId;
    _turnQuotes = List<String>.from(quotedExcerpts);
    final generation = ++_generation;

    await _sendRequest(
      question: question,
      clientMessageId: clientMessageId,
      appendToMessageId: null,
      quotedExcerpts: quotedExcerpts,
      generation: generation,
      isRetryAfterConflict: true,
    );
  }

  Future<void> _refreshConversationFromBackend({ChatMessage? pendingMessage}) async {
    if (_currentConversationId == null) return;
    try {
      final resp = await ApiClient.instance.get(
        ApiEndpoints.getConversationMessages(_currentConversationId!),
      );
      if (resp.statusCode != 200 || resp.data is! List) return;
      final refreshed = _parseHistory(resp.data as List);
      final latest = state;
      if (latest is ChatLoaded) {
        emit(latest.copyWith(
          messages: [...refreshed, if (pendingMessage != null) pendingMessage],
        ));
      }
    } catch (_) {}
  }

  void _useServerMessageId(String localId, String? serverId) {
    if (serverId == null || serverId.isEmpty || serverId == localId) return;
    final latest = state;
    if (latest is! ChatLoaded) return;

    final updated = latest.messages.map((m) {
      if (m.id != localId) return m;
      return ChatMessage(
        id: serverId,
        role: m.role,
        content: m.content,
        timestamp: m.timestamp,
        isStreaming: m.isStreaming,
        hasError: m.hasError,
        steps: m.steps,
        jiraCards: m.jiraCards,
        quotedExcerpts: m.quotedExcerpts,
      );
    }).toList();

    emit(latest.copyWith(messages: updated));
  }

  // ───────────────────────── Errors ─────────────────────────

  void _handleDioError(dynamic e, String failedText) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
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

  void _emitError(ChatErrorType type, {String? failedText}) {
    if (state is! ChatLoaded) {
      emit(ChatErrorState(ChatError.fromType(type).message));
      return;
    }
    final current = state as ChatLoaded;
    final hasPendingHttp = _cancelToken != null && !_cancelToken!.isCancelled;
    emit(current.copyWith(
      error: ChatError.fromType(type, failedText: failedText ?? _lastFailedMessage),
      isSending: hasPendingHttp,
      isStreaming: false,
    ));
  }

  
  Future<void> editMessage(String messageId, String newText) async {
    if (state is! ChatLoaded || newText.trim().isEmpty) return;
    _invalidatePendingRequests();
    final generation = _generation;
    final current = state as ChatLoaded;

    final index = current.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final quotes = current.messages[index].quotedExcerpts;
    final updatedMessages = current.messages.sublist(0, index);
    final clientMessageId = _uuid.v4();

    final userMessage = ChatMessage(
      id: clientMessageId,
      role: ChatRole.user,
      content: newText,
      timestamp: DateTime.now(),
      quotedExcerpts: quotes,
    );

    _lastFailedMessage = newText;
    _lastFailedQuotes = quotes;

    emit(current.copyWith(
      messages: [...updatedMessages, userMessage],
      isSending: true,
      isStreaming: false,
      clearError: true,
    ));

    final token = CancelToken();
    _cancelToken = token;
    _requestStartedAt = DateTime.now();

    try {
      final data = <String, dynamic>{
        'question': newText,
        'editedMessageId': messageId,
        'clientMessageId': clientMessageId,
      };
      if (quotes.isNotEmpty) data['quotedExcerpts'] = quotes;
      if (_currentConversationId != null) {
        data['conversationId'] = _currentConversationId;
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.askAssistant,
        data: data,
        cancelToken: token,
        options: Options(receiveTimeout: const Duration(seconds: 110)),
      );

      if (generation != _generation || isClosed) return;

      await _processSuccess(
        response: response,
        clientMessageId: clientMessageId,
        generation: generation,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (generation != _generation || isClosed) return;
      _cancelToken = null;
      _requestStartedAt = null;
      _handleDioError(e, newText);
    }
  }


  Future<void> deleteConversation(String id) async {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    try {
      await ApiClient.instance.delete(ApiEndpoints.deleteConversation(id));
      final updatedSessions = current.sessions.where((s) => s.id != id).toList();
      if (current.currentSessionId == id) newChat();
      final latest = state;
      if (latest is ChatLoaded) {
        emit(latest.copyWith(sessions: updatedSessions));
      }
    } catch (e) {
      _emitError(ChatErrorType.unknown);
    }
  }

  Future<void> _streamResponse({
    required String messageId,
    required String fullText,
    required int generation,
  }) async {
    final chunks = _splitIntoChunks(fullText);
    String accumulated = '';

    for (final chunk in chunks) {
      await Future.delayed(const Duration(milliseconds: 20));
      if (generation != _generation || isClosed) return;
      accumulated += chunk;
      final latest = state;
      if (latest is! ChatLoaded) return;

      final updatedMessages = latest.messages.map((m) {
        if (m.id == messageId) return m.copyWith(content: accumulated);
        return m;
      }).toList();

      emit(latest.copyWith(messages: updatedMessages, isSending: true, isStreaming: true));
    }

    if (generation != _generation || isClosed) return;
    final latest = state;
    if (latest is! ChatLoaded) return;

    final completedMessages = latest.messages.map((m) {
      if (m.id == messageId) return m.copyWith(content: fullText, isStreaming: false);
      return m;
    }).toList();

    final anyStreaming = completedMessages.any((m) => m.isStreaming);
    final hasPendingHttp = _cancelToken != null && !_cancelToken!.isCancelled;
    emit(latest.copyWith(
      messages: completedMessages,
      isStreaming: anyStreaming,
      isSending: anyStreaming || hasPendingHttp,
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
    if (buffer.isNotEmpty) chunks.add(buffer.toString());
    return chunks;
  }

  Future<void> retryLastMessage() async {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    final failedText = _lastFailedMessage ?? current.error?.failedMessageText;
    if (failedText == null || failedText.isEmpty) return;
    final quotes = _lastFailedQuotes;

    final messages = List<ChatMessage>.from(current.messages);
    if (messages.isNotEmpty && messages.last.hasError) messages.removeLast();
    if (messages.isNotEmpty && messages.last.role == ChatRole.user) messages.removeLast();

    emit(current.copyWith(messages: messages, clearError: true, isSending: false, isStreaming: false));
    await sendMessage(failedText, quotedExcerpts: quotes);
  }

  void deleteFailedMessage() {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    final messages = List<ChatMessage>.from(current.messages);
    if (messages.isNotEmpty && messages.last.hasError) messages.removeLast();
    emit(current.copyWith(messages: messages, clearError: true));
    _lastFailedMessage = null;
    _lastFailedQuotes = const [];
  }

  void dismissError() {
    if (state is! ChatLoaded) return;
    emit((state as ChatLoaded).copyWith(clearError: true));
  }

  void clearChat() {
    newChat();
  }

  void _resetTurnState() {
    _isTurnActive = false;
    _firstClientMessageId = null;
    _turnQuotes = [];
    _cancelToken = null;
    _requestStartedAt = null;
  }

  void _invalidatePendingRequests() {
    _generation++;
    _conversationVersion++;
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('Conversation changed');
    }
    _resetTurnState();
  }
}