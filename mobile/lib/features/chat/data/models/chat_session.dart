import 'package:equatable/equatable.dart';

class ChatSession extends Equatable {
  final String id;
  final String title;
  final DateTime lastMessageAt;
  final String? preview;

  const ChatSession({
    required this.id,
    required this.title,
    required this.lastMessageAt,
    this.preview,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id']?.toString() ?? json['conversationId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'New Chat',
      lastMessageAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : (json['lastMessageAt'] != null
                ? DateTime.parse(json['lastMessageAt'].toString())
                : DateTime.now()),
      preview: json['preview']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'preview': preview,
    };
  }

  @override
  List<Object?> get props => [id, title, lastMessageAt, preview];
}
