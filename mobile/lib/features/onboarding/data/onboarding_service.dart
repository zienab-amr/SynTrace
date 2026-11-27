import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';

import 'onboarding_data.dart';

class OnboardingService {
  OnboardingService._();

  static final OnboardingService instance = OnboardingService._();

  final _storage = const FlutterSecureStorage();

  static const _legacyKey = 'onboarding_data';

  Future<String?> _accountKey() async {
    final storage = SecureStorageService.instance;

    final userId = await storage.getUserId();
    final tenantId = await storage.getTenantId();

    if (userId == null ||
        userId.isEmpty ||
        tenantId == null ||
        tenantId.isEmpty) {
      return null;
    }

    return 'onboarding_data_v2_${tenantId}_$userId';
  }

  Future<void> clearLegacyData() async {
    await _storage.delete(key: _legacyKey);
  }

  Future<void> saveData(OnboardingData data) async {
    await clearLegacyData();

    final key = await _accountKey();

    if (key == null) {
      throw StateError('No authenticated account.');
    }

    final jsonMap = {
      'organizationName': data.organizationName,
      'industry': data.industry,
      'customIndustry': data.customIndustry,
      'teamSize': data.teamSize,
      'userRole': data.userRole,
      'customRole': data.customRole,
      'isDarkMode': data.isDarkMode,
    };

    await _storage.write(key: key, value: jsonEncode(jsonMap));
  }

  Future<OnboardingData?> loadData() async {
    await clearLegacyData();

    final key = await _accountKey();

    if (key == null) return null;

    final jsonString = await _storage.read(key: key);

    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      return OnboardingData(
        organizationName: json['organizationName'] as String? ?? '',
        industry: json['industry'] as String? ?? '',
        customIndustry: json['customIndustry'] as String? ?? '',
        teamSize: json['teamSize'] as String? ?? '',
        userRole: json['userRole'] as String? ?? '',
        customRole: json['customRole'] as String? ?? '',
        isDarkMode: json['isDarkMode'] as bool? ?? true,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clearData() async {
    final key = await _accountKey();

    if (key != null) {
      await _storage.delete(key: key);
    }

    await clearLegacyData();
  }
}
