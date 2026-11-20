import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'onboarding_data.dart';

class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  final _storage = const FlutterSecureStorage();
  static const _key = 'onboarding_data';

  Future<void> saveData(OnboardingData data) async {
    final jsonMap = {
      'organizationName': data.organizationName,
      'industry': data.industry,
      'customIndustry': data.customIndustry,
      'teamSize': data.teamSize,
      'userRole': data.userRole,
      'customRole': data.customRole,
      'teamMembers': data.teamMembers,
      'isDarkMode': data.isDarkMode,
      'notificationsEnabled': data.notificationsEnabled,
    };
    await _storage.write(key: _key, value: jsonEncode(jsonMap));
  }

  Future<OnboardingData?> loadData() async {
    final jsonString = await _storage.read(key: _key);
    if (jsonString == null) return null;

    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

    return OnboardingData(
      organizationName: jsonMap['organizationName'] ?? '',
      industry: jsonMap['industry'] ?? '',
      customIndustry: jsonMap['customIndustry'] ?? '',
      teamSize: jsonMap['teamSize'] ?? '',
      userRole: jsonMap['userRole'] ?? '',
      customRole: jsonMap['customRole'] ?? '',
      teamMembers: jsonMap['teamMembers'] != null
          ? List<Map<String, String>>.from(
              jsonMap['teamMembers'].map((x) => Map<String, String>.from(x)),
            )
          : [], // التعديل هنا
      isDarkMode: jsonMap['isDarkMode'] ?? true,
      notificationsEnabled: jsonMap['notificationsEnabled'] ?? true,
    );
  }
}
