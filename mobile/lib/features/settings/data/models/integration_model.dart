enum IntegrationType { jira, github }
enum IntegrationStatus { connected, disconnected, connecting }

class IntegrationModel {
  final IntegrationType type;
  final String name;
  final String description;
  final IntegrationStatus status;
  final String? accountName;

  const IntegrationModel({
    required this.type,
    required this.name,
    required this.description,
    this.status = IntegrationStatus.disconnected,
    this.accountName,
  });

  IntegrationModel copyWith({
    IntegrationType? type,
    String? name,
    String? description,
    IntegrationStatus? status,
    String? accountName,
  }) {
    return IntegrationModel(
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      accountName: accountName ?? this.accountName,
    );
  }
}