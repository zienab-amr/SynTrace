import 'package:dio/dio.dart';
import 'package:syntrace/core/models/user_profile_model.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/services/current_user_service.dart';

class SettingsRepository
{
  // ═══════════════════════════════════════════════════════
  // Get Profile
  // ═══════════════════════════════════════════════════════
  Future<UserProfileModel?> getProfile() async {
  final user = CurrentUserService.instance.user;
  if (user != null) {
    return UserProfileModel.fromUser(user);
  }
  return null;
}

  // ═══════════════════════════════════════════════════════
  // Update Profile
  // ═══════════════════════════════════════════════════════
  Future<bool> updateProfile(UserProfileModel profile) async {
    try {
      final response = await ApiClient.instance.put(
        ApiEndpoints.me,
        data: {
          'request': {
            'fullName': profile.fullName,
            'email': profile.email,
          },
        },
      );

      return response.statusCode == 200;
    } on DioException {
      return false;
    }
  }
}