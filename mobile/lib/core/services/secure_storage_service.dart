import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _keyToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyTenantId = 'tenant_id';
  static const _keyUserId = 'user_id';
  static const _keyUserRole = 'user_role';
  static const _keyUserName = 'user_name';
  static const _keyCompanyName = 'company_name';
  static const _keyAvatarBytes = 'avatar_bytes';
  static const _keyOnboardingCompleted = 'onboarding_completed';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> saveTenantId(String tenantId) async {
    await _storage.write(key: _keyTenantId, value: tenantId);
  }

  Future<String?> getTenantId() async {
    return await _storage.read(key: _keyTenantId);
  }

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

  Future<void> saveUserName(String name) async {
    await _storage.write(key: _keyUserName, value: name);
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: _keyUserName);
  }

  Future<void> saveCompanyName(String name) async {
    await _storage.write(key: _keyCompanyName, value: name);
  }

  Future<String?> getCompanyName() async {
    return await _storage.read(key: _keyCompanyName);
  }

  Future<void> saveAvatarBytes(Uint8List bytes) async {
    final base64String = base64Encode(bytes);
    await _storage.write(key: _keyAvatarBytes, value: base64String);
  }

  Future<Uint8List?> getAvatarBytes() async {
    final base64String = await _storage.read(key: _keyAvatarBytes);
    if (base64String == null || base64String.isEmpty) return null;
    try {
      return base64Decode(base64String);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteAvatarBytes() async {
    await _storage.delete(key: _keyAvatarBytes);
  }

  Future<void> saveOnboardingCompleted(bool value) async {
    await _storage.write(
      key: _keyOnboardingCompleted,
      value: value.toString(),
    );
  }

  Future<bool> isOnboardingCompleted() async {
    final value = await _storage.read(key: _keyOnboardingCompleted);
    return value == 'true';
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<void> clearAuthData() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyOnboardingCompleted);
  }
}