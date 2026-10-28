import 'package:equatable/equatable.dart';

class OnboardingData extends Equatable {
  // ─── Organization Info ───
  final String organizationName;
  final String industry;
  final String customIndustry;   // ← جديد
  final String teamSize;
  final String userRole;
  final String customRole;       // ← جديد

  // ─── Team Members ───
  final List<String> teamEmails;

  // ─── Preferences ───
  final bool isDarkMode;
  final bool notificationsEnabled;

  const OnboardingData({
    this.organizationName = '',
    this.industry = '',
    this.customIndustry = '',
    this.teamSize = '',
    this.userRole = '',
    this.customRole = '',
    this.teamEmails = const [],
    this.isDarkMode = true,
    this.notificationsEnabled = true,
  });

  /// ─── الـ industry الفعلي (لو Other، استخدم الـ custom) ───
  String get effectiveIndustry {
    if (industry == 'Other' && customIndustry.isNotEmpty) {
      return customIndustry;
    }
    return industry;
  }

  String get effectiveRole {
    if (userRole == 'Other' && customRole.isNotEmpty) {
      return customRole;
    }
    return userRole;
  }

  OnboardingData copyWith({
    String? organizationName,
    String? industry,
    String? customIndustry,
    String? teamSize,
    String? userRole,
    String? customRole,
    List<String>? teamEmails,
    bool? isDarkMode,
    bool? notificationsEnabled,
  }) {
    return OnboardingData(
      organizationName: organizationName ?? this.organizationName,
      industry: industry ?? this.industry,
      customIndustry: customIndustry ?? this.customIndustry,
      teamSize: teamSize ?? this.teamSize,
      userRole: userRole ?? this.userRole,
      customRole: customRole ?? this.customRole,
      teamEmails: teamEmails ?? this.teamEmails,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  @override
  List<Object?> get props => [
        organizationName,
        industry,
        customIndustry,
        teamSize,
        userRole,
        customRole,
        teamEmails,
        isDarkMode,
        notificationsEnabled,
      ];
}

class OnboardingOptions {
  OnboardingOptions._();

  static const industries = [
    'Software Development',
    'Fintech',
    'Healthcare',
    'E-commerce',
    'Education',
    'Other',
  ];

  static const teamSizes = ['1-10', '11-50', '51-200', '200+'];

  static const roles = [
    'Developer',
    'Team Lead',
    'Manager',
    'CTO',
    'Founder',
    'Other',
  ];
}