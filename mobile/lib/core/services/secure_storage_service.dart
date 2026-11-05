import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyTenantId = 'tenant_id';
  static const _keyUserId = 'user_id';
  static const _keyUserRole = 'user_role';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyCompanyName = 'company_name';
  static const _keyOnboardingCompleted = 'onboarding_completed_global';

  Future<void> saveToken(String token) async =>
      await _storage.write(key: _keyToken, value: token);
  Future<String?> getToken() async => await _storage.read(key: _keyToken);
  Future<void> deleteToken() async => await _storage.delete(key: _keyToken);

  Future<void> saveRefreshToken(String token) async =>
      await _storage.write(key: _keyRefreshToken, value: token);
  Future<String?> getRefreshToken() async =>
      await _storage.read(key: _keyRefreshToken);
  Future<void> deleteRefreshToken() async =>
      await _storage.delete(key: _keyRefreshToken);

  Future<void> saveTenantId(String tenantId) async =>
      await _storage.write(key: _keyTenantId, value: tenantId);
  Future<String?> getTenantId() async => await _storage.read(key: _keyTenantId);
  Future<void> deleteTenantId() async =>
      await _storage.delete(key: _keyTenantId);

  Future<void> saveUserId(String userId) async =>
      await _storage.write(key: _keyUserId, value: userId);
  Future<String?> getUserId() async => await _storage.read(key: _keyUserId);

  Future<void> saveUserRole(String role) async =>
      await _storage.write(key: _keyUserRole, value: role);
  Future<String?> getUserRole() async => await _storage.read(key: _keyUserRole);

  Future<void> saveUserName(String name) async =>
      await _storage.write(key: _keyUserName, value: name);
  Future<String?> getUserName() async => await _storage.read(key: _keyUserName);

  Future<void> saveUserEmail(String email) async =>
      await _storage.write(key: _keyUserEmail, value: email);
  Future<String?> getUserEmail() async =>
      await _storage.read(key: _keyUserEmail);

  Future<void> saveCompanyName(String name) async =>
      await _storage.write(key: _keyCompanyName, value: name);
  Future<String?> getCompanyName() async =>
      await _storage.read(key: _keyCompanyName);

  Future<void> saveOnboardingCompleted(bool value) async => await _storage
      .write(key: _keyOnboardingCompleted, value: value.toString());

  Future<bool?> getOnboardingCompleted() async {
    final value = await _storage.read(key: _keyOnboardingCompleted);
    if (value == null) return null;
    return value == 'true';
  }

  Future<bool> isOnboardingCompleted() async {
    final value = await getOnboardingCompleted();
    return value ?? false;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() async => await _storage.deleteAll();

  Future<void> clearUserData() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserRole);
    await _storage.delete(key: _keyUserName);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyCompanyName);
  }

  Future<void> clearAuthData() async {
    await clearUserData();
  }
}
