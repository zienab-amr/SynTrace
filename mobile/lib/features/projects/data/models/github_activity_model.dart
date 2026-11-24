import 'package:syntrace/features/settings/data/models/github_model.dart';

enum GitHubActivityKind {
  commit,
  pullRequest;

  String get apiValue => switch (this) {
    GitHubActivityKind.commit => 'commit',
    GitHubActivityKind.pullRequest => 'pull_request',
  };

  String get label => switch (this) {
    GitHubActivityKind.commit => 'Commits',
    GitHubActivityKind.pullRequest => 'Pull Requests',
  };
}

class GitHubChangedFile {
  final String? path;
  final String? previousPath;
  final String? status;
  final int? additions;
  final int? deletions;

  const GitHubChangedFile({
    this.path,
    this.previousPath,
    this.status,
    this.additions,
    this.deletions,
  });

  factory GitHubChangedFile.fromJson(Map<String, dynamic> json) {
    return GitHubChangedFile(
      path: json['path'] as String?,
      previousPath: json['previousPath'] as String?,
      status: json['status'] as String?,
      additions: json['additions'] as int?,
      deletions: json['deletions'] as int?,
    );
  }

  bool get isRenamed => previousPath != null && previousPath != path;
}

class GitHubJiraReference {
  final String key;
  final String? status;
  final String? summary;
  final String? url;

  const GitHubJiraReference({
    required this.key,
    this.status,
    this.summary,
    this.url,
  });

  factory GitHubJiraReference.fromJson(Map<String, dynamic> json) {
    return GitHubJiraReference(
      key: json['key'] as String,
      status: json['status'] as String?,
      summary: json['summary'] as String?,
      url: json['url'] as String?,
    );
  }
}

class GitHubLinkedActor {
  final int githubUserId;
  final String employeeId;
  final String jiraAccountId;

  const GitHubLinkedActor({
    required this.githubUserId,
    required this.employeeId,
    required this.jiraAccountId,
  });

  factory GitHubLinkedActor.fromJson(Map<String, dynamic> json) {
    return GitHubLinkedActor(
      githubUserId: json['gitHubUserId'] as int,
      employeeId: json['employeeId'] as String,
      jiraAccountId: json['jiraAccountId'] as String,
    );
  }
}

class GitHubActivityItem {
  final GitHubActivityKind kind;

  final String? sha;
  final int? number;

  final String? message;
  final String? title;
  final String? body;

  final int? authorId;
  final String? authorLogin;

  final String? state;
  final bool draft;

  final String? headRef;
  final String? baseRef;
  final String? headSha;
  final String? mergeCommitSha;

  final DateTime? commitDate;
  final DateTime? authoredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final DateTime? mergedAt;

  final String? url;

  final List<GitHubChangedFile> files;
  final bool filesMayBeIncomplete;

  final List<String> commitShas;
  final List<String> parents;
  final bool commitsMayBeIncomplete;

  final List<GitHubJiraReference> jira;
  final List<String> unresolvedJiraKeys;

  final GitHubLinkedActor? linkedAuthor;
  final GitHubLinkedActor? linkedMergedBy;

  const GitHubActivityItem({
    required this.kind,
    this.sha,
    this.number,
    this.message,
    this.title,
    this.body,
    this.authorId,
    this.authorLogin,
    this.state,
    this.draft = false,
    this.headRef,
    this.baseRef,
    this.headSha,
    this.mergeCommitSha,
    this.commitDate,
    this.authoredAt,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.mergedAt,
    this.url,
    this.files = const [],
    this.filesMayBeIncomplete = false,
    this.commitShas = const [],
    this.parents = const [],
    this.commitsMayBeIncomplete = false,
    this.jira = const [],
    this.unresolvedJiraKeys = const [],
    this.linkedAuthor,
    this.linkedMergedBy,
  });

  factory GitHubActivityItem.fromJson(
    Map<String, dynamic> json,
    GitHubActivityKind kind,
  ) {
    final activity = Map<String, dynamic>.from(json['activity'] as Map);

    final sha = activity['sha'] as String?;
    final number = activity['number'] as int?;

    if (kind == GitHubActivityKind.commit && (sha == null || sha.isEmpty)) {
      throw const FormatException('Missing commit SHA.');
    }

    if (kind == GitHubActivityKind.pullRequest &&
        (number == null || number <= 0)) {
      throw const FormatException('Missing pull request number.');
    }

    return GitHubActivityItem(
      kind: kind,
      sha: sha,
      number: number,
      message: activity['message'] as String?,
      title: activity['title'] as String?,
      body: activity['body'] as String?,
      authorId: activity['authorId'] as int?,
      authorLogin: activity['authorLogin'] as String?,
      state: activity['state'] as String?,
      draft: activity['draft'] == true,
      headRef: activity['headRef'] as String?,
      baseRef: activity['baseRef'] as String?,
      headSha: activity['headSha'] as String?,
      mergeCommitSha: activity['mergeCommitSha'] as String?,
      commitDate: _parseDate(activity['commitDate']),
      authoredAt: _parseDate(activity['authoredAt']),
      createdAt: _parseDate(activity['createdAt']),
      updatedAt: _parseDate(activity['updatedAt']),
      closedAt: _parseDate(activity['closedAt']),
      mergedAt: _parseDate(activity['mergedAt']),
      url: activity['url'] as String?,
      files: List.unmodifiable(
        _parseObjects(activity['files'], GitHubChangedFile.fromJson),
      ),
      filesMayBeIncomplete: activity['filesMayBeIncomplete'] == true,
      commitShas: _parseStrings(activity['commitShas']),
      parents: _parseStrings(activity['parents']),
      commitsMayBeIncomplete: activity['commitsMayBeIncomplete'] == true,
      jira: List.unmodifiable(
        _parseObjects(json['jira'], GitHubJiraReference.fromJson),
      ),
      unresolvedJiraKeys: _parseStrings(json['unresolvedJiraKeys']),
      linkedAuthor: _parseActor(json['linkedAuthor']),
      linkedMergedBy: _parseActor(json['linkedMergedBy']),
    );
  }

  String get id => isCommit ? sha! : number.toString();

  bool get isCommit => kind == GitHubActivityKind.commit;

  bool get isMerged => mergedAt != null;

  String get shortSha {
    final value = sha ?? '';

    return value.length > 7 ? value.substring(0, 7) : value;
  }

  String get displayTitle {
    final value = isCommit ? message : title;

    if (value == null || value.trim().isEmpty) {
      return isCommit ? 'Commit $shortSha' : 'Pull request #$number';
    }

    return value.trim().split('\n').first;
  }

  String get statusLabel {
    if (isCommit) return 'Commit';
    if (isMerged) return 'Merged';
    if (state == 'closed') return 'Closed';
    if (draft) return 'Draft';
    if (state == 'open') return 'Open';

    return 'Unknown';
  }

  DateTime? get displayDate =>
      isCommit ? commitDate ?? authoredAt : updatedAt ?? createdAt;

  bool get hasJiraEvidence => jira.isNotEmpty || unresolvedJiraKeys.isNotEmpty;

  static DateTime? _parseDate(dynamic value) {
    return value is String ? DateTime.tryParse(value) : null;
  }

  static List<String> _parseStrings(dynamic value) {
    if (value == null) return const [];

    if (value is! List) {
      throw const FormatException('Invalid string list.');
    }

    return List<String>.unmodifiable(value.cast<String>());
  }

  static List<T> _parseObjects<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (value == null) return [];

    if (value is! List) {
      throw const FormatException('Invalid object list.');
    }

    return value
        .map((item) => parser(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static GitHubLinkedActor? _parseActor(dynamic value) {
    if (value == null) return null;

    return GitHubLinkedActor.fromJson(Map<String, dynamic>.from(value as Map));
  }
}

class GitHubActivityPage {
  final GitHubSyncCoverage source;
  final List<GitHubActivityItem> items;
  final int? nextOffset;

  const GitHubActivityPage({
    required this.source,
    required this.items,
    this.nextOffset,
  });

  factory GitHubActivityPage.fromJson(
    Map<String, dynamic> json,
    GitHubActivityKind kind,
  ) {
    final rawItems = json['items'];

    if (rawItems is! List) {
      throw const FormatException('Invalid GitHub activity response.');
    }

    return GitHubActivityPage(
      source: GitHubSyncCoverage.fromJson(
        Map<String, dynamic>.from(json['source'] as Map),
      ),
      items: List.unmodifiable(
        rawItems.map(
          (item) => GitHubActivityItem.fromJson(
            Map<String, dynamic>.from(item as Map),
            kind,
          ),
        ),
      ),
      nextOffset: json['nextOffset'] as int?,
    );
  }

  bool get hasMore => nextOffset != null;
}
