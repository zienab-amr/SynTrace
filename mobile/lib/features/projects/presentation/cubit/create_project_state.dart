import 'package:equatable/equatable.dart';

import '../../data/models/project_client_model.dart';
import '../../data/models/project_api_model.dart';
import '../../data/models/project_team_member.dart';

enum CreateProjectStatus {
  initial,
  loading,
  ready,
  submitting,
  partialSuccess,
  success,
  failure,
}

class CreateProjectState extends Equatable {
  final CreateProjectStatus status;
  final List<ProjectClientModel> clients;
  final ProjectApiModel? createdProject;
  final String? errorMessage;
  final bool creationUncertain;

  final List<ProjectTeamMember> completedMembers;
  final bool githubMapped;
  final bool jiraMapped;

  const CreateProjectState({
    this.status = CreateProjectStatus.initial,
    this.clients = const [],
    this.createdProject,
    this.errorMessage,
    this.creationUncertain = false,
    this.completedMembers = const [],
    this.githubMapped = false,
    this.jiraMapped = false,
  });

  bool get isLoading => status == CreateProjectStatus.loading;

  bool get isSubmitting => status == CreateProjectStatus.submitting;

  bool get isPartialSuccess => status == CreateProjectStatus.partialSuccess;

  bool get hasCreatedProject => createdProject != null;

  @override
  List<Object?> get props => [
    status,
    clients,
    createdProject,
    errorMessage,
    creationUncertain,
    completedMembers,
    githubMapped,
    jiraMapped,
  ];
}
