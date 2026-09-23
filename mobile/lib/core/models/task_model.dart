import 'package:equatable/equatable.dart';

class TaskModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final String projectId;
  final String? assigneeId;
  final String? reporterId;
  final String? sprintId;
  final DateTime? dueDate;
  final double? estimatedHours;
  final double? loggedHours;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.projectId,
    this.assigneeId,
    this.reporterId,
    this.sprintId,
    this.dueDate,
    this.estimatedHours,
    this.loggedHours,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: TaskStatus.fromString(json['status'] as String?),
      priority: TaskPriority.fromString(json['priority'] as String?),
      projectId: json['projectId'] as String? ?? '',
      assigneeId: json['assigneeId'] as String?,
      reporterId: json['reporterId'] as String?,
      sprintId: json['sprintId'] as String?,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      estimatedHours: (json['estimatedHours'] as num?)?.toDouble(),
      loggedHours: (json['loggedHours'] as num?)?.toDouble(),
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
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
      'status': status.value,
      'priority': priority.value,
      'projectId': projectId,
      'assigneeId': assigneeId,
      'reporterId': reporterId,
      'sprintId': sprintId,
      'dueDate': dueDate?.toIso8601String(),
      'estimatedHours': estimatedHours,
      'loggedHours': loggedHours,
      'tags': tags,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    String? projectId,
    String? assigneeId,
    String? reporterId,
    String? sprintId,
    DateTime? dueDate,
    double? estimatedHours,
    double? loggedHours,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      projectId: projectId ?? this.projectId,
      assigneeId: assigneeId ?? this.assigneeId,
      reporterId: reporterId ?? this.reporterId,
      sprintId: sprintId ?? this.sprintId,
      dueDate: dueDate ?? this.dueDate,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      loggedHours: loggedHours ?? this.loggedHours,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isDone => status == TaskStatus.done;
  bool get isInProgress => status == TaskStatus.inProgress;
  bool get isBlocked => status == TaskStatus.blocked;
  bool get isOverdue =>
      dueDate != null && !isDone && dueDate!.isBefore(DateTime.now());

  @override
  List<Object?> get props => [
        id, title, description, status, priority, projectId,
        assigneeId, reporterId, sprintId, dueDate, estimatedHours,
        loggedHours, tags, createdAt, updatedAt,
      ];
}

enum TaskStatus {
  todo('todo'),
  inProgress('in_progress'),
  inReview('in_review'),
  done('done'),
  blocked('blocked');

  final String value;
  const TaskStatus(this.value);

  static TaskStatus fromString(String? value) {
    if (value == null) return TaskStatus.todo;
    return TaskStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == value.toLowerCase(),
      orElse: () => TaskStatus.todo,
    );
  }
}

enum TaskPriority {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String value;
  const TaskPriority(this.value);

  static TaskPriority fromString(String? value) {
    if (value == null) return TaskPriority.medium;
    return TaskPriority.values.firstWhere(
      (p) => p.value.toLowerCase() == value.toLowerCase(),
      orElse: () => TaskPriority.medium,
    );
  }
}