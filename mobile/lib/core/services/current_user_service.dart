import 'package:flutter/foundation.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';

class CurrentUserService {
  CurrentUserService._();
  static final CurrentUserService instance = CurrentUserService._();

  final ValueNotifier<UserModel?> _userNotifier =
      ValueNotifier<UserModel?>(null);

  ValueNotifier<UserModel?> get userNotifier => _userNotifier;
  UserModel? get user => _userNotifier.value;

  void setUser(UserModel user) {
    _userNotifier.value = user;
  }

  void updateUser(UserModel user) {
    _userNotifier.value = user;
  }

  Future<void> clearUser() async {
    _userNotifier.value = null;
    await SecureStorageService.instance.clearAuthData();
  }

  Future<void> loadFromStorage() async {
    try {
      final userId = await SecureStorageService.instance.getUserId();
      final userRole = await SecureStorageService.instance.getUserRole();
      final tenantId = await SecureStorageService.instance.getTenantId();
      final userName = await SecureStorageService.instance.getUserName();
      final companyName =
          await SecureStorageService.instance.getCompanyName();

      if (userId != null) {
        _userNotifier.value = UserModel(
          id: userId,
          name: userName ?? 'User',
          email: '',
          role: UserRole.fromString(userRole),
          tenantId: tenantId,
          companyName: companyName,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load user from storage: $e');
    }
  }
}