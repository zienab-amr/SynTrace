import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/chat/data/models/chat_session.dart';

class ChatLocalStorageService {
  ChatLocalStorageService._();
  static final ChatLocalStorageService instance = ChatLocalStorageService._();

  static const _keySessions = 'cached_chat_sessions';
  
  String _messagesKey(String sessionId) => 'cached_chat_messages_$sessionId';

  Future<void> saveSessions(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_keySessions, jsonEncode(jsonList));
  }

  Future<List<ChatSession>?> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keySessions);
    if (jsonString == null) return null;
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => ChatSession.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveMessages(String sessionId, List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = messages.map((m) => m.toJson()).toList();
    await prefs.setString(_messagesKey(sessionId), jsonEncode(jsonList));
  }

  Future<List<ChatMessage>?> loadMessages(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_messagesKey(sessionId));
    if (jsonString == null) return null;
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }
}