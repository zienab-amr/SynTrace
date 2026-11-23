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
  forbidden,
  badRequest,
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
        return ChatError(type: type, message: 'Check your internet connection', failedMessageText: failedText);
      case ChatErrorType.server:
        return ChatError(type: type, message: 'AI Service is temporarily unavailable', failedMessageText: failedText);
      case ChatErrorType.timeout:
        return ChatError(type: type, message: 'AI request took too long. Please try again.', failedMessageText: failedText);
      case ChatErrorType.emptyResponse:
        return ChatError(type: type, message: 'AI returned an empty response', failedMessageText: failedText);
      case ChatErrorType.unauthorized:
        return ChatError(type: type, message: 'Session expired. Please log in again.');
      case ChatErrorType.forbidden:
        return ChatError(type: type, message: 'Access denied. You do not have permission.', failedMessageText: failedText);
      case ChatErrorType.badRequest:
        return ChatError(type: type, message: 'Invalid request. Please check your input.', failedMessageText: failedText);
      case ChatErrorType.unknown:
        return ChatError(type: type, message: 'Something went wrong. Please try again.', failedMessageText: failedText);
    }
  }

  bool get canRetry => type != ChatErrorType.unauthorized && type != ChatErrorType.forbidden;

  @override
  List<Object?> get props => [type, message, failedMessageText];
}