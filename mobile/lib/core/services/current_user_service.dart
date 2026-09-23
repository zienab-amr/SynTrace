import 'package:flutter/foundation.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';

/// ═══════════════════════════════════════════════════════════
/// Current User Service
/// 
/// بيحتفظ ببيانات المستخدم الحالي في الذاكرة
/// (هيتم تحديثها لما نعمل شاشة Login)
/// ═══════════════════════════════════════════════════════════
class CurrentUserService {
  CurrentUserService._();
  static final CurrentUserService instance = CurrentUserService._();

  // ─── UserNotifier ───
  final ValueNotifier<UserModel?> _userNotifier =
      ValueNotifier<UserModel?>(null);

  ValueNotifier<UserModel?> get userNotifier => _userNotifier;
  UserModel? get user => _userNotifier.value;

  /// ═══════════════════════════════════════════════════════
  /// تعيين المستخدم (بيتنادى بعد Login)
  /// ═══════════════════════════════════════════════════════
  void setUser(UserModel user) {
    _userNotifier.value = user;
  }

  /// ═══════════════════════════════════════════════════════
  /// تحديث جزء من المستخدم
  /// ═══════════════════════════════════════════════════════
  void updateUser(UserModel user) {
    _userNotifier.value = user;
  }

  /// ═══════════════════════════════════════════════════════
  /// مسح المستخدم (بيتنادى بعد Logout)
  /// ═══════════════════════════════════════════════════════
  Future<void> clearUser() async {
    _userNotifier.value = null;
    await SecureStorageService.instance.clearUserData();
  }

  /// ═══════════════════════════════════════════════════════
  /// تحميل من الـ SecureStorage (لما التطبيق يفتح)
  /// ═══════════════════════════════════════════════════════
  Future<void> loadFromStorage() async {
    try {
      final userId = await SecureStorageService.instance.getUserId();
      final userRole = await SecureStorageService.instance.getUserRole();
      final tenantId = await SecureStorageService.instance.getTenantId();

      if (userId != null) {
        // ─── مستخدم مبدئي من التخزين ───
        // (هيتم تحديثه لما نعمل Login API)
        _userNotifier.value = UserModel(
          id: userId,
          name: 'User', // هيتم تحديثه بعد Login
          email: '',
          role: UserRole.fromString(userRole),
          tenantId: tenantId,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load user from storage: $e');
    }
  }
}