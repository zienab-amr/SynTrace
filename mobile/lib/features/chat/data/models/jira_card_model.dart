import 'package:equatable/equatable.dart';

/// ═══════════════════════════════════════════════════════════
/// Jira Card Model
/// ═══════════════════════════════════════════════════════════
class JiraCardModel extends Equatable {
  final String issueKey;       // "SYNT-45"
  final String summary;        // "Fix Customer Table schema"
  final String status;         // "In Progress"
  final String statusCategory; // "todo" | "in_progress" | "done" | "blocked"
  final String priority;       // "High"
  final String issueType;      // "Task" | "Bug" | "Story"
  final String? assigneeName;  // "Ahmed Kamal"
  final String url;            // "https://jira.../SYNT-45"

  const JiraCardModel({
    required this.issueKey,
    required this.summary,
    required this.status,
    required this.statusCategory,
    required this.priority,
    required this.issueType,
    this.assigneeName,
    required this.url,
  });

  factory JiraCardModel.fromJson(Map<String, dynamic> json) {
    return JiraCardModel(
      issueKey: json['issueKey'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      status: json['status'] as String? ?? 'Todo',
      statusCategory: json['statusCategory'] as String? ?? 'todo',
      priority: json['priority'] as String? ?? 'Medium',
      issueType: json['issueType'] as String? ?? 'Task',
      assigneeName: json['assigneeName'] as String?,
      url: json['url'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
        issueKey,
        summary,
        status,
        statusCategory,
        priority,
        issueType,
        assigneeName,
        url,
      ];
      JiraCardModel copyWith({
  String? issueKey,
  String? summary,
  String? status,
  String? statusCategory,
  String? priority,
  String? issueType,
  String? assigneeName,
  String? url,
}) {
  return JiraCardModel(
    issueKey: issueKey ?? this.issueKey,
    summary: summary ?? this.summary,
    status: status ?? this.status,
    statusCategory: statusCategory ?? this.statusCategory,
    priority: priority ?? this.priority,
    issueType: issueType ?? this.issueType,
    assigneeName: assigneeName ?? this.assigneeName,
    url: url ?? this.url,
  );
}
}