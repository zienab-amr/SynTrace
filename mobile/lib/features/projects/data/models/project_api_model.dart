import 'package:equatable/equatable.dart';

enum ProjectApiStatus {
  notStarted,
  inProgress,
  onHold,
  completed,
  cancelled,
  archived,
  unknown;

  static ProjectApiStatus fromJson(dynamic value) {
    if (value is int) {
      switch (value) {
        case 0:
          return notStarted;
        case 1:
          return inProgress;
        case 2:
          return onHold;
        case 3:
          return completed;
        case 4:
          return cancelled;
        case 5:
          return archived;
        default:
          return unknown;
      }
    }

    final normalized = value
        ?.toString()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');

    switch (normalized) {
      case 'notstarted':
        return notStarted;
      case 'inprogress':
        return inProgress;
      case 'onhold':
        return onHold;
      case 'completed':
        return completed;
      case 'cancelled':
        return cancelled;
      case 'archived':
        return archived;
      default:
        return unknown;
    }
  }

  String get label {
    switch (this) {
      case notStarted:
        return 'Not Started';
      case inProgress:
        return 'In Progress';
      case onHold:
        return 'On Hold';
      case completed:
        return 'Completed';
      case cancelled:
        return 'Cancelled';
      case archived:
        return 'Archived';
      case unknown:
        return 'Not Available';
    }
  }

  int get apiValue {
    if (this == unknown) {
      throw StateError('Unknown project status cannot be submitted.');
    }

    return index;
  }
}

class ProjectApiModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String clientId;
  final String? jiraProjectId;
  final ProjectApiStatus? status;

  const ProjectApiModel({
    required this.id,
    required this.name,
    required this.clientId,
    this.description,
    this.jiraProjectId,
    this.status,
  });

  factory ProjectApiModel.fromJson(Map<String, dynamic> json) {
    final id = json['projectId'] as String?;
    final name = json['projectName'] as String?;
    final clientId = json['clientId'] as String?;

    if (id == null || id.isEmpty || name == null || clientId == null) {
      throw const FormatException('Invalid project response.');
    }

    return ProjectApiModel(
      id: id,
      name: name,
      clientId: clientId,
      description: json['description'] as String?,
      jiraProjectId: json['jiraProjectId'] as String?,
      status: json['status'] == null
          ? null
          : ProjectApiStatus.fromJson(json['status']),
    );
  }

  bool get hasJiraProject => jiraProjectId?.isNotEmpty ?? false;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    clientId,
    jiraProjectId,
    status,
  ];
}

class JiraProjectOption extends Equatable {
  final String id;
  final String key;
  final String name;

  const JiraProjectOption({
    required this.id,
    required this.key,
    required this.name,
  });

  factory JiraProjectOption.fromJson(Map<String, dynamic> json) {
    return JiraProjectOption(
      id: json['jiraProjectId'] as String,
      key: json['key'] as String,
      name: json['name'] as String,
    );
  }

  @override
  List<Object?> get props => [id, key, name];
}
