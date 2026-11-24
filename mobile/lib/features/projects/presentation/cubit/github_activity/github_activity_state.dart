import 'package:equatable/equatable.dart';

import '../../../data/models/github_activity_model.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';

enum GitHubActivityStatus {
  initial,
  loading,
  success,
  failure,
  unavailable,
  forbidden,
}

class GitHubActivityState extends Equatable {
  final GitHubActivityStatus status;

  final List<GitHubActivityItem> items;
  final GitHubSyncCoverage? source;

  final int? nextOffset;

  final bool isRefreshing;
  final bool isLoadingMore;

  final String? errorMessage;
  final String? paginationError;

  const GitHubActivityState({
    this.status = GitHubActivityStatus.initial,
    this.items = const [],
    this.source,
    this.nextOffset,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.paginationError,
  });

  bool get hasMore => nextOffset != null;

  bool get isEmpty => status == GitHubActivityStatus.success && items.isEmpty;

  bool get isBusy =>
      status == GitHubActivityStatus.loading || isRefreshing || isLoadingMore;

  bool get canLoadMore =>
      status == GitHubActivityStatus.success && hasMore && !isBusy;

  GitHubActivityState copyWith({
    GitHubActivityStatus? status,
    List<GitHubActivityItem>? items,
    GitHubSyncCoverage? source,
    int? nextOffset,
    bool? isRefreshing,
    bool? isLoadingMore,
    String? errorMessage,
    String? paginationError,
    bool clearSource = false,
    bool clearNextOffset = false,
    bool clearError = false,
    bool clearPaginationError = false,
  }) {
    return GitHubActivityState(
      status: status ?? this.status,
      items: items ?? this.items,
      source: clearSource ? null : source ?? this.source,
      nextOffset: clearNextOffset ? null : nextOffset ?? this.nextOffset,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      paginationError: clearPaginationError
          ? null
          : paginationError ?? this.paginationError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    source,
    nextOffset,
    isRefreshing,
    isLoadingMore,
    errorMessage,
    paginationError,
  ];
}
