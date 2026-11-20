import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
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
  }) async {
    if (state is SignupLoading) return;
    emit(const SignupLoading());

    final trimmedEmail = email.trim().toLowerCase();
    final trimmedCompany = companyName.trim();
    final trimmedFirstName = firstName.trim();
    final trimmedLastName = lastName.trim();

    final emailExists = await _repository.checkEmailExists(trimmedEmail);
    if (emailExists) {
      emit(EmailAlreadyExists(trimmedEmail));
      return;
    }

    PendingSignupService.instance.save(
      SignupRequest(
        companyName: trimmedCompany,
        firstName: trimmedFirstName,
        lastName: trimmedLastName,
        email: trimmedEmail,
        password: password,
      ),
    );

    final otpResult = await _repository.sendOtp(trimmedEmail);
    if (otpResult.success) {
      emit(OtpSent(trimmedEmail));
    } else {
      PendingSignupService.instance.clear();
      emit(SignupError(otpResult.message));
    }
  }

  Future<void> verifyOtp({required String email, required String otp}) async {
    if (state is SignupLoading) return;
    emit(const SignupLoading());

    final trimmedEmail = email.trim().toLowerCase();
    final trimmedOtp = otp.trim();

    final verifyResult = await _repository.verifyOtp(
      email: trimmedEmail,
      otp: trimmedOtp,
    );
    if (!verifyResult.success || verifyResult.data != true) {
      emit(SignupError(verifyResult.message));
      return;
    }

    emit(const OtpVerified());

    final pending = PendingSignupService.instance.pendingRequest;
    if (pending == null) {
      emit(const SignupError('Signup data lost. Please try again.'));
      return;
    }

    final registerResult = await _repository.signup(pending);
    if (!registerResult.success || registerResult.data == null) {
      emit(SignupError(registerResult.message));
      return;
    }

    final loginResult = await _repository.login(
      LoginRequest(email: pending.email, password: pending.password),
    );

    if (loginResult.success && loginResult.data != null) {
      await _saveTokens(loginResult.data!);

      final fullName = '${pending.firstName} ${pending.lastName}'.trim();

      final user = loginResult.data!.extractUser(
        fallbackEmail: pending.email,
        fallbackName: fullName,
        fallbackCompanyName: pending.companyName,
      );

      if (user != null) {
        await SecureStorageService.instance.saveUserId(user.id);
        await SecureStorageService.instance.saveUserRole(user.role.value);
        if (user.tenantId != null && user.tenantId!.isNotEmpty) {
          await SecureStorageService.instance.saveTenantId(user.tenantId!);
        }

        await CurrentUserService.instance.setUser(user);
      }

      PendingSignupService.instance.clear();
      emit(SignupSuccess(registerResult.data!));
    } else {
      emit(SignupError(loginResult.message));
    }
  }

  Future<void> _saveTokens(AuthResponse response) async {
    await SecureStorageService.instance.saveToken(response.accessToken);
    await SecureStorageService.instance.saveRefreshToken(response.refreshToken);
  }

  void reset() {
    PendingSignupService.instance.clear();
    emit(const SignupInitial());
  }
}
