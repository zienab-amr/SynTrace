import 'package:flutter/foundation.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';

class CurrentUserService {
  CurrentUserService._();
  static final CurrentUserService instance = CurrentUserService._();

  final ValueNotifier<UserModel?> _userNotifier = ValueNotifier<UserModel?>(null);

  ValueNotifier<UserModel?> get userNotifier => _userNotifier;
  UserModel? get user => _userNotifier.value;

  Future<void> setUser(UserModel user) async {
    _userNotifier.value = user;
    
    final s = SecureStorageService.instance;
    await s.saveUserId(user.id);
    await s.saveUserName(user.name);
    await s.saveUserEmail(user.email);
    await s.saveUserRole(user.role.name); 
    if (user.tenantId != null) await s.saveTenantId(user.tenantId!);
    if (user.companyName != null) await s.saveCompanyName(user.companyName!);
  }

  Future<void> updateUser(UserModel user) async {
    _userNotifier.value = user;
    await setUser(user); 
  }

  Future<void> clearUser() async {
    _userNotifier.value = null;
    await SecureStorageService.instance.clearAuthData();
  }

  Future<void> loadFromStorage() async {
    try {
      final s = SecureStorageService.instance;

      final token = await s.getToken();
      if (token == null || token.isEmpty) return;

      final userId = await s.getUserId();
      if (userId == null || userId.isEmpty) return;

      final userRole = await s.getUserRole();
      final tenantId = await s.getTenantId();
      final userName = await s.getUserName();
      final email = await s.getUserEmail();
      final companyName = await s.getCompanyName();

      _userNotifier.value = UserModel(
        id: userId,
        name: userName ?? 'User',
        email: email ?? '',
        role: UserRole.fromString(userRole),
        tenantId: tenantId,
        companyName: companyName,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to load user from storage: $e');
    }
  }
}