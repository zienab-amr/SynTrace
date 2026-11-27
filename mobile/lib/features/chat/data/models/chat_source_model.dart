import 'package:equatable/equatable.dart';

enum ChatSourceType {
  jira,
  githubCommit,
  githubPullRequest,
  githubFile,
  githubRepository,
  unknown,
}

class ChatSourceModel extends Equatable {
  final String key;
  final String url;

  const ChatSourceModel({required this.key, required this.url});

  factory ChatSourceModel.fromJson(Map<String, dynamic> json) {
    return ChatSourceModel(
      key: json['key'] is String ? (json['key'] as String).trim() : '',
      url: json['url'] is String ? (json['url'] as String).trim() : '',
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'url': url};

  static List<ChatSourceModel> parseList(dynamic raw) {
    if (raw is! List) return const [];

    final sources = <ChatSourceModel>{};

    for (final item in raw) {
      if (item is! Map) continue;

      final source = ChatSourceModel.fromJson({
        'key': item['key'],
        'url': item['url'],
      });

      if (source.key.isEmpty && source.url.isEmpty) {
        continue;
      }

      sources.add(source);
    }

    return List.unmodifiable(sources);
  }

  Uri? get safeUri {
    final uri = Uri.tryParse(url);

    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasQuery) {
      return null;
    }

    return uri;
  }

  ChatSourceType get type {
    final uri = safeUri;

    if (uri == null) return ChatSourceType.unknown;

    final segments = uri.pathSegments;

    if (uri.host.endsWith('.atlassian.net') &&
        segments.length == 2 &&
        segments.first == 'browse') {
      return ChatSourceType.jira;
    }

    if (uri.host != 'github.com' ||
        segments.length < 2 ||
        segments.any(
          (segment) =>
              segment.isEmpty ||
              segment == '.' ||
              segment == '..' ||
              segment.contains('/') ||
              segment.contains('\\'),
        )) {
      return ChatSourceType.unknown;
    }

    if (segments.length == 2) {
      return ChatSourceType.githubRepository;
    }

    if (segments.length == 4 &&
        segments[2] == 'commit' &&
        _isCommitSha(segments[3])) {
      return ChatSourceType.githubCommit;
    }

    if (segments.length == 4 &&
        segments[2] == 'pull' &&
        (int.tryParse(segments[3]) ?? 0) > 0) {
      return ChatSourceType.githubPullRequest;
    }

    if (segments.length >= 5 && segments[2] == 'blob') {
      return ChatSourceType.githubFile;
    }

    return ChatSourceType.unknown;
  }

  bool get isGitHub =>
      type == ChatSourceType.githubCommit ||
      type == ChatSourceType.githubPullRequest ||
      type == ChatSourceType.githubFile ||
      type == ChatSourceType.githubRepository;

  bool get isAvailable => safeUri != null && type != ChatSourceType.unknown;

  String? get repository {
    if (!isGitHub) return null;

    final segments = safeUri!.pathSegments;

    return '${segments[0]}/${segments[1]}';
  }

  String? get revision {
    if (type != ChatSourceType.githubCommit &&
        type != ChatSourceType.githubFile) {
      return null;
    }

    return safeUri!.pathSegments[3];
  }

  String? get commitSha {
    final value = revision;

    if (value == null || !_isCommitSha(value)) {
      return null;
    }

    return value;
  }

  String? get shortSha {
    final sha = commitSha;

    if (sha == null) return null;

    return sha.length > 7 ? sha.substring(0, 7) : sha;
  }

  int? get pullRequestNumber {
    if (type != ChatSourceType.githubPullRequest) {
      return null;
    }

    return int.tryParse(safeUri!.pathSegments[3]);
  }

  String? get filePath {
    if (type != ChatSourceType.githubFile || commitSha == null) {
      return null;
    }

    return safeUri!.pathSegments.skip(4).join('/');
  }

  RegExpMatch? get _lineMatch {
    if (type != ChatSourceType.githubFile) {
      return null;
    }

    return RegExp(
      r'^L([1-9][0-9]*)(?:-L([1-9][0-9]*))?$',
    ).firstMatch(safeUri!.fragment);
  }

  int? get startLine {
    final match = _lineMatch;

    if (match == null) return null;

    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2) ?? match.group(1)!);

    if (start == null || end == null || end < start) {
      return null;
    }

    return start;
  }

  int? get endLine {
    if (startLine == null) return null;

    final match = _lineMatch!;

    return int.tryParse(match.group(2) ?? match.group(1)!);
  }

  bool get hasLineRange => startLine != null && endLine != null;

  bool get isPreciseCodeReference =>
      type == ChatSourceType.githubFile &&
      commitSha?.length == 40 &&
      filePath != null &&
      hasLineRange;

  String get typeLabel {
    switch (type) {
      case ChatSourceType.jira:
        return 'Jira Issue';

      case ChatSourceType.githubCommit:
        return 'GitHub Commit';

      case ChatSourceType.githubPullRequest:
        return 'GitHub Pull Request';

      case ChatSourceType.githubFile:
        return 'GitHub Source File';

      case ChatSourceType.githubRepository:
        return 'GitHub Repository';

      case ChatSourceType.unknown:
        return 'Unavailable Source';
    }
  }

  String get displayTitle {
    switch (type) {
      case ChatSourceType.githubCommit:
        return 'Commit ${shortSha ?? ''}'.trim();

      case ChatSourceType.githubPullRequest:
        return 'Pull Request #$pullRequestNumber';

      case ChatSourceType.githubFile:
        return filePath ?? (key.isNotEmpty ? key : 'Source file');

      case ChatSourceType.githubRepository:
        return repository ?? 'Repository';

      case ChatSourceType.jira:
        return key.isNotEmpty ? key : safeUri!.pathSegments.last;

      case ChatSourceType.unknown:
        return 'Source unavailable';
    }
  }

  static bool _isCommitSha(String value) {
    return RegExp(r'^[a-fA-F0-9]{7,40}$').hasMatch(value);
  }

  @override
  List<Object?> get props => [key, url];
}
