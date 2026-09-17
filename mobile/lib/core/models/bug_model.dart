import 'package:equatable/equatable.dart';

class BugModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final BugStatus status;
  final BugSeverity severity;
  final BugPriority priority;
  final String projectId;
  final String? assigneeId;
  final String? reporterId;
  final String? relatedCommitSha;
  final String? relatedTaskId;
  final int recurrenceCount;     // ← للـ ML Model
  final List<String> affectedFiles;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BugModel({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.severity,
    required this.priority,
    required this.projectId,
    this.assigneeId,
    this.reporterId,
    this.relatedCommitSha,
    this.relatedTaskId,
    this.recurrenceCount = 0,
    this.affectedFiles = const [],
    this.resolvedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory BugModel.fromJson(Map<String, dynamic> json) {
    return BugModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: BugStatus.fromString(json['status'] as String?),
      severity: BugSeverity.fromString(json['severity'] as String?),
      priority: BugPriority.fromString(json['priority'] as String?),
      projectId: json['projectId'] as String? ?? '',
      assigneeId: json['assigneeId'] as String?,
      reporterId: json['reporterId'] as String?,
      relatedCommitSha: json['relatedCommitSha'] as String?,
      relatedTaskId: json['relatedTaskId'] as String?,
      recurrenceCount: json['recurrenceCount'] as int? ?? 0,
      affectedFiles: json['affectedFiles'] != null
          ? List<String>.from(json['affectedFiles'] as List)
          : const [],
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
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
      'status': status.value,
      'severity': severity.value,
      'priority': priority.value,
      'projectId': projectId,
      'assigneeId': assigneeId,
      'reporterId': reporterId,
      'relatedCommitSha': relatedCommitSha,
      'relatedTaskId': relatedTaskId,
      'recurrenceCount': recurrenceCount,
      'affectedFiles': affectedFiles,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  BugModel copyWith({
    String? id,
    String? title,
    String? description,
    BugStatus? status,
    BugSeverity? severity,
    BugPriority? priority,
    String? projectId,
    String? assigneeId,
    String? reporterId,
    String? relatedCommitSha,
    String? relatedTaskId,
    int? recurrenceCount,
    List<String>? affectedFiles,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BugModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      priority: priority ?? this.priority,
      projectId: projectId ?? this.projectId,
      assigneeId: assigneeId ?? this.assigneeId,
      reporterId: reporterId ?? this.reporterId,
      relatedCommitSha: relatedCommitSha ?? this.relatedCommitSha,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      affectedFiles: affectedFiles ?? this.affectedFiles,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isResolved => status == BugStatus.resolved || status == BugStatus.closed;
  bool get isCritical => severity == BugSeverity.critical;
  bool get isRecurring => recurrenceCount > 1;
  bool get isLinked => relatedCommitSha != null || relatedTaskId != null;

  @override
  List<Object?> get props => [
        id, title, description, status, severity, priority, projectId,
        assigneeId, reporterId, relatedCommitSha, relatedTaskId,
        recurrenceCount, affectedFiles, resolvedAt, createdAt, updatedAt,
      ];
}

enum BugStatus {
  open('open'),
  inProgress('in_progress'),
  resolved('resolved'),
  closed('closed'),
  reopened('reopened');

  final String value;
  const BugStatus(this.value);

  static BugStatus fromString(String? value) {
    if (value == null) return BugStatus.open;
    return BugStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == value.toLowerCase(),
      orElse: () => BugStatus.open,
    );
  }
}

enum BugSeverity {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String value;
  const BugSeverity(this.value);

  static BugSeverity fromString(String? value) {
    if (value == null) return BugSeverity.medium;
    return BugSeverity.values.firstWhere(
      (s) => s.value.toLowerCase() == value.toLowerCase(),
      orElse: () => BugSeverity.medium,
    );
  }
}

enum BugPriority {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  final String value;
  const BugPriority(this.value);

  static BugPriority fromString(String? value) {
    if (value == null) return BugPriority.medium;
    return BugPriority.values.firstWhere(
      (p) => p.value.toLowerCase() == value.toLowerCase(),
      orElse: () => BugPriority.medium,
    );
  }
}