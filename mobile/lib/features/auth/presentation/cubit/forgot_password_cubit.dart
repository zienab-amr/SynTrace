import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_repository.dart';
import '../../data/models/auth_models.dart';
import '../validators/auth_validators.dart';
import 'forgot_password_state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  final AuthRepository _repository;
  ForgotPasswordCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(const ForgotPasswordState());

  Future<void> sendCode(String email) async {
    if (isClosed || state.busy || state.completed) return;
    email = email.trim();
    if (AuthValidators.email(email) != null) return;
    final previous = state;
    if (previous.email != null && previous.email != email) return;
    if (previous.resendAt?.isAfter(DateTime.now()) ?? false) return;
    emit(
      ForgotPasswordState(
        email: previous.email,
        busy: true,
        resendAt: previous.resendAt,
      ),
    );
    final result = await _repository.sendOtp(
      email,
      purpose: OtpPurpose.passwordReset,
    );
    if (isClosed) return;
    if (result.success && result.data == true) {
      emit(
        ForgotPasswordState(
          email: email,
          resendAt: DateTime.now().add(const Duration(seconds: 60)),
          message: 'If an account exists, a reset code has been requested.',
        ),
      );
    } else {
      emit(
        ForgotPasswordState(
          email: previous.email,
          resendAt: DateTime.now().add(const Duration(seconds: 60)),
          message:
              'Unable to confirm code delivery. Please wait before trying again.',
        ),
      );
    }
  }

  Future<void> reset({
    required String otp,
    required String password,
    required String confirmation,
  }) async {
    final previous = state;
    final email = previous.email;
    if (isClosed || previous.busy || previous.completed || email == null) {
      return;
    }
    if (AuthValidators.otp(otp) != null ||
        AuthValidators.signupPassword(password) != null ||
        password != confirmation) {
      return;
    }
    emit(
      ForgotPasswordState(
        email: email,
        busy: true,
        resendAt: previous.resendAt,
      ),
    );
    final result = await _repository.resetPassword(
      ResetPasswordRequest(
        email: email,
        otp: otp.trim(),
        newPassword: password,
        confirmPassword: confirmation,
      ),
    );
    if (isClosed) return;
    emit(
      ForgotPasswordState(
        email: email,
        resendAt: previous.resendAt,
        completed: result.success && result.data == true,
        message: result.success && result.data == true
            ? 'Password updated. Sign in with your new password.'
            : 'Unable to confirm reset. Check the code and password, or try signing in.',
      ),
    );
  }
}
