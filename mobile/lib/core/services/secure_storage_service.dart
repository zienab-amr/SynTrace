import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _keyUserEmail = 'user_email'; 
  static const _keyCompanyName = 'company_name';
  static const _keyAvatarBytes = 'avatar_bytes';
  static const _keyOnboardingCompleted = 'onboarding_completed';

  Future<void> _save(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _storage.read(key: key);
    }
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  Future<void> saveToken(String token) async => await _save(_keyToken, token);
  Future<String?> getToken() async => await _read(_keyToken);

  Future<void> saveRefreshToken(String token) async => await _save(_keyRefreshToken, token);
  Future<String?> getRefreshToken() async => await _read(_keyRefreshToken);

  Future<void> saveTenantId(String tenantId) async => await _save(_keyTenantId, tenantId);
  Future<String?> getTenantId() async => await _read(_keyTenantId);

  Future<void> saveUserId(String userId) async => await _save(_keyUserId, userId);
  Future<String?> getUserId() async => await _read(_keyUserId);

  Future<void> saveUserRole(String role) async => await _save(_keyUserRole, role);
  Future<String?> getUserRole() async => await _read(_keyUserRole);

  Future<void> saveUserName(String name) async => await _save(_keyUserName, name);
  Future<String?> getUserName() async => await _read(_keyUserName);

  Future<void> saveUserEmail(String email) async => await _save(_keyUserEmail, email);
  Future<String?> getUserEmail() async => await _read(_keyUserEmail);

  Future<void> saveCompanyName(String name) async => await _save(_keyCompanyName, name);
  Future<String?> getCompanyName() async => await _read(_keyCompanyName);

  Future<void> saveAvatarBytes(Uint8List bytes) async {
    final base64String = base64Encode(bytes);
    await _save(_keyAvatarBytes, base64String);
  }

  Future<Uint8List?> getAvatarBytes() async {
    final base64String = await _read(_keyAvatarBytes);
    if (base64String == null || base64String.isEmpty) return null;
    try {
      return base64Decode(base64String);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteAvatarBytes() async => await _delete(_keyAvatarBytes);

  Future<void> saveOnboardingCompleted(bool value) async => await _save(_keyOnboardingCompleted, value.toString());

  Future<bool> isOnboardingCompleted() async {
    final value = await _read(_keyOnboardingCompleted);
    return value == 'true';
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } else {
      await _storage.deleteAll();
    }
  }

 Future<void> clearAuthData() async {
    await _delete(_keyToken);
    await _delete(_keyRefreshToken);
    await _delete(_keyOnboardingCompleted);
    await _delete(_keyUserId);
    await _delete(_keyTenantId);
    await _delete(_keyUserRole);
    await _delete(_keyUserEmail);
  }
}