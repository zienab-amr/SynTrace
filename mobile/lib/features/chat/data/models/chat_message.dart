import 'package:equatable/equatable.dart';
import 'package:syntrace/features/chat/data/models/jira_card_model.dart';

enum ChatRole { user, ai }

class ProgressStep extends Equatable {
  final String label;
  final bool isDone;

  const ProgressStep({required this.label, this.isDone = false});

  factory ProgressStep.fromJson(Map<String, dynamic> json) {
    return ProgressStep(
      label: json['label'] as String,
      isDone: json['isDone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'isDone': isDone};

  ProgressStep copyWith({bool? isDone}) =>
      ProgressStep(label: label, isDone: isDone ?? this.isDone);

  @override
  List<Object?> get props => [label, isDone];
}

class ChatMessage extends Equatable {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final bool hasError;
  final List<ProgressStep> steps;
  final List<JiraCardModel> jiraCards;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.hasError = false,
    this.steps = const [],
    this.jiraCards = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] == 'user' ? ChatRole.user : ChatRole.ai,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isStreaming: json['isStreaming'] as bool? ?? false,
      hasError: json['hasError'] as bool? ?? false,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => ProgressStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      jiraCards: (json['jiraCards'] as List<dynamic>?)
              ?.map((e) => JiraCardModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isStreaming': isStreaming,
      'hasError': hasError,
      'steps': steps.map((e) => e.toJson()).toList(),
      'jiraCards': jiraCards.map((e) => e.toJson()).toList(),
    };
  }

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    bool? hasError,
    List<ProgressStep>? steps,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      hasError: hasError ?? this.hasError,
      steps: steps ?? this.steps,
      jiraCards: jiraCards,
    );
  }

  @override
  List<Object?> get props =>
      [id, role, content, timestamp, isStreaming, hasError, steps, jiraCards];
}