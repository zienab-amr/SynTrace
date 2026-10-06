import 'package:equatable/equatable.dart';

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
  final int currentSprint;
  final int totalSprints;
  final DateTime? sprintEnd;
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
    this.currentSprint = 1,
    this.totalSprints = 1,
    this.sprintEnd,
    this.createdAt,
    this.updatedAt,
  });

  // ═══════════════════════════════════════════════════════
  // fromJson
  // ═══════════════════════════════════════════════════════
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
      currentSprint: json['currentSprint'] as int? ?? 1,
      totalSprints: json['totalSprints'] as int? ?? 1,
      sprintEnd: json['sprintEnd'] != null
          ? DateTime.tryParse(json['sprintEnd'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════
  // toJson
  // ═══════════════════════════════════════════════════════
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
      'currentSprint': currentSprint,
      'totalSprints': totalSprints,
      'sprintEnd': sprintEnd?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // ═══════════════════════════════════════════════════════
  // copyWith
  // ═══════════════════════════════════════════════════════
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
    int? currentSprint,
    int? totalSprints,
    DateTime? sprintEnd,
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
      currentSprint: currentSprint ?? this.currentSprint,
      totalSprints: totalSprints ?? this.totalSprints,
      sprintEnd: sprintEnd ?? this.sprintEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ═══════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════
  bool get isActive => status == ProjectStatus.active;
  bool get isCompleted => status == ProjectStatus.completed;
  bool get isArchived => status == ProjectStatus.archived;

  /// ─── Sprint info ───
  String get sprintLabel => 'Sprint $currentSprint of $totalSprints';

  // ═══════════════════════════════════════════════════════
  // Equatable
  // ═══════════════════════════════════════════════════════
  @override
  List<Object?> get props => [
        id,
        name,
        description,
        status,
        startDate,
        endDate,
        tenantId,
        ownerId,
        memberIds,
        currentSprint,
        totalSprints,
        sprintEnd,
        createdAt,
        updatedAt,
      ];
}

// ═══════════════════════════════════════════════════════════
// ProjectStatus
// ═══════════════════════════════════════════════════════════
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