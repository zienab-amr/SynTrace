import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/features/auth/data/auth_repository.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';
import 'login_state.dart';

/// ═══════════════════════════════════════════════════════════
/// LoginCubit
/// 
/// بيدير حالة شاشة الـ Login
/// ═══════════════════════════════════════════════════════════
class LoginCubit extends Cubit<LoginState> {
  final AuthRepository _repository;

  LoginCubit({AuthRepository? repository})
      : _repository = repository ?? AuthRepository(),
        super(const LoginInitial());

  /// ═══════════════════════════════════════════════════════
  /// Login
  /// ═══════════════════════════════════════════════════════
  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(const LoginLoading());

    // ─── نادي الـ Repository ───
    final result = await _repository.login(
      LoginRequest(email: email, password: password),
    );

    if (result.success && result.data != null) {
      // ─── احفظي الـ Token ───
      await _saveAuthData(result.data!);

      emit(LoginSuccess(result.data!));
    } else {
      emit(LoginError(result.message));
    }
  }

  /// ═══════════════════════════════════════════════════════
  /// Signup
  /// ═══════════════════════════════════════════════════════
  Future<void> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    emit(const LoginLoading());

    final result = await _repository.signup(
      SignupRequest(
        fullName: fullName,
        email: email,
        password: password,
      ),
    );

    if (result.success && result.data != null) {
      await _saveAuthData(result.data!);
      emit(LoginSuccess(result.data!));
    } else {
      emit(LoginError(result.message));
    }
  }

  /// ═══════════════════════════════════════════════════════
  /// Helpers
  /// ═══════════════════════════════════════════════════════
  Future<void> _saveAuthData(AuthResponse response) async {
    // ─── حفظ الـ Token ───
    await SecureStorageService.instance.saveToken(response.token);
    await SecureStorageService.instance.saveRefreshToken(response.refreshToken);
    await SecureStorageService.instance.saveUserId(response.user.id);
    await SecureStorageService.instance.saveUserRole(response.user.role.value);

    if (response.user.tenantId != null) {
      await SecureStorageService.instance.saveTenantId(response.user.tenantId!);
    }

    CurrentUserService.instance.setUser(response.user);
  }

  /// ─── Reset ───
  void reset() {
    emit(const LoginInitial());
  }
}