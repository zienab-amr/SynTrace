class GitHubInstallationOption {
  final int installationId;
  final int accountId;
  final String accountLogin;
  final String accountType;
  final int? repositoryCount;

  const GitHubInstallationOption({
    required this.installationId,
    required this.accountId,
    required this.accountLogin,
    required this.accountType,
    this.repositoryCount,
  });

  factory GitHubInstallationOption.fromJson(Map<String, dynamic> json) {
    return GitHubInstallationOption(
      installationId: _toInt(json['installationId']),
      accountId: _toInt(json['accountId']),
      accountLogin: json['accountLogin']?.toString() ?? '',
      accountType: json['accountType']?.toString() ?? '',
      repositoryCount: json['repositoryCount'] == null
          ? null
          : _toInt(json['repositoryCount']),
    );
  }

  static int _toInt(dynamic value) => value is int
      ? value
      : int.tryParse(value?.toString() ?? '') ?? 0;
}

class GitHubPendingConnection {
  final String kind;
  final String githubLogin;
  final List<GitHubInstallationOption> installations;

  const GitHubPendingConnection({
    required this.kind,
    required this.githubLogin,
    required this.installations,
  });

  factory GitHubPendingConnection.fromJson(Map<String, dynamic> json) {
    final raw = json['installations'];
    return GitHubPendingConnection(
      kind: json['kind']?.toString() ?? '',
      githubLogin: json['githubLogin']?.toString() ?? '',
      installations: raw is List
          ? raw
              .whereType<Map>()
              .map((item) => GitHubInstallationOption.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
    );
  }
}

class GitHubCompanyStatus {
  final bool connected;
  final int? installationId;
  final String? accountLogin;
  final bool suspended;

  const GitHubCompanyStatus({
    required this.connected,
    this.installationId,
    this.accountLogin,
    this.suspended = false,
  });

  factory GitHubCompanyStatus.fromJson(Map<String, dynamic> json) {
    return GitHubCompanyStatus(
      connected: json['connected'] == true,
      installationId: json['installationId'] == null
          ? null
          : GitHubInstallationOption._toInt(json['installationId']),
      accountLogin: json['accountLogin']?.toString(),
      suspended: json['suspended'] == true,
    );
  }
}

class GitHubEmployeeStatus {
  final bool connected;
  final int? githubUserId;
  final String? githubLogin;

  const GitHubEmployeeStatus({
    required this.connected,
    this.githubUserId,
    this.githubLogin,
  });

  factory GitHubEmployeeStatus.fromJson(Map<String, dynamic> json) {
    return GitHubEmployeeStatus(
      connected: json['connected'] == true,
      githubUserId: json['githubUserId'] == null
          ? null
          : GitHubInstallationOption._toInt(json['githubUserId']),
      githubLogin: json['githubLogin']?.toString(),
    );
  }
}
