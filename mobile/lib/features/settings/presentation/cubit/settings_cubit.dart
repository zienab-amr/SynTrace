import 'package:dio/dio.dart';
import 'package:syntrace/core/cache/cache_session.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/models/user_profile_model.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsInitial());

  Future<void> loadProfile() async {
    if (isClosed) return;
    final user = CurrentUserService.instance.user;
    if (user == null) {
      emit(const SettingsError('Profile unavailable.'));
      return;
    }
    emit(SettingsLoaded(profile: UserProfileModel.fromUser(user)));
  }

  Future<void> logout() async {
    final current = CurrentUserService.instance;
    final generation = CacheSession.instance.generation;
    final storage = SecureStorageService.instance;
    // Invalidate immediately, before any network call.
    final tokenFuture = storage.getRefreshToken();
    final accessFuture = storage.getToken();
    final clearing = current.clearUser(expectedGeneration: generation);
    try {
      await clearing;
      if (!isClosed) emit(const SettingsLoggedOut());
      final refresh = await tokenFuture;
      final access = await accessFuture;
      if (refresh == null || refresh.isEmpty) return;
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          followRedirects: false,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          headers: {
            'ngrok-skip-browser-warning': 'true',
            if (access != null) 'Authorization': 'Bearer $access',
          },
        ),
      );
      try {
        await dio.post(ApiEndpoints.logout, data: {'refreshToken': refresh});
      } finally {
        dio.close();
      }
    } catch (_) {
      if (!isClosed && current.user == null) emit(const SettingsLoggedOut());
    }
  }
}
