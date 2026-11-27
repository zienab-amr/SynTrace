enum IntegrationType { jira, github }

enum IntegrationStatus { connected, disconnected, connecting, unknown }

class IntegrationModel {
  final IntegrationType type;
  final String name;
  final String description;
  final IntegrationStatus status;
  final String? accountName;
  final bool suspended;

  final bool isFromCache;
  final DateTime? lastSyncedAt;

  const IntegrationModel({
    required this.type,
    required this.name,
    required this.description,
    this.status = IntegrationStatus.unknown,
    this.accountName,
    this.suspended = false,
    this.isFromCache = false,
    this.lastSyncedAt,
  });

  bool get canModify =>
      !isFromCache &&
      status != IntegrationStatus.unknown &&
      status != IntegrationStatus.connecting;

  IntegrationModel copyWith({
    IntegrationType? type,
    String? name,
    String? description,
    IntegrationStatus? status,
    String? accountName,
    bool? suspended,
    bool? isFromCache,
    DateTime? lastSyncedAt,
    bool clearAccountName = false,
    bool clearLastSyncedAt = false,
  }) {
    return IntegrationModel(
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      accountName: clearAccountName ? null : accountName ?? this.accountName,
      suspended: suspended ?? this.suspended,
      isFromCache: isFromCache ?? this.isFromCache,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
