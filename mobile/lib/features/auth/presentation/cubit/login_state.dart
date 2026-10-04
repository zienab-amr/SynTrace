import 'package:equatable/equatable.dart';
import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';

abstract class LoginState extends BaseState {
  const LoginState();
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class OtpSent extends LoginState {
  final String email;
  const OtpSent(this.email);

  @override
  List<Object?> get props => [email];
}

class OtpVerified extends LoginState {
  const OtpVerified();
}

class LoginSuccess extends LoginState {
  final AuthResponse authResponse;
  const LoginSuccess(this.authResponse);

  @override
  List<Object?> get props => [authResponse];
}

class RegisterSuccess extends LoginState {
  final RegisterResponse registerResponse;
  const RegisterSuccess(this.registerResponse);

  @override
  List<Object?> get props => [registerResponse];
}

class LoginError extends LoginState {
  final String message;
  const LoginError(this.message);

  @override
  List<Object?> get props => [message];
}