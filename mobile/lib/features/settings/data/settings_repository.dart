import 'package:syntrace/core/models/user_profile_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/self_profile_service.dart';

class SettingsRepository {
  final _service = SelfProfileService();

  Future<UserProfileModel?> getProfile() async {
    final user = CurrentUserService.instance.user;
    return user == null ? null : UserProfileModel.fromUser(user);
  }

  Future<bool> updateProfile(UserProfileModel profile) async {
    final user = CurrentUserService.instance.user;
    if (user == null ||
        user.id != profile.id ||
        user.tenantId != profile.organizationId ||
        user.email != profile.email) {
      return false;
    }
    final name = profile.fullName.trim();
    final index = name.indexOf(' ');
    if (index < 1) return false;
    try {
      await _service.update(
        firstName: name.substring(0, index),
        lastName: name.substring(index + 1),
        phoneNumber: profile.phoneNumber ?? '',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
