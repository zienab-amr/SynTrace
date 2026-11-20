import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/features/auth/data/auth_repository.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthRepository _repository;

  LoginCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(const LoginInitial());

  Future<void> login({required String email, required String password}) async {
    if (state is LoginLoading) return;
    emit(const LoginLoading());

    final result = await _repository.login(
      LoginRequest(email: email, password: password),
    );

    if (result.success && result.data != null) {
      await _saveTokens(result.data!);

      var user = result.data!.extractUser(fallbackEmail: email);

      if (user != null) {
        await SecureStorageService.instance.saveUserId(user.id);
        await SecureStorageService.instance.saveUserRole(user.role.value);
        if (user.tenantId != null && user.tenantId!.isNotEmpty) {
          await SecureStorageService.instance.saveTenantId(user.tenantId!);
        }

        if (user.id.isNotEmpty) {
          final profileResult = await _repository.getEmployeeProfile(user.id);

          if (profileResult.success && profileResult.data != null) {
            final data = profileResult.data!;

            final firstName = data['firstName']?.toString() ?? '';
            final lastName = data['lastName']?.toString() ?? '';
            final fullName = '$firstName $lastName'.trim();
            final phoneNumber = data['phoneNumber']?.toString();

            String? companyName;
            if (data['companyName'] != null) {
              companyName = data['companyName'].toString();
            } else if (data['company'] is Map &&
                data['company']['companyName'] != null) {
              companyName = data['company']['companyName'].toString();
            }

            user = user.copyWith(
              name: fullName.isNotEmpty ? fullName : user.name,
              phoneNumber: phoneNumber,
              companyName: companyName ?? user.companyName,
            );
          }
        }

        await CurrentUserService.instance.setUser(user);
      }
      emit(LoginSuccess(result.data!));
    } else {
      emit(LoginError(result.message));
    }
  }

  Future<void> _saveTokens(AuthResponse response) async {
    await SecureStorageService.instance.saveToken(response.accessToken);
    await SecureStorageService.instance.saveRefreshToken(response.refreshToken);
  }
}
