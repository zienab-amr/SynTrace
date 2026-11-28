import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:syntrace/core/cache/cache_scope.dart';

class CacheEncryptionService {
  CacheEncryptionService._();

  static final instance = CacheEncryptionService._();

  final AesGcm _algorithm = AesGcm.with256bits();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final Map<String, Future<SecretKey>> _pendingKeys = {};

  String _storageKey(CacheScope scope) {
    final identifier = jsonEncode([scope.tenantId, scope.userId]);

    return 'syntrace_cache_key_v1_${base64UrlEncode(utf8.encode(identifier))}';
  }

  Future<SecretKey> _getKey(
    CacheScope scope, {
    bool createIfMissing = true,
  }) async {
    final storageKey = _storageKey(scope);

    if (!createIfMissing) {
      final stored = await _storage.read(key: storageKey);

      if (stored == null) {
        throw StateError('Cache encryption key missing.');
      }

      return _decodeKey(stored);
    }

    final pending = _pendingKeys.putIfAbsent(
      storageKey,
      () => _loadOrCreateKey(storageKey),
    );

    try {
      return await pending;
    } finally {
      if (identical(_pendingKeys[storageKey], pending)) {
        _pendingKeys.remove(storageKey);
      }
    }
  }

  SecretKey _decodeKey(String stored) {
    final bytes = base64Decode(stored);

    if (bytes.length != 32) {
      throw const FormatException('Invalid cache encryption key.');
    }

    return SecretKey(bytes);
  }

  Future<SecretKey> _loadOrCreateKey(String storageKey) async {
    final stored = await _storage.read(key: storageKey);

    if (stored != null) {
      return _decodeKey(stored);
    }

    final secretKey = await _algorithm.newSecretKey();
    final bytes = await secretKey.extractBytes();

    await _storage.write(key: storageKey, value: base64Encode(bytes));

    return secretKey;
  }

  List<int> _associatedData({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
    required int version,
  }) {
    return utf8.encode(
      jsonEncode([
        scope.tenantId,
        scope.userId,
        resourceType,
        resourceKey,
        version,
      ]),
    );
  }

  Future<String> encrypt({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
    required String plaintext,
    int version = 1,
  }) async {
    final key = await _getKey(scope);

    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      aad: _associatedData(
        scope: scope,
        resourceType: resourceType,
        resourceKey: resourceKey,
        version: version,
      ),
    );

    return base64Encode(box.concatenation());
  }

  Future<String> decrypt({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
    required String encrypted,
    int version = 1,
  }) async {
    final key = await _getKey(scope, createIfMissing: false);

    final box = SecretBox.fromConcatenation(
      base64Decode(encrypted),
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );

    final bytes = await _algorithm.decrypt(
      box,
      secretKey: key,
      aad: _associatedData(
        scope: scope,
        resourceType: resourceType,
        resourceKey: resourceKey,
        version: version,
      ),
    );

    return utf8.decode(bytes);
  }

  Future<void> deleteKey(CacheScope scope) async {
    final storageKey = _storageKey(scope);
    final pending = _pendingKeys[storageKey];

    try {
      if (pending != null) await pending;
    } finally {
      await _storage.delete(key: storageKey);
    }
  }
}
