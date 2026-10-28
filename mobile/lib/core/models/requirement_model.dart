import 'package:equatable/equatable.dart';

class RequirementModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final RequirementType type;
  final RequirementStatus status;
  final RequirementPriority priority;
  final String projectId;
  final String? createdById;
  final List<String> linkedTaskIds;
  final List<String> linkedCommitShas;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RequirementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.priority,
    required this.projectId,
    this.createdById,
    this.linkedTaskIds = const [],
    this.linkedCommitShas = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory RequirementModel.fromJson(Map<String, dynamic> json) {
    return RequirementModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: RequirementType.fromString(json['type'] as String?),
      status: RequirementStatus.fromString(json['status'] as String?),
      priority: RequirementPriority.fromString(json['priority'] as String?),
      projectId: json['projectId'] as String? ?? '',
      createdById: json['createdById'] as String?,
      linkedTaskIds: json['linkedTaskIds'] != null
          ? List<String>.from(json['linkedTaskIds'] as List)
          : const [],
      linkedCommitShas: json['linkedCommitShas'] != null
          ? List<String>.from(json['linkedCommitShas'] as List)
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
      'title': title,
      'description': description,
      'type': type.value,
      'status': status.value,
      'priority': priority.value,
      'projectId': projectId,
      'createdById': createdById,
      'linkedTaskIds': linkedTaskIds,
      'linkedCommitShas': linkedCommitShas,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  RequirementModel copyWith({
    String? id,
    String? title,
    String? description,
    RequirementType? type,
    RequirementStatus? status,
    RequirementPriority? priority,
    String? projectId,
    String? createdById,
    List<String>? linkedTaskIds,
    List<String>? linkedCommitShas,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RequirementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      projectId: projectId ?? this.projectId,
      createdById: createdById ?? this.createdById,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
      linkedCommitShas: linkedCommitShas ?? this.linkedCommitShas,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isImplemented => linkedCommitShas.isNotEmpty;
  bool get isLinkedToTasks => linkedTaskIds.isNotEmpty;

  @override
  List<Object?> get props => [
        id, title, description, type, status, priority, projectId,
        createdById, linkedTaskIds, linkedCommitShas, createdAt, updatedAt,
      ];
}

enum RequirementType {
  functional('functional'),
  nonFunctional('non_functional'),
  business('business'),
  technical('technical');

  final String value;
  const RequirementType(this.value);

  static RequirementType fromString(String? value) {
    if (value == null) return RequirementType.functional;
    return RequirementType.values.firstWhere(
      (t) => t.value.toLowerCase() == value.toLowerCase(),
      orElse: () => RequirementType.functional,
    );
  }
}

enum RequirementStatus {
  draft('draft'),
  approved('approved'),
  inProgress('in_progress'),
  implemented('implemented'),
  rejected('rejected');

  final String value;
  const RequirementStatus(this.value);

  static RequirementStatus fromString(String? value) {
    if (value == null) return RequirementStatus.draft;
    return RequirementStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == value.toLowerCase(),
      orElse: () => RequirementStatus.draft,
    );
  }
}

enum RequirementPriority {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String value;
  const RequirementPriority(this.value);

  static RequirementPriority fromString(String? value) {
    if (value == null) return RequirementPriority.medium;
    return RequirementPriority.values.firstWhere(
      (p) => p.value.toLowerCase() == value.toLowerCase(),
      orElse: () => RequirementPriority.medium,
    );
  }
}