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

  static int _toInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
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
                .map(
                  (item) => GitHubInstallationOption.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
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

class GitHubRepositoryOption {
  final int repositoryId;
  final String owner;
  final String name;
  final String fullName;
  final String? defaultBranch;
  final bool isPrivate;

  const GitHubRepositoryOption({
    required this.repositoryId,
    required this.owner,
    required this.name,
    required this.fullName,
    this.defaultBranch,
    required this.isPrivate,
  });

  factory GitHubRepositoryOption.fromJson(Map<String, dynamic> json) {
    return GitHubRepositoryOption(
      repositoryId: (json['repositoryId'] as num).toInt(),
      owner: json['owner'] as String,
      name: json['name'] as String,
      fullName: json['fullName'] as String,
      defaultBranch: json['defaultBranch'] as String?,
      isPrivate: json['isPrivate'] as bool,
    );
  }
}

enum GitHubSyncStatus {
  notMapped('not-mapped'),
  pending('pending'),
  retrying('retrying'),
  synced('synced'),
  unavailable('unavailable'),
  unknown('unknown');

  final String value;

  const GitHubSyncStatus(this.value);

  static GitHubSyncStatus fromJson(dynamic value) {
    return GitHubSyncStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => GitHubSyncStatus.unknown,
    );
  }

  String get label {
    switch (this) {
      case GitHubSyncStatus.notMapped:
        return 'Not Linked';

      case GitHubSyncStatus.pending:
        return 'Sync Pending';

      case GitHubSyncStatus.retrying:
        return 'Retrying';

      case GitHubSyncStatus.synced:
        return 'Synced';

      case GitHubSyncStatus.unavailable:
        return 'Unavailable';

      case GitHubSyncStatus.unknown:
        return 'Unknown';
    }
  }

  bool get isProcessing =>
      this == GitHubSyncStatus.pending || this == GitHubSyncStatus.retrying;

  bool get isSynced => this == GitHubSyncStatus.synced;
}

class GitHubProjectStatus {
  final String projectId;
  final String? bindingId;
  final int? repositoryId;
  final String? fullName;
  final String? defaultBranch;
  final GitHubSyncStatus syncStatus;
  final DateTime? lastSuccessAtUtc;

  const GitHubProjectStatus({
    required this.projectId,
    this.bindingId,
    this.repositoryId,
    this.fullName,
    this.defaultBranch,
    required this.syncStatus,
    this.lastSuccessAtUtc,
  });

  factory GitHubProjectStatus.fromJson(Map<String, dynamic> json) {
    return GitHubProjectStatus(
      projectId: json['projectId'] as String,
      bindingId: json['bindingId'] as String?,
      repositoryId: (json['repositoryId'] as num?)?.toInt(),
      fullName: json['fullName'] as String?,
      defaultBranch: json['defaultBranch'] as String?,
      syncStatus: GitHubSyncStatus.fromJson(json['syncStatus']),
      lastSuccessAtUtc: DateTime.tryParse(
        json['lastSuccessAtUtc']?.toString() ?? '',
      ),
    );
  }

  bool get isMapped => bindingId != null && repositoryId != null;

  bool get isProcessing => syncStatus.isProcessing;

  bool get isSynced => syncStatus.isSynced;

  bool get isUnavailable => syncStatus == GitHubSyncStatus.unavailable;

  bool get canRequestSync =>
      isMapped &&
      !isUnavailable &&
      (syncStatus == GitHubSyncStatus.synced ||
          syncStatus == GitHubSyncStatus.retrying);

  bool get canUnlink => isMapped;

  bool get canSelectRepository => syncStatus == GitHubSyncStatus.notMapped;
}

class GitHubSyncCoverage {
  final String bindingId;
  final int repositoryId;
  final String fullName;
  final int requestedVersion;
  final int completedVersion;
  final String phase;
  final DateTime? lastSuccessAtUtc;
  final String? lastFailure;
  final String? lastIndexedHeadSha;

  const GitHubSyncCoverage({
    required this.bindingId,
    required this.repositoryId,
    required this.fullName,
    required this.requestedVersion,
    required this.completedVersion,
    required this.phase,
    this.lastSuccessAtUtc,
    this.lastFailure,
    this.lastIndexedHeadSha,
  });

  factory GitHubSyncCoverage.fromJson(Map<String, dynamic> json) {
    return GitHubSyncCoverage(
      bindingId: json['id'] as String,
      repositoryId: (json['repositoryId'] as num).toInt(),
      fullName: json['fullName'] as String,
      requestedVersion: (json['requestedVersion'] as num).toInt(),
      completedVersion: (json['completedVersion'] as num).toInt(),
      phase: json['phase'] as String,
      lastSuccessAtUtc: DateTime.tryParse(
        json['lastSuccessAtUtc']?.toString() ?? '',
      ),
      lastFailure: json['lastFailure'] as String?,
      lastIndexedHeadSha: json['lastIndexedHeadSha'] as String?,
    );
  }

  bool get hasFailure => lastFailure?.trim().isNotEmpty ?? false;

  bool get hasCompletedRequestedVersion => completedVersion >= requestedVersion;

  bool get hasIndexedHead => lastIndexedHeadSha?.isNotEmpty ?? false;

  String get phaseLabel {
    switch (phase) {
      case 'start':
        return 'Repository Sync';

      case 'commits':
        return 'Importing Commits';

      case 'pull_requests':
        return 'Importing Pull Requests';

      case 'code':
        return 'Processing Source Code';

      default:
        return 'Unknown Phase';
    }
  }
}
