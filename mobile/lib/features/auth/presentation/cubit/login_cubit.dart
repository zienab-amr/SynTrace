import 'package:syntrace/core/cache/cache_session.dart';
import 'package:syntrace/core/services/self_profile_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/services/current_user_service.dart';
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

    final generation = CacheSession.instance.generation;
    emit(const LoginLoading());

    try {
      final normalizedEmail = email.trim().toLowerCase();

      final result = await _repository.login(
        LoginRequest(email: normalizedEmail, password: password),
      );

      if (isClosed) return;

      if (!result.success || result.data == null) {
        emit(LoginError(result.message));
        return;
      }

      final response = result.data!;

      final user = response.extractUser(fallbackEmail: normalizedEmail);

      if (user == null ||
          user.id.isEmpty ||
          user.tenantId == null ||
          user.tenantId!.isEmpty ||
          response.accessToken.isEmpty ||
          response.refreshToken.isEmpty) {
        emit(
          const LoginError(
            'Unable to initialize your account. Please try again.',
          ),
        );
        return;
      }

      await CurrentUserService.instance.establishSession(
        user,
        response,
        expectedGeneration: generation,
      );
      final activeGeneration = CacheSession.instance.generation;

      try {
        await SelfProfileService().refresh();
      } catch (_) {
        // A temporary profile failure must not prevent successful sign-in.
        // Settings will retry and will not invent missing profile data.
      }
      if (isClosed ||
          CacheSession.instance.generation != activeGeneration ||
          CurrentUserService.instance.user == null) {
        return;
      }

      emit(LoginSuccess(response));
    } catch (_) {
      if (isClosed) return;

      emit(const LoginError('Unable to sign in. Please try again.'));
    }
  }
}
