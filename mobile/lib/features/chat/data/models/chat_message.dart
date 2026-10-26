import 'package:equatable/equatable.dart';
import 'package:syntrace/features/chat/data/models/jira_card_model.dart';

enum ChatRole { user, ai }

/// ═══════════════════════════════════════════════════════════
/// Progress Step
/// ═══════════════════════════════════════════════════════════
class ProgressStep extends Equatable {
  final String label;
  final bool isDone;

  const ProgressStep({required this.label, this.isDone = false});

  ProgressStep copyWith({bool? isDone}) =>
      ProgressStep(label: label, isDone: isDone ?? this.isDone);

  @override
  List<Object?> get props => [label, isDone];
}

/// ═══════════════════════════════════════════════════════════
/// Chat Message
/// ═══════════════════════════════════════════════════════════
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
    );
  }

  @override
  List<Object?> get props =>
      [id, role, content, timestamp, isStreaming, hasError, steps];
}