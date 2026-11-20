import 'package:equatable/equatable.dart';

class OnboardingData extends Equatable {
  final String organizationName;
  final String industry;
  final String customIndustry;
  final String teamSize;
  final String userRole;
  final String customRole;
  final List<Map<String, String>> teamMembers;
  final bool isDarkMode;
  final bool notificationsEnabled;

  const OnboardingData({
    this.organizationName = '',
    this.industry = '',
    this.customIndustry = '',
    this.teamSize = '',
    this.userRole = '',
    this.customRole = '',
    this.teamMembers = const [],
    this.isDarkMode = true,
    this.notificationsEnabled = true,
  });

  OnboardingData copyWith({
    String? organizationName,
    String? industry,
    String? customIndustry,
    String? teamSize,
    String? userRole,
    String? customRole,
    List<Map<String, String>>? teamMembers,
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
      teamMembers: teamMembers ?? this.teamMembers,
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
    teamMembers,
    isDarkMode,
    notificationsEnabled,
  ];
}

class OnboardingOptions {
  static const List<String> industries = [
    'Technology',
    'Finance',
    'Healthcare',
    'E-commerce',
    'Education',
    'Other',
  ];

  static const List<String> teamSizes = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '500+',
  ];
}
