class TaskModel {
  final String id;
  final String projectId;
  final String title;
  final String status;
  final String priority;
  final String assigneeName;

  const TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    required this.priority,
    required this.assigneeName,
  });
}
