import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/features/auth/data/auth_repository.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';
import 'package:syntrace/features/auth/data/pending_signup_service.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthRepository _repository;

  LoginCubit({AuthRepository? repository})
      : _repository = repository ?? AuthRepository(),
        super(const LoginInitial());

  // ═══════════════════════════════════════════════════════
  // 1. Send OTP
  // ═══════════════════════════════════════════════════════
  Future<void> sendOtp({
    required String companyName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    emit(const LoginLoading());

    PendingSignupService.instance.save(
      SignupRequest(
        companyName: companyName,
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      ),
    );

    final result = await _repository.sendOtp(email);

    if (result.success) {
      emit(OtpSent(email));
    } else {
      PendingSignupService.instance.clear();
      emit(LoginError(result.message));
    }
  }

  // ═══════════════════════════════════════════════════════
  // 2. Verify OTP + Register + Auto-Login
  // ═══════════════════════════════════════════════════════
  Future<void> verifyOtp({
    required String email,
    required String otp,
  }) async {
    emit(const LoginLoading());

    // ─── 1. Verify OTP ───
    final verifyResult = await _repository.verifyOtp(
      email: email,
      otp: otp,
    );

    if (!verifyResult.success || verifyResult.data != true) {
      emit(LoginError(verifyResult.message));
      return;
    }

    emit(const OtpVerified());

    // ─── 2. اقرأي بيانات الـ Signup ───
    final pending = PendingSignupService.instance.pendingRequest;

    if (pending == null) {
      emit(const LoginError('Signup data lost. Please try again.'));
      return;
    }

    // ─── 3. Register ───
    final registerResult = await _repository.signup(pending);

    if (!registerResult.success || registerResult.data == null) {
      emit(LoginError(registerResult.message));
      return;
    }

    PendingSignupService.instance.clear();

    // ─── 4. Auto-Login عشان نجيب الـ Token + User ───
    final loginResult = await _repository.login(
      LoginRequest(
        email: pending.email,
        password: pending.password,
      ),
    );

    if (loginResult.success && loginResult.data != null) {
      await _saveTokens(loginResult.data!);

      final user = loginResult.data!.extractUser();
      if (user != null) {
        CurrentUserService.instance.setUser(user);
      }
    }

    emit(RegisterSuccess(registerResult.data!));
  }

  // ═══════════════════════════════════════════════════════
  // 3. Login
  // ═══════════════════════════════════════════════════════
  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(const LoginLoading());

    final result = await _repository.login(
      LoginRequest(email: email, password: password),
    );

    if (result.success && result.data != null) {
      await _saveTokens(result.data!);

      final user = result.data!.extractUser();
      if (user != null) {
        CurrentUserService.instance.setUser(user);
      }

      emit(LoginSuccess(result.data!));
    } else {
      emit(LoginError(result.message));
    }
  }

  // ═══════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════
  Future<void> _saveTokens(AuthResponse response) async {
    await SecureStorageService.instance.saveToken(response.accessToken);
    await SecureStorageService.instance.saveRefreshToken(response.refreshToken);
  }

  void reset() {
    PendingSignupService.instance.clear();
    emit(const LoginInitial());
  }
}