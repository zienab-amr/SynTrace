import 'package:equatable/equatable.dart';

class CommitModel extends Equatable {
  final String id;
  final String sha;             // hash بتاع الـ commit
  final String message;
  final String authorName;
  final String? authorEmail;
  final String? authorId;       // ← يربط بالـ User
  final String repositoryName;
  final String branch;
  final int additions;
  final int deletions;
  final int changedFiles;
  final DateTime committedAt;
  final String? taskId;         // ← يربط بالـ Task (SYNT-XX)
  final String? projectId;
  final DateTime? createdAt;

  const CommitModel({
    required this.id,
    required this.sha,
    required this.message,
    required this.authorName,
    this.authorEmail,
    this.authorId,
    required this.repositoryName,
    required this.branch,
    this.additions = 0,
    this.deletions = 0,
    this.changedFiles = 0,
    required this.committedAt,
    this.taskId,
    this.projectId,
    this.createdAt,
  });

  factory CommitModel.fromJson(Map<String, dynamic> json) {
    return CommitModel(
      id: json['id'] as String? ?? '',
      sha: json['sha'] as String? ?? '',
      message: json['message'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorEmail: json['authorEmail'] as String?,
      authorId: json['authorId'] as String?,
      repositoryName: json['repositoryName'] as String? ?? '',
      branch: json['branch'] as String? ?? 'main',
      additions: json['additions'] as int? ?? 0,
      deletions: json['deletions'] as int? ?? 0,
      changedFiles: json['changedFiles'] as int? ?? 0,
      committedAt: json['committedAt'] != null
          ? DateTime.tryParse(json['committedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      taskId: json['taskId'] as String?,
      projectId: json['projectId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sha': sha,
      'message': message,
      'authorName': authorName,
      'authorEmail': authorEmail,
      'authorId': authorId,
      'repositoryName': repositoryName,
      'branch': branch,
      'additions': additions,
      'deletions': deletions,
      'changedFiles': changedFiles,
      'committedAt': committedAt.toIso8601String(),
      'taskId': taskId,
      'projectId': projectId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  CommitModel copyWith({
    String? id,
    String? sha,
    String? message,
    String? authorName,
    String? authorEmail,
    String? authorId,
    String? repositoryName,
    String? branch,
    int? additions,
    int? deletions,
    int? changedFiles,
    DateTime? committedAt,
    String? taskId,
    String? projectId,
    DateTime? createdAt,
  }) {
    return CommitModel(
      id: id ?? this.id,
      sha: sha ?? this.sha,
      message: message ?? this.message,
      authorName: authorName ?? this.authorName,
      authorEmail: authorEmail ?? this.authorEmail,
      authorId: authorId ?? this.authorId,
      repositoryName: repositoryName ?? this.repositoryName,
      branch: branch ?? this.branch,
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
      changedFiles: changedFiles ?? this.changedFiles,
      committedAt: committedAt ?? this.committedAt,
      taskId: taskId ?? this.taskId,
      projectId: projectId ?? this.projectId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isLinkedToTask => taskId != null && taskId!.isNotEmpty;
  String get shortSha => sha.length > 7 ? sha.substring(0, 7) : sha;
  int get totalChanges => additions + deletions;

  @override
  List<Object?> get props => [
        id, sha, message, authorName, authorEmail, authorId,
        repositoryName, branch, additions, deletions, changedFiles,
        committedAt, taskId, projectId, createdAt,
      ];
}