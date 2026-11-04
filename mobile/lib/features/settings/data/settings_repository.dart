import 'package:dio/dio.dart';
import 'package:syntrace/core/models/user_profile_model.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/services/current_user_service.dart';

class SettingsRepository {
  Future<UserProfileModel?> getProfile() async {
    final user = CurrentUserService.instance.user;
    if (user != null) {
      return UserProfileModel.fromUser(user);
    }
    return null;
  }

  Future<bool> updateProfile(UserProfileModel profile) async {
    try {
      final trimmed = profile.fullName.trim();
      final spaceIndex = trimmed.indexOf(' ');
      final firstName = spaceIndex == -1
          ? trimmed
          : trimmed.substring(0, spaceIndex).trim();
      final lastName = spaceIndex == -1
          ? ''
          : trimmed.substring(spaceIndex + 1).trim();

      final response = await ApiClient.instance.put(
        ApiEndpoints.updateEmployee,
        data: {
          'employeeId': profile.id,
          'firstName': firstName,
          'lastName': lastName,
          'email': profile.email,
          'phoneNumber': '',
        },
      );

      final status = response.statusCode ?? 0;
      return status == 200 || status == 204;
    } on DioException {
      return false;
    }
  }
}
