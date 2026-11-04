import 'package:equatable/equatable.dart';

class JiraCardModel extends Equatable {
  final String issueKey;
  final String summary;
  final String status;
  final String statusCategory;
  final String priority;
  final String issueType;
  final String? assigneeName;
  final String url;

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

  Map<String, dynamic> toJson() {
    return {
      'issueKey': issueKey,
      'summary': summary,
      'status': status,
      'statusCategory': statusCategory,
      'priority': priority,
      'issueType': issueType,
      'assigneeName': assigneeName,
      'url': url,
    };
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
}