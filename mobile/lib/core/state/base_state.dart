import 'package:equatable/equatable.dart';

/// ═══════════════════════════════════════════════════════════
/// Base State
/// 
/// الـ Parent لكل الـ States في التطبيق
/// ═══════════════════════════════════════════════════════════
abstract class BaseState extends Equatable {
  const BaseState();

  @override
  List<Object?> get props => [];
}

/// ═══════════════════════════════════════════════════════════
/// Initial State
/// ═══════════════════════════════════════════════════════════
class InitialState extends BaseState {
  const InitialState();
}

/// ═══════════════════════════════════════════════════════════
/// Loading State
/// ═══════════════════════════════════════════════════════════
class LoadingState extends BaseState {
  const LoadingState();
}

/// ═══════════════════════════════════════════════════════════
/// Error State
/// ═══════════════════════════════════════════════════════════
class ErrorState extends BaseState {
  final String message;
  final int? statusCode;

  const ErrorState({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

/// ═══════════════════════════════════════════════════════════
/// Success State (Base)
/// 
/// ═══════════════════════════════════════════════════════════
class SuccessState<T> extends BaseState {
  final T data;

  const SuccessState({required this.data});

  @override
  List<Object?> get props => [data];
}