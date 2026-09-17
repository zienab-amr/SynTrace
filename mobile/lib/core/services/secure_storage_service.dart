import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ═══════════════════════════════════════════════════════════
/// Secure Storage Service
/// 
/// الخزنة الآمنة للتطبيق
/// بنخزن فيها: Token, TenantId, API Keys
/// ═══════════════════════════════════════════════════════════
class SecureStorageService {
  // ─── Singleton ───
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  // ─── الخزنة ───
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ═══════════════════════════════════════════════════════
  // Keys
  // ═══════════════════════════════════════════════════════
  static const _keyToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyTenantId = 'tenant_id';
  static const _keyUserId = 'user_id';
  static const _keyUserRole = 'user_role';
  static const _keyApiKey = 'api_key';

  // ═══════════════════════════════════════════════════════
  // 1. Auth Token
  // ═══════════════════════════════════════════════════════
  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
  }

  // ═══════════════════════════════════════════════════════
  // 2. Refresh Token
  // ═══════════════════════════════════════════════════════
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _keyRefreshToken);
  }

  // ═══════════════════════════════════════════════════════
  // 3. Tenant ID (Multi-Tenancy)
  // ═══════════════════════════════════════════════════════
  Future<void> saveTenantId(String tenantId) async {
    await _storage.write(key: _keyTenantId, value: tenantId);
  }

  Future<String?> getTenantId() async {
    return await _storage.read(key: _keyTenantId);
  }

  Future<void> deleteTenantId() async {
    await _storage.delete(key: _keyTenantId);
  }

  // ═══════════════════════════════════════════════════════
  // 4. User Info (Cache)
  // ═══════════════════════════════════════════════════════
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  Future<void> saveUserRole(String role) async {
    await _storage.write(key: _keyUserRole, value: role);
  }

  Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }

  // ═══════════════════════════════════════════════════════
  // 5. API Key (للـ Backend Communication)
  // ═══════════════════════════════════════════════════════
  Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _keyApiKey, value: apiKey);
  }

  Future<String?> getApiKey() async {
    return await _storage.read(key: _keyApiKey);
  }

  // ═══════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════
  
  /// هل المستخدم عامل Login؟
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// امسحي كل حاجة (لما يعمل Logout)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// امسحي كل حاجة ماعدا الـ Tenant ID
  Future<void> clearUserData() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserRole);
  }
}