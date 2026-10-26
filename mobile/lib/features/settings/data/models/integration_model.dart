import 'package:equatable/equatable.dart';

enum IntegrationType { jira, github }

enum IntegrationStatus { connected, disconnected, connecting }

class IntegrationModel extends Equatable 
{
  final IntegrationType type;
  final String name;
  final String description;
  final IntegrationStatus status;
  final DateTime? connectedAt;
  final String? accountName;

  const IntegrationModel({
    required this.type,
    required this.name,
    required this.description,
    required this.status,
    this.connectedAt,
    this.accountName,
  });

  IntegrationModel copyWith({
    IntegrationStatus? status,
    DateTime? connectedAt,
    String? accountName,
  }) {
    return IntegrationModel(
      type: type,
      name: name,
      description: description,
      status: status ?? this.status,
      connectedAt: connectedAt ?? this.connectedAt,
      accountName: accountName ?? this.accountName,
    );
  }

  @override
  List<Object?> get props =>
      [type, name, description, status, connectedAt, accountName];
}