import 'package:equatable/equatable.dart';

import '../../../data/models/project_team_member.dart';

enum ProjectMembersStatus { initial, loading, success, failure }

class ProjectMembersState extends Equatable {
  final ProjectMembersStatus status;
  final List<ProjectTeamMember> members;

  final bool isMutating;
  final bool isRefreshing;
  final bool isUnavailable;
  final bool isFromCache;

  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const ProjectMembersState({
    this.status = ProjectMembersStatus.initial,
    this.members = const [],
    this.isMutating = false,
    this.isRefreshing = false,
    this.isUnavailable = false,
    this.isFromCache = false,
    this.lastSyncedAt,
    this.errorMessage,
  });

  bool get isLoading => status == ProjectMembersStatus.loading;

  bool get hasError => status == ProjectMembersStatus.failure;

  bool get isBusy => isLoading || isMutating || isRefreshing;

  bool get hasLoaded => status == ProjectMembersStatus.success;

  bool get canModify => hasLoaded && !isFromCache && !isBusy && !isUnavailable;

  ProjectMembersState copyWith({
    ProjectMembersStatus? status,
    List<ProjectTeamMember>? members,
    bool? isMutating,
    bool? isRefreshing,
    bool? isUnavailable,
    bool? isFromCache,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProjectMembersState(
      status: status ?? this.status,
      members: members ?? this.members,
      isMutating: isMutating ?? this.isMutating,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isUnavailable: isUnavailable ?? this.isUnavailable,
      isFromCache: isFromCache ?? this.isFromCache,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    members,
    isMutating,
    isRefreshing,
    isUnavailable,
    isFromCache,
    lastSyncedAt,
    errorMessage,
  ];
}
