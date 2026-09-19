import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:syntrace/features/onboarding/data/onboarding_data.dart';

/// ═══════════════════════════════════════════════════════════
/// OnboardingService
/// 
/// ═══════════════════════════════════════════════════════════
class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  static const _key = 'onboarding_data';
  final _storage = const FlutterSecureStorage();

  // ─── In-Memory Cache ───
  OnboardingData? _cached;

  Future<OnboardingData?> getData() async {
    if (_cached != null) return _cached;

    try {
      final jsonStr = await _storage.read(key: _key);
      if (jsonStr == null) return null;

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      _cached = _fromJson(json);
      return _cached;
    } catch (e) {
      debugPrint('⚠️ Failed to read onboarding data: $e');
      return null;
    }
  }

  Future<void> saveData(OnboardingData data) async {
    try {
      _cached = data;
      final jsonStr = jsonEncode(_toJson(data));
      await _storage.write(key: _key, value: jsonStr);
      debugPrint('✅ Onboarding data saved');
    } catch (e) {
      debugPrint('⚠️ Failed to save onboarding data: $e');
    }
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _key);
  }

  Future<bool> isCompleted() async {
    final data = await getData();
    return data != null && data.organizationName.isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════
  // JSON Serialization
  // ═══════════════════════════════════════════════════════
  Map<String, dynamic> _toJson(OnboardingData data) {
    return {
      'organizationName': data.organizationName,
      'industry': data.industry,
      'customIndustry': data.customIndustry,
      'teamSize': data.teamSize,
      'userRole': data.userRole,
      'customRole': data.customRole,
      'teamEmails': data.teamEmails,
      'isDarkMode': data.isDarkMode,
      'notificationsEnabled': data.notificationsEnabled,
    };
  }

  OnboardingData _fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      organizationName: json['organizationName'] as String? ?? '',
      industry: json['industry'] as String? ?? '',
      customIndustry: json['customIndustry'] as String? ?? '',
      teamSize: json['teamSize'] as String? ?? '',
      userRole: json['userRole'] as String? ?? '',
      customRole: json['customRole'] as String? ?? '',
      teamEmails:
          (json['teamEmails'] as List?)?.cast<String>() ?? const [],
      isDarkMode: json['isDarkMode'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }
}