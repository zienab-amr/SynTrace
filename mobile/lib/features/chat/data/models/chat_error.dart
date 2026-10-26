import 'package:equatable/equatable.dart';

/// ═══════════════════════════════════════════════════════════
/// Chat Error Types
/// ═══════════════════════════════════════════════════════════
enum ChatErrorType
 {
  network,       
  server,        
  timeout,       
  emptyResponse, 
  unauthorized,  
  unknown,      
}

class ChatError extends Equatable {
  final ChatErrorType type;
  final String message;
  final String? failedMessageText; 

  const ChatError({
    required this.type,
    required this.message,
    this.failedMessageText,
  });

  factory ChatError.fromType(ChatErrorType type, {String? failedText}) {
    switch (type) {
      case ChatErrorType.network:
        return ChatError(
          type: type,
          message: 'Check your internet connection',
          failedMessageText: failedText,
        );
      case ChatErrorType.server:
        return ChatError(
          type: type,
          message: 'Server is temporarily unavailable',
          failedMessageText: failedText,
        );
      case ChatErrorType.timeout:
        return ChatError(
          type: type,
          message: 'AI took too long to respond',
          failedMessageText: failedText,
        );
      case ChatErrorType.emptyResponse:
        return ChatError(
          type: type,
          message: 'AI returned an empty response',
          failedMessageText: failedText,
        );
      case ChatErrorType.unauthorized:
        return ChatError(
          type: type,
          message: 'Session expired. Please log in again.',
        );
      case ChatErrorType.unknown:
        return ChatError(
          type: type,
          message: 'Something went wrong. Please try again.',
          failedMessageText: failedText,
        );
    }
  }
  bool get canRetry =>
      type != ChatErrorType.unauthorized;

  String get iconName {
    switch (type) {
      case ChatErrorType.network:
        return 'wifi_off';
      case ChatErrorType.server:
        return 'cloud_off';
      case ChatErrorType.timeout:
        return 'schedule';
      case ChatErrorType.emptyResponse:
        return 'chat_bubble_outline';
      case ChatErrorType.unauthorized:
        return 'lock_outline';
      case ChatErrorType.unknown:
        return 'error_outline';
    }
  }

  @override
  List<Object?> get props => [type, message, failedMessageText];
}