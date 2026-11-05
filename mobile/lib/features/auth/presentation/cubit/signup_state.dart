import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';

abstract class SignupState extends BaseState {
  const SignupState();
}

class SignupInitial extends SignupState {
  const SignupInitial();
}

class SignupLoading extends SignupState {
  const SignupLoading();
}

class OtpSent extends SignupState {
  final String email;
  const OtpSent(this.email);

  @override
  List<Object?> get props => [email];
}

class OtpVerified extends SignupState {
  const OtpVerified();
}

class SignupSuccess extends SignupState {
  final RegisterResponse registerResponse;
  const SignupSuccess(this.registerResponse);

  @override
  List<Object?> get props => [registerResponse];
}

class SignupError extends SignupState {
  final String message;
  const SignupError(this.message);

  @override
  List<Object?> get props => [message];
}

class EmailAlreadyExists extends SignupState {
  final String email;
  const EmailAlreadyExists(this.email);

  @override
  List<Object?> get props => [email];
}
