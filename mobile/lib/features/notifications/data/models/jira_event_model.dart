import 'package:equatable/equatable.dart';

enum JiraEventCategory {
  issue,
  comment,
  sprint,
  worklog,
  project,
  user,
  issueType,
  board,
}

class JiraEventModel extends Equatable {
  final String id;
  final String action;
  final JiraEventCategory category;
  final String title;
  final String description;
  final String actorName;
  final DateTime timestamp;

  const JiraEventModel({
    required this.id,
    required this.action,
    required this.category,
    required this.title,
    required this.description,
    required this.actorName,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
    id,
    action,
    category,
    title,
    description,
    actorName,
    timestamp,
  ];
}
