import 'dart:async';
import 'package:dio/dio.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/features/chat/data/models/chat_error.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/data/models/chat_session.dart';
import 'package:syntrace/features/chat/data/models/chat_source_model.dart';
import 'chat_state.dart';
import 'package:uuid/uuid.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatInitial()) {
    final scope = CacheScope.fromCurrentUser();
    if (scope != null) {
      try {
        _guard = CacheSessionGuard.capture(scope);
      } catch (_) {}
    }
    _session.userNotifier.addListener(_onSessionChanged);
  }

  final _session = CurrentUserService.instance;
  CacheSessionGuard? _guard;
  bool _appendWaiting = false;
  bool _needsHistoryRefresh = false;
  bool get _sessionValid => !isClosed && _guard?.isValid == true;
  bool _isCurrent(int generation) => _sessionValid && generation == _generation;
  bool get canSend =>
      _sessionValid &&
      !_appendWaiting &&
      !_needsHistoryRefresh &&
      state is ChatLoaded &&
      !(state as ChatLoaded).isStreaming &&
      (!(state as ChatLoaded).isSending || _isTurnActive);

  void _onSessionChanged() {
    if (_sessionValid || isClosed) return;
    _invalidatePendingRequests();
    _currentConversationId = null;
    emit(const ChatErrorState('Your session has changed. Reopen the chat.'));
  }

  Options _requestOptions({bool mutation = false}) => Options(
    extra: {
      'auth_generation': _guard!.generation,
      if (mutation) 'allow_retry': false,
    },
    receiveTimeout: mutation ? const Duration(seconds: 110) : null,
  );

  void _requireStatus(Response response, int expected) {
    if (response.statusCode != expected) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }

  bool _validInput(String text, List<String> quotes) =>
      text.trim().isNotEmpty &&
      text.trim().length <= 2000 &&
      quotes.length <= 5 &&
      quotes.every((q) => q.trim().isNotEmpty && q.trim().length <= 1000) &&
      quotes.fold<int>(0, (sum, q) => sum + q.trim().length) <= 4000;

  void _invalidInput() => _emitError(ChatErrorType.badRequest);

  final Uuid _uuid = const Uuid();

  String? _lastFailedMessage;
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
    final rows = data
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    rows.sort(
      (a, b) =>
          (a['sequenceNumber'] as num).compareTo(b['sequenceNumber'] as num),
    );
    final knownMessages = <String, ChatMessage>{
      if (state is ChatLoaded)
        for (final message in (state as ChatLoaded).messages)
          message.id: message,
    };
    final seen = <String>{};
    final result = <ChatMessage>[];
    for (final row in rows) {
      final id = row['id'] as String;
      if (id.isEmpty || !seen.add(id)) {
        throw const FormatException('Invalid message ID.');
      }
      final timestamp = DateTime.parse(row['createdAt'] as String);
      final status = row['status'] as String;
      final answered = status.toLowerCase() == 'answered';
      result.add(
        ChatMessage(
          id: id,
          role: ChatRole.user,
          content: row['question'] as String,
          timestamp: timestamp,
          hasError: !answered && status.toLowerCase() != 'pending',
          quotedExcerpts: row.containsKey('quotedExcerpts')
              ? _parseQuotes(row['quotedExcerpts'])
              : knownMessages[id]?.quotedExcerpts ?? const [],
        ),
      );
      if (answered) {
        result.add(
          ChatMessage(
            id: 'ai-$id',
            role: ChatRole.ai,
            content: row['answer'] as String,
            timestamp: timestamp,
            sources: ChatSourceModel.parseList(row['links']),
            meeting: row.containsKey('meeting')
                ? row['meeting'] as Map<String, dynamic>?
                : knownMessages['ai-$id']?.content == row['answer']
                ? knownMessages['ai-$id']?.meeting
                : null,
            choices: row.containsKey('choices')
                ? ChatMessage.parseChoices(row['choices'])
                : knownMessages['ai-$id']?.content == row['answer']
                ? knownMessages['ai-$id']!.choices
                : const [],
          ),
        );
      }
    }
    return result;
  }

  List<ChatSession> _parseSessions(dynamic data) {
    if (data is! List) {
      throw const FormatException('Invalid conversation list.');
    }
    final sessions = data
        .map(
          (item) =>
              ChatSession.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    if (sessions.any((s) => s.id.isEmpty) ||
        sessions.map((s) => s.id).toSet().length != sessions.length) {
      throw const FormatException('Invalid conversation ID.');
    }
    return sessions;
  }

  Future<void> loadChat() async {
    if (!_sessionValid) {
      if (!isClosed) {
        emit(
          const ChatErrorState('Your session is unavailable. Reopen the chat.'),
        );
      }
      return;
    }
    _invalidatePendingRequests();
    _currentConversationId = null;
    final generation = _generation;
    emit(const ChatLoading());
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.getConversations,
        options: _requestOptions(),
      );
      if (!_isCurrent(generation)) return;
      _requireStatus(response, 200);
      emit(ChatLoaded(sessions: _parseSessions(response.data)));
    } catch (e) {
      if (!_isCurrent(generation)) return;
      _handleDioError(e, '');
    }
  }

  Future<void> openSession(ChatSession session) async {
    if (!_sessionValid || state is! ChatLoaded || session.id.isEmpty) return;
    _invalidatePendingRequests();
    final generation = _generation;
    _currentConversationId = session.id;
    final current = state as ChatLoaded;

    emit(
      current.copyWith(
        currentSessionId: session.id,
        messages: [],
        isSending: true,
        isStreaming: false,
        clearError: true,
      ),
    );

    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.getConversationMessages(session.id),
        options: _requestOptions(),
      );
      if (!_isCurrent(generation)) return;

      final latest = state;
      if (latest is! ChatLoaded) return;

      _requireStatus(response, 200);
      emit(
        latest.copyWith(
          messages: _parseHistory(response.data as List),
          isSending: false,
          isStreaming: false,
        ),
      );
    } catch (e) {
      if (!_isCurrent(generation)) return;
      final latest = state;
      if (latest is ChatLoaded) {
        emit(latest.copyWith(isSending: false, isStreaming: false));
      }
      _needsHistoryRefresh = true;
      _handleDioError(e, '');
    }
  }

  void newChat() {
    if (!_sessionValid || state is! ChatLoaded) return;
    _invalidatePendingRequests();
    _currentConversationId = null;
    _lastFailedMessage = null;
    final current = state as ChatLoaded;
    emit(
      current.copyWith(
        messages: [],
        clearSession: true,
        isSending: false,
        isStreaming: false,
        clearError: true,
      ),
    );
  }

  // ───────────────────────── Send / Append ─────────────────────────

  Future<bool> selectChoice(String answerId, String choice) async {
    final current = state;
    if (current is! ChatLoaded ||
        current.isBusy ||
        current.messages.length < 2) {
      return false;
    }
    final answer = current.messages.last;
    final question = current.messages[current.messages.length - 2];
    if (answer.id != answerId ||
        answer.role != ChatRole.ai ||
        !answer.choices.contains(choice) ||
        question.role != ChatRole.user) {
      return false;
    }
    if (answer.meeting?['needsProject'] == true) return sendMessage(choice);
    final arabic = RegExp(r'[؀-ۿ]').hasMatch(question.content);
    final label = arabic ? 'الاختيار' : 'Selected option';
    return sendMessage(
      '${question.content}\n\n$label: $choice',
      quotedExcerpts: question.quotedExcerpts,
    );
  }

  Future<bool> sendMessage(
    String text, {
    List<String> quotedExcerpts = const [],
    String? transcript,
  }) async {
    if (!canSend || (transcript != null && _isTurnActive)) return false;
    final question = text.trim();
    final clientId = _uuid.v4();
    final appendId = _isTurnActive ? _firstClientMessageId : null;
    final mergedQuotes = <String>{
      if (appendId != null) ..._turnQuotes,
      ...quotedExcerpts.map((q) => q.trim()),
    }.toList();
    if (!_validInput(question, mergedQuotes)) {
      _invalidInput();
      return false;
    }
    final convVer = _conversationVersion;
    if (appendId != null) {
      _appendWaiting = true;
      final startedAt = _requestStartedAt;
      final wait = startedAt == null
          ? Duration.zero
          : const Duration(milliseconds: 300) -
                DateTime.now().difference(startedAt);
      // Keep the root registration grace period from the original client.
      if (wait > Duration.zero) await Future.delayed(wait);
      if (!_sessionValid || convVer != _conversationVersion) return false;
      // The original answer may have arrived during the grace period.
      // Wait for its presentation to finish rather than cutting it off.
      while (state is ChatLoaded &&
          !_isTurnActive &&
          (state as ChatLoaded).isBusy) {
        await Future.delayed(const Duration(milliseconds: 25));
        if (!_sessionValid || convVer != _conversationVersion) return false;
      }
      _appendWaiting = false;
      if (_needsHistoryRefresh || state is! ChatLoaded) return false;
    }
    final current = state as ChatLoaded;
    final effectiveAppend = _isTurnActive ? appendId : null;
    final effectiveQuotes = effectiveAppend == null
        ? quotedExcerpts.map((q) => q.trim()).toSet().toList()
        : mergedQuotes;
    final generation = ++_generation;
    _cancelToken?.cancel('Superseded by newer message');
    _firstClientMessageId = effectiveAppend ?? clientId;
    _turnQuotes = effectiveQuotes;
    _lastFailedMessage = question;
    _isTurnActive = true;
    final userMessage = ChatMessage(
      id: clientId,
      role: ChatRole.user,
      content: question,
      timestamp: DateTime.now(),
      quotedExcerpts: quotedExcerpts,
    );
    emit(
      current.copyWith(
        messages: [...current.messages, userMessage],
        isSending: true,
        clearError: true,
      ),
    );
    unawaited(
      _sendRequest(
        question: question,
        clientMessageId: clientId,
        appendToMessageId: effectiveAppend,
        quotedExcerpts: effectiveQuotes,
        transcript: transcript,
        generation: generation,
      ),
    );
    return true;
  }

  Future<void> _sendRequest({
    required String question,
    required String clientMessageId,
    String? appendToMessageId,
    String? transcript,
    List<String> quotedExcerpts = const [],
    required int generation,
  }) async {
    final token = CancelToken();
    _cancelToken = token;
    _requestStartedAt = DateTime.now();

    try {
      final data = <String, dynamic>{
        'question': question,
        'clientMessageId': clientMessageId,
        'transcript': ?transcript,
        if (transcript != null)
          'meetingDate': DateTime.now().toIso8601String().split('T').first,
      };
      if (quotedExcerpts.isNotEmpty) data['quotedExcerpts'] = quotedExcerpts;
      if (_currentConversationId != null) {
        data['conversationId'] = _currentConversationId;
      }
      if (appendToMessageId != null) {
        data['appendToMessageId'] = appendToMessageId;
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.askAssistant,
        data: data,
        cancelToken: token,
        options: _requestOptions(mutation: true),
      );

      if (!_isCurrent(generation)) return;

      await _processSuccess(
        response: response,
        clientMessageId: clientMessageId,
        generation: generation,
      );
    } on DioException catch (e) {
      if (!_isCurrent(generation)) return;
      if (e.type == DioExceptionType.cancel) return;

      _resetTurnState();
      _lastFailedMessage = question;
      _needsHistoryRefresh = true;
      _handleDioError(e, question);
    } catch (e) {
      if (!_isCurrent(generation)) return;
      _resetTurnState();
      _lastFailedMessage = question;
      _needsHistoryRefresh = true;
      _handleDioError(e, question);
    }
  }

  Future<void> _processSuccess({
    required Response response,
    required String clientMessageId,
    required int generation,
  }) async {
    _requireStatus(response, 200);
    if (!_isCurrent(generation)) return;
    if (response.data is! Map) {
      throw const FormatException('Invalid assistant response.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final conversationId = data['conversationId'];
    final messageId = data['messageId'];
    final answer = data['answer'];
    if (conversationId is! String ||
        conversationId.isEmpty ||
        messageId is! String ||
        messageId.isEmpty ||
        answer is! String ||
        answer.trim().isEmpty) {
      throw const FormatException('Incomplete assistant response.');
    }
    _currentConversationId = conversationId;
    final sources = ChatSourceModel.parseList(data['links']);
    final rootId = _firstClientMessageId ?? clientMessageId;
    final savedQuotes = List<String>.of(_turnQuotes);
    _resetTurnState();
    _lastFailedMessage = null;
    final latest = state;
    if (latest is! ChatLoaded) return;
    final aiMessageId = 'ai-$messageId';
    final aiMessage = ChatMessage(
      id: aiMessageId,
      role: ChatRole.ai,
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
      sources: sources,
      choices: ChatMessage.parseChoices(
        data['choices'] ??
            (data['meeting'] is Map ? data['meeting']['choices'] : null),
      ),
      meeting: data['meeting'] is Map<String, dynamic> ? data['meeting'] : null,
    );
    final updatedMessages = latest.messages.map((m) {
      if (m.id != rootId) return m;
      return ChatMessage(
        id: messageId,
        role: m.role,
        content: m.content,
        timestamp: m.timestamp,
        quotedExcerpts: savedQuotes.isEmpty ? m.quotedExcerpts : savedQuotes,
      );
    }).toList();
    emit(
      latest.copyWith(
        currentSessionId: conversationId,
        messages: [...updatedMessages, aiMessage],
        isSending: true,
        isStreaming: true,
      ),
    );
    await _streamResponse(
      messageId: aiMessageId,
      fullText: answer,
      generation: generation,
    );
    if (!_isCurrent(generation)) return;
    // Server history is authoritative for appended/edited turns and persisted IDs.
    // A refresh failure must not discard the answer that was already received.
    try {
      final history = await ApiClient.instance.get(
        ApiEndpoints.getConversationMessages(conversationId),
        options: _requestOptions(),
      );
      if (!_isCurrent(generation)) return;
      _requireStatus(history, 200);
      final refreshed = _parseHistory(history.data as List);
      final current = state;
      if (current is ChatLoaded) emit(current.copyWith(messages: refreshed));
      final list = await ApiClient.instance.get(
        ApiEndpoints.getConversations,
        options: _requestOptions(),
      );
      if (!_isCurrent(generation)) return;
      _requireStatus(list, 200);
      final currentList = state;
      if (currentList is ChatLoaded) {
        emit(currentList.copyWith(sessions: _parseSessions(list.data)));
      }
    } catch (e) {
      if (!_isCurrent(generation)) return;
      if (e is DioException && [401, 403].contains(e.response?.statusCode)) {
        _invalidatePendingRequests();
        _currentConversationId = null;
        emit(
          const ChatErrorState('Access to this conversation is restricted.'),
        );
        return;
      }
      _needsHistoryRefresh = true;
      _emitError(ChatErrorType.unknown);
    } finally {
      if (_isCurrent(generation) && state is ChatLoaded) {
        emit(
          (state as ChatLoaded).copyWith(isSending: false, isStreaming: false),
        );
      }
    }
  }

  // ───────────────────────── Errors ─────────────────────────

  void _handleDioError(dynamic e, String failedText) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        _emitError(ChatErrorType.network, failedText: failedText);
      } else if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
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
    if (!_sessionValid) return;
    if (type == ChatErrorType.unauthorized || type == ChatErrorType.forbidden) {
      _invalidatePendingRequests();
      _currentConversationId = null;
      emit(ChatErrorState(ChatError.fromType(type).message));
      return;
    }
    if (state is! ChatLoaded) {
      emit(ChatErrorState(ChatError.fromType(type).message));
      return;
    }
    final current = state as ChatLoaded;
    final hasPendingHttp = _cancelToken != null && !_cancelToken!.isCancelled;
    emit(
      current.copyWith(
        error: _needsHistoryRefresh
            ? ChatError(
                type: type,
                message:
                    'Refresh the conversation before trying again. ${ChatError.fromType(type).message}',
              )
            : ChatError.fromType(
                type,
                failedText: failedText ?? _lastFailedMessage,
              ),
        isSending: hasPendingHttp,
        isStreaming: false,
      ),
    );
  }

  Future<void> editMessage(String messageId, String newText) async {
    if (!canSend ||
        state is! ChatLoaded ||
        (state as ChatLoaded).isBusy ||
        _currentConversationId == null) {
      return;
    }
    final current = state as ChatLoaded;

    final index = current.messages.indexWhere((m) => m.id == messageId);
    if (index == -1 ||
        current.messages[index].role != ChatRole.user ||
        !current.messages.any((m) => m.id == 'ai-$messageId')) {
      return;
    }
    final quotes = current.messages[index].quotedExcerpts;
    if (!_validInput(newText, quotes)) {
      _invalidInput();
      return;
    }
    _invalidatePendingRequests();
    final generation = _generation;
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

    emit(
      current.copyWith(
        messages: [...updatedMessages, userMessage],
        isSending: true,
        isStreaming: false,
        clearError: true,
      ),
    );

    _turnQuotes = List.of(quotes);
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
        options: _requestOptions(mutation: true),
      );

      if (!_isCurrent(generation)) return;

      await _processSuccess(
        response: response,
        clientMessageId: clientMessageId,
        generation: generation,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (!_isCurrent(generation)) return;
      _resetTurnState();
      _needsHistoryRefresh = true;
      emit(current.copyWith(isSending: false, isStreaming: false));
      _handleDioError(e, newText);
    }
  }

  Future<void> deleteConversation(String id) async {
    if (!_sessionValid ||
        state is! ChatLoaded ||
        (state as ChatLoaded).isBusy) {
      return;
    }
    final generation = _generation;
    try {
      final response = await ApiClient.instance.delete(
        ApiEndpoints.deleteConversation(id),
        options: _requestOptions(mutation: true),
      );
      if (!_isCurrent(generation)) return;
      _requireStatus(response, 204);
      final latest = state;
      if (latest is! ChatLoaded) return;
      final updated = latest.sessions.where((s) => s.id != id).toList();
      if (latest.currentSessionId == id) {
        newChat();
      }
      final current = state;
      if (current is ChatLoaded) emit(current.copyWith(sessions: updated));
    } catch (e) {
      if (!_isCurrent(generation)) return;
      _handleDioError(e, '');
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
      if (!_isCurrent(generation)) return;
      accumulated += chunk;
      final latest = state;
      if (latest is! ChatLoaded) return;

      final updatedMessages = latest.messages.map((m) {
        if (m.id == messageId) return m.copyWith(content: accumulated);
        return m;
      }).toList();

      emit(
        latest.copyWith(
          messages: updatedMessages,
          isSending: true,
          isStreaming: true,
        ),
      );
    }

    if (!_isCurrent(generation)) return;
    final latest = state;
    if (latest is! ChatLoaded) return;

    final completedMessages = latest.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(content: fullText, isStreaming: false);
      }
      return m;
    }).toList();

    final anyStreaming = completedMessages.any((m) => m.isStreaming);
    emit(
      latest.copyWith(
        messages: completedMessages,
        isStreaming: anyStreaming,
        isSending: true,
      ),
    );
  }

  List<String> _splitIntoChunks(String text) {
    final points = text.runes.toList();
    final size = (points.length / 120).ceil().clamp(3, 1000000).toInt();
    return [
      for (var i = 0; i < points.length; i += size)
        String.fromCharCodes(points.skip(i).take(size)),
    ];
  }

  Future<void> retryLastMessage() async {
    if (!_sessionValid ||
        state is! ChatLoaded ||
        (state as ChatLoaded).isBusy) {
      return;
    }
    final id = _currentConversationId;
    final current = state as ChatLoaded;
    if (id == null) {
      await loadChat();
      return;
    }
    ChatSession? session;
    for (final item in current.sessions) {
      if (item.id == id) {
        session = item;
        break;
      }
    }
    if (session == null) {
      await loadChat();
      return;
    }
    await openSession(session);
  }

  void deleteFailedMessage() {
    if (state is! ChatLoaded) return;
    final current = state as ChatLoaded;
    final messages = List<ChatMessage>.from(current.messages);
    if (messages.isNotEmpty && messages.last.hasError) messages.removeLast();
    emit(current.copyWith(messages: messages, clearError: true));
    _lastFailedMessage = null;
  }

  void dismissError() {
    if (state is! ChatLoaded || _needsHistoryRefresh) return;
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
    _appendWaiting = false;
    _needsHistoryRefresh = false;
    _lastFailedMessage = null;
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('Conversation changed');
    }
    _resetTurnState();
  }

  @override
  Future<void> close() {
    _session.userNotifier.removeListener(_onSessionChanged);
    _invalidatePendingRequests();
    _guard = null;
    return super.close();
  }
}
