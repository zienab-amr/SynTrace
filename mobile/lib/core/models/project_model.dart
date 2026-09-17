import 'package:equatable/equatable.dart';
import 'user_model.dart';

class ProjectModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final ProjectStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? tenantId;
  final String? ownerId;
  final List<String> memberIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProjectModel({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.startDate,
    this.endDate,
    this.tenantId,
    this.ownerId,
    this.memberIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: ProjectStatus.fromString(json['status'] as String?),
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      tenantId: json['tenantId'] as String?,
      ownerId: json['ownerId'] as String?,
      memberIds: json['memberIds'] != null
          ? List<String>.from(json['memberIds'] as List)
          : const [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status.value,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'tenantId': tenantId,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    ProjectStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? tenantId,
    String? ownerId,
    List<String>? memberIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      tenantId: tenantId ?? this.tenantId,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == ProjectStatus.active;
  bool get isCompleted => status == ProjectStatus.completed;
  bool get isArchived => status == ProjectStatus.archived;

  @override
  List<Object?> get props => [
        id, name, description, status, startDate, endDate,
        tenantId, ownerId, memberIds, createdAt, updatedAt,
      ];
}

enum ProjectStatus {
  active('active'),
  completed('completed'),
  archived('archived'),
  onHold('on_hold');

  final String value;
  const ProjectStatus(this.value);

  static ProjectStatus fromString(String? value) {
    if (value == null) return ProjectStatus.active;
    return ProjectStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == value.toLowerCase(),
      orElse: () => ProjectStatus.active,
    );
  }
}