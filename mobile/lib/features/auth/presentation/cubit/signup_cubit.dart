import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/features/auth/data/auth_repository.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';
import 'package:syntrace/features/auth/data/pending_signup_service.dart';
import 'signup_state.dart';

class SignupCubit extends Cubit<SignupState> {
  final AuthRepository _repository;

  SignupCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(const SignupInitial());

  Future<void> sendOtp({
    required String companyName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    if (state is SignupLoading) return;
    emit(const SignupLoading());

    final trimmedEmail = email.trim().toLowerCase();
    final trimmedCompany = companyName.trim();
    final trimmedFirstName = firstName.trim();
    final trimmedLastName = lastName.trim();

    PendingSignupService.instance.save(
      SignupRequest(
        companyName: trimmedCompany,
        firstName: trimmedFirstName,
        lastName: trimmedLastName,
        email: trimmedEmail,
        phoneNumber: phoneNumber == null || phoneNumber.trim().isEmpty
            ? null
            : phoneNumber.trim(),
        password: password,
      ),
    );

    final otpResult = await _repository.sendOtp(trimmedEmail);
    if (isClosed) return;
    if (otpResult.success) {
      PendingSignupService.instance.markSent();
      emit(OtpSent(trimmedEmail));
    } else {
      PendingSignupService.instance.clear();
      emit(SignupError(otpResult.message));
    }
  }

  Future<void> resendOtp(String email) async {
    if (isClosed || state is SignupLoading) return;
    final service = PendingSignupService.instance;
    final pending = service.pendingRequest;
    if (pending == null || pending.email != email.trim().toLowerCase()) {
      emit(const SignupError('Signup data lost. Please start again.'));
      return;
    }
    if (service.resendAt?.isAfter(DateTime.now()) ?? false) return;
    emit(const SignupLoading());
    final result = await _repository.sendOtp(pending.email);
    if (!identical(service.pendingRequest, pending)) return;
    if (result.success) {
      service.markSent();
      if (!isClosed) emit(OtpSent(pending.email));
    } else {
      if (result.statusCode == 429) {
        service.resendAt = DateTime.now().add(const Duration(seconds: 60));
      }
      if (!isClosed) {
        emit(
          SignupError(
            result.statusCode == 429
                ? 'Too many requests. Please wait before requesting another code.'
                : result.message,
          ),
        );
      }
    }
  }

  Future<void> verifyOtp({required String email, required String otp}) async {
    if (state is SignupLoading) return;
    emit(const SignupLoading());

    final trimmedEmail = email.trim().toLowerCase();
    final trimmedOtp = otp.trim();

    final pending = PendingSignupService.instance.pendingRequest;
    if (pending == null || pending.email != trimmedEmail) {
      emit(const SignupError('Signup data lost. Please start again.'));
      return;
    }
    final expiresAt = PendingSignupService.instance.expiresAt;
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      emit(const SignupError('Code expired. Request a new code.'));
      return;
    }
    final verifyResult = await _repository.verifyOtp(
      email: trimmedEmail,
      otp: trimmedOtp,
    );
    if (isClosed) return;
    if (!identical(PendingSignupService.instance.pendingRequest, pending))
      return;
    final token = verifyResult.data?.verificationToken;
    if (!verifyResult.success ||
        verifyResult.data?.verified != true ||
        token == null ||
        token.isEmpty) {
      emit(SignupError(verifyResult.message));
      return;
    }
    final registerResult = await _repository.signup(
      pending.withVerificationToken(token),
    );
    if (isClosed) return;
    if (!registerResult.success || registerResult.data == null) {
      emit(
        SignupError(
          '${registerResult.message} Request a new code before trying again. If your account was created, sign in instead.',
        ),
      );
      return;
    }

    PendingSignupService.instance.clear();
    if (!isClosed) {
      emit(SignupSuccess(registerResult.data!));
    }
  }

  void reset() {
    PendingSignupService.instance.clear();
    emit(const SignupInitial());
  }
}
