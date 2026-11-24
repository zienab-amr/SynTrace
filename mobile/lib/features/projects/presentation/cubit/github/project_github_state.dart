import 'package:equatable/equatable.dart';

import 'package:syntrace/features/settings/data/models/github_model.dart';

enum ProjectGitHubRequestStatus { initial, loading, success, failure }

enum ProjectGitHubAction { none, linking, syncing, unlinking }

class ProjectGitHubState extends Equatable {
  final ProjectGitHubRequestStatus status;
  final ProjectGitHubRequestStatus repositoriesStatus;

  final GitHubProjectStatus? integration;
  final GitHubSyncCoverage? coverage;

  final List<GitHubRepositoryOption> repositories;

  final ProjectGitHubAction action;

  final bool isRefreshing;

  final String? errorMessage;
  final String? repositoriesError;
  final String? coverageError;

  const ProjectGitHubState({
    this.status = ProjectGitHubRequestStatus.initial,
    this.repositoriesStatus = ProjectGitHubRequestStatus.initial,
    this.integration,
    this.coverage,
    this.repositories = const [],
    this.action = ProjectGitHubAction.none,
    this.isRefreshing = false,
    this.errorMessage,
    this.repositoriesError,
    this.coverageError,
  });

  // ═══════════════════════════════════════════
  // Computed Properties
  // ═══════════════════════════════════════════

  bool get isLoading => status == ProjectGitHubRequestStatus.loading;

  bool get isLoadingRepositories =>
      repositoriesStatus == ProjectGitHubRequestStatus.loading;

  bool get isMapped => integration?.isMapped ?? false;

  bool get isProcessing => integration?.isProcessing ?? false;

  bool get isBusy => action != ProjectGitHubAction.none;

  bool get isLinking => action == ProjectGitHubAction.linking;

  bool get isSyncing => action == ProjectGitHubAction.syncing;

  bool get isUnlinking => action == ProjectGitHubAction.unlinking;

  bool get hasCoverage => coverage != null;

  bool get canSelectRepository =>
      !isBusy &&
      !isLoading &&
      !isRefreshing &&
      (integration?.canSelectRepository ?? false);

  bool get canRequestSync =>
      !isBusy && !isRefreshing && (integration?.canRequestSync ?? false);

  bool get canUnlink =>
      !isBusy && !isRefreshing && (integration?.canUnlink ?? false);

  // ═══════════════════════════════════════════
  // Copy With
  // ═══════════════════════════════════════════

  ProjectGitHubState copyWith({
    ProjectGitHubRequestStatus? status,
    ProjectGitHubRequestStatus? repositoriesStatus,
    GitHubProjectStatus? integration,
    GitHubSyncCoverage? coverage,
    List<GitHubRepositoryOption>? repositories,
    ProjectGitHubAction? action,
    bool? isRefreshing,
    String? errorMessage,
    String? repositoriesError,
    String? coverageError,
    bool clearIntegration = false,
    bool clearCoverage = false,
    bool clearError = false,
    bool clearRepositoriesError = false,
    bool clearCoverageError = false,
  }) {
    return ProjectGitHubState(
      status: status ?? this.status,

      repositoriesStatus: repositoriesStatus ?? this.repositoriesStatus,

      integration: clearIntegration ? null : integration ?? this.integration,

      coverage: clearCoverage ? null : coverage ?? this.coverage,

      repositories: repositories ?? this.repositories,

      action: action ?? this.action,

      isRefreshing: isRefreshing ?? this.isRefreshing,

      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,

      repositoriesError: clearRepositoriesError
          ? null
          : repositoriesError ?? this.repositoriesError,

      coverageError: clearCoverageError
          ? null
          : coverageError ?? this.coverageError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    repositoriesStatus,
    integration,
    coverage,
    repositories,
    action,
    isRefreshing,
    errorMessage,
    repositoriesError,
    coverageError,
  ];
}
