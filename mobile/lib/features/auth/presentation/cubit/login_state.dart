import 'package:equatable/equatable.dart';
import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';

/// ═══════════════════════════════════════════════════════════
/// Login State
/// ═══════════════════════════════════════════════════════════
abstract class LoginState extends BaseState {
  const LoginState();
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginSuccess extends LoginState {
  final AuthResponse authResponse;

  const LoginSuccess(this.authResponse);

  @override
  List<Object?> get props => [authResponse];
}

class LoginError extends LoginState {
  final String message;

  const LoginError(this.message);

  @override
  List<Object?> get props => [message];
}