import 'package:equatable/equatable.dart';

import '../../../data/models/project_api_model.dart';

class ProjectDetailsState extends Equatable {
  final ProjectApiModel? project;
  final bool isLoading;
  final bool isRefreshing;
  final bool isFromCache;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const ProjectDetailsState({
    this.project,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isFromCache = false,
    this.lastSyncedAt,
    this.errorMessage,
  });

  bool get hasData => project != null;

  @override
  List<Object?> get props => [
    project,
    isLoading,
    isRefreshing,
    isFromCache,
    lastSyncedAt,
    errorMessage,
  ];
}
