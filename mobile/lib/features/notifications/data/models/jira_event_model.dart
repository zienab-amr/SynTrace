import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

enum JiraEventCategory { issue, comment, sprint, worklog, project, user, issueType, board }

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

  Color get color {
    switch (category) {
      case JiraEventCategory.issue:
        return Colors.blue;
      case JiraEventCategory.comment:
        return Colors.green;
      case JiraEventCategory.sprint:
        return Colors.purple;
      case JiraEventCategory.worklog:
        return Colors.orange;
      case JiraEventCategory.project:
        return Colors.teal;
      case JiraEventCategory.user:
        return Colors.pink;
      case JiraEventCategory.issueType:
        return Colors.amber;
      case JiraEventCategory.board:
        return Colors.indigo;
    }
  }

  IconData get icon {
    switch (category) {
      case JiraEventCategory.issue:
        return Icons.task_alt;
      case JiraEventCategory.comment:
        return Icons.chat_bubble_outline;
      case JiraEventCategory.sprint:
        return Icons.directions_run;
      case JiraEventCategory.worklog:
        return Icons.timer_outlined;
      case JiraEventCategory.project:
        return Icons.folder_outlined;
      case JiraEventCategory.user:
        return Icons.person_outline;
      case JiraEventCategory.issueType:
        return Icons.category_outlined;
      case JiraEventCategory.board:
        return Icons.dashboard_outlined;
    }
  }

  @override
  List<Object?> get props => [id, action, category, title, description, actorName, timestamp];
}