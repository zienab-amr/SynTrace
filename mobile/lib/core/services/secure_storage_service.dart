import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyTokenPair = 'auth_token_pair_v1';
  static const _keyToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyTenantId = 'tenant_id';
  static const _keyUserId = 'user_id';
  static const _keyRoleNames = 'user_role_names';
  static const _keyUserRole = 'user_role';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyCompanyName = 'company_name';
  static const _keyPhoneNumber = 'user_phone_number';
  static const _keyAvatarUrl = 'user_avatar_url';

  Future<Map<String, dynamic>?> _readPair() async {
    final raw = await _storage.read(key: _keyTokenPair);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<bool> hasPendingRotation() async =>
      await _storage.read(key: 'auth_rotation_pending') != null;

  Future<void> markRotationPending() =>
      _storage.write(key: 'auth_rotation_pending', value: 'true');

  Future<void> clearRotationPending() =>
      _storage.delete(key: 'auth_rotation_pending');

  Future<void> saveTokenPair(
    String accessToken,
    String refreshToken, {
    DateTime? verifiedAt,
    DateTime? refreshExpiresAt,
  }) async {
    if (accessToken.trim().isEmpty || refreshToken.trim().isEmpty) {
      throw const FormatException('Invalid token pair');
    }
    await _storage.write(
      key: _keyTokenPair,
      value: jsonEncode({
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'verifiedAt': verifiedAt?.toUtc().toIso8601String(),
        'refreshExpiresAt': refreshExpiresAt?.toUtc().toIso8601String(),
      }),
    );
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  Future<DateTime?> offlineDeadline() async {
    final pair = await _readPair();
    final verified = DateTime.tryParse(pair?['verifiedAt'] as String? ?? '');
    final expiry = DateTime.tryParse(
      pair?['refreshExpiresAt'] as String? ?? '',
    );
    if (verified == null ||
        expiry == null ||
        verified.isAfter(DateTime.now().toUtc())) {
      return null;
    }
    final grace = verified.add(const Duration(hours: 24));
    return expiry.isBefore(grace) ? expiry : grace;
  }

  // Legacy methods remain for compatibility with existing callers.
  Future<void> saveToken(String token) async {
    final pair = await _readPair();
    if (pair != null) {
      await saveTokenPair(
        token,
        pair['refreshToken'] as String,
        verifiedAt: DateTime.tryParse(pair['verifiedAt'] as String? ?? ''),
        refreshExpiresAt: DateTime.tryParse(
          pair['refreshExpiresAt'] as String? ?? '',
        ),
      );
    } else {
      await _storage.write(key: _keyToken, value: token);
    }
  }

  Future<String?> getToken() async {
    final pair = await _readPair();
    return pair != null
        ? pair['accessToken'] as String?
        : await _storage.read(key: _keyToken);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyTokenPair);
  }

  Future<void> saveRefreshToken(String token) async {
    final access = await getToken();
    if (access == null) throw StateError('Missing access token');
    final pair = await _readPair();
    await saveTokenPair(
      access,
      token,
      verifiedAt: DateTime.tryParse(pair?['verifiedAt'] as String? ?? ''),
      refreshExpiresAt: DateTime.tryParse(
        pair?['refreshExpiresAt'] as String? ?? '',
      ),
    );
  }

  Future<String?> getRefreshToken() async {
    final pair = await _readPair();
    return pair != null
        ? pair['refreshToken'] as String?
        : await _storage.read(key: _keyRefreshToken);
  }

  Future<void> deleteRefreshToken() => deleteToken();

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

  Future<void> saveRoleNames(List<String> names) =>
      _storage.write(key: _keyRoleNames, value: jsonEncode(names));

  Future<List<String>> getRoleNames() async {
    final raw = await _storage.read(key: _keyRoleNames);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.any((v) => v is! String)) {
      throw const FormatException('Invalid stored roles');
    }
    return List.unmodifiable(decoded.cast<String>());
  }

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
  Future<void> savePhoneNumber(String? value) async {
    await _storage.write(key: _keyPhoneNumber, value: value);
  }

  Future<String?> getPhoneNumber() async {
    return _storage.read(key: _keyPhoneNumber);
  }

  Future<void> saveAvatarUrl(String? value) async {
    await _storage.write(key: _keyAvatarUrl, value: value);
  }

  Future<String?> getAvatarUrl() async {
    return _storage.read(key: _keyAvatarUrl);
  }

  Future<void> deleteCompanyName() async {
    await _storage.delete(key: _keyCompanyName);
  }

  Future<String?> _onboardingKey() async {
    final userId = await getUserId();
    final tenantId = await getTenantId();

    if (userId == null ||
        userId.isEmpty ||
        tenantId == null ||
        tenantId.isEmpty) {
      return null;
    }

    return 'onboarding_completed_v2_${tenantId}_$userId';
  }

  Future<void> saveOnboardingCompleted(bool value) async {
    final key = await _onboardingKey();

    if (key == null) {
      throw StateError('No authenticated account.');
    }

    await _storage.write(key: key, value: value.toString());
  }

  Future<bool?> getOnboardingCompleted() async {
    final key = await _onboardingKey();

    if (key == null) return null;

    final value = await _storage.read(key: key);

    if (value == null) return null;

    return value == 'true';
  }

  Future<bool> isOnboardingCompleted() async {
    return await getOnboardingCompleted() ?? false;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() async => await _storage.deleteAll();

  Future<void> clearUserData() async {
    await deleteToken();
    await clearRotationPending();
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserRole);
    await _storage.delete(key: _keyRoleNames);
    await _storage.delete(key: _keyUserName);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyCompanyName);
    await _storage.delete(key: _keyTenantId);
    await _storage.delete(key: _keyPhoneNumber);
    await _storage.delete(key: _keyAvatarUrl);
  }

  Future<void> clearAuthData() async {
    await clearUserData();
  }
}
