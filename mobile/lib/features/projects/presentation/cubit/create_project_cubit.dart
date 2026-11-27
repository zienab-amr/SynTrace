import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/cache/cache_session.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import '../../data/models/project_client_model.dart';
import '../../data/models/project_api_model.dart';
import '../../data/models/project_creation_request.dart';
import '../../data/models/project_team_member.dart';

import '../../data/project_clients_repository.dart';
import '../../data/project_creation_service.dart';
import '../../data/projects_repository.dart';

import 'create_project_state.dart';

class CreateProjectCubit extends Cubit<CreateProjectState> {
  final ProjectClientsRepository _clientsRepository;
  final ProjectCreationService _creationService;

  final UserModel? _owner = CurrentUserService.instance.user;
  final int _generation = CacheSession.instance.generation;

  CancelToken? _clientsToken;

  CreateProjectCubit({
    ProjectsRepository? projectsRepository,
    ProjectClientsRepository? clientsRepository,
    ProjectCreationService? creationService,
  }) : _clientsRepository = clientsRepository ?? ProjectClientsRepository(),
       _creationService =
           creationService ??
           ProjectCreationService(projectsRepository: projectsRepository),
       super(const CreateProjectState());

  bool get _canCreate {
    final current = CurrentUserService.instance.user;

    return !isClosed &&
        CacheSession.instance.generation == _generation &&
        _owner != null &&
        _owner.tenantId?.isNotEmpty == true &&
        current?.id == _owner.id &&
        current?.tenantId == _owner.tenantId &&
        current?.role == UserRole.admin;
  }

  bool get _isLocked =>
      isClosed ||
      state.isLoading ||
      state.isSubmitting ||
      state.creationUncertain ||
      state.hasCreatedProject;

  Future<void> loadClients() async {
    if (_isLocked) return;

    if (!_canCreate) {
      emit(
        const CreateProjectState(
          status: CreateProjectStatus.failure,
          errorMessage: 'Permission denied.',
        ),
      );

      return;
    }

    _clientsToken = CancelToken();

    final previousClients = state.clients;

    emit(
      CreateProjectState(
        status: CreateProjectStatus.loading,
        clients: previousClients,
      ),
    );

    try {
      final clients = await _clientsRepository.getClients(
        cancelToken: _clientsToken,
      );

      if (!_canCreate) return;

      emit(
        CreateProjectState(status: CreateProjectStatus.ready, clients: clients),
      );
    } catch (_) {
      if (!_canCreate) return;

      emit(
        CreateProjectState(
          status: CreateProjectStatus.failure,
          errorMessage: 'Unable to load clients. Please try again.',
        ),
      );
    } finally {
      _clientsToken = null;
    }
  }

  void addCreatedClient(ProjectClientModel client) {
    if (_isLocked || !_canCreate) return;

    final clients = [
      ...state.clients.where((item) => item.id != client.id),
      client,
    ];

    clients.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    emit(
      CreateProjectState(
        status: CreateProjectStatus.ready,
        clients: List.unmodifiable(clients),
      ),
    );
  }

  Future<void> createProject({
    required String name,
    required String clientId,
    required String description,
    List<ProjectTeamMember> members = const [],
    int? githubRepositoryId,
    String? jiraProjectId,
  }) async {
    if (_isLocked || !_canCreate) return;

    final request = ProjectCreationRequest(
      name: name,
      clientId: clientId,
      description: description,
      members: members,
      githubRepositoryId: githubRepositoryId,
      jiraProjectId: jiraProjectId,
    );

    final clients = state.clients;

    final validClient = clients.any((client) => client.id == request.clientId);

    if (!request.isValid || !validClient) {
      emit(
        CreateProjectState(
          status: CreateProjectStatus.failure,
          clients: clients,
          errorMessage: 'Review the project configuration before continuing.',
        ),
      );

      return;
    }

    emit(
      CreateProjectState(
        status: CreateProjectStatus.submitting,
        clients: clients,
      ),
    );

    late final ProjectApiModel project;

    // Phase 1: Create the project exactly once
    // during this submission.

    try {
      project = await _creationService.createProject(request);
    } catch (error) {
      if (!_canCreate) return;

      final code = error is DioException ? error.response?.statusCode : null;

      final rejected = const [400, 401, 403, 404, 422].contains(code);

      emit(
        CreateProjectState(
          status: CreateProjectStatus.failure,
          clients: clients,
          creationUncertain: !rejected,
          errorMessage: rejected
              ? _errorMessage(error)
              : 'Project creation could not be confirmed. '
                    'Check the projects list before trying again.',
        ),
      );

      return;
    }

    if (!_canCreate) return;

    final completedMembers = <ProjectTeamMember>[];
    final failures = <String>[];

    bool githubMapped = false;
    bool jiraMapped = false;

    void publishProgress() {
      if (!_canCreate) return;

      emit(
        CreateProjectState(
          status: CreateProjectStatus.submitting,
          clients: clients,
          createdProject: project,
          completedMembers: List.unmodifiable(completedMembers),
          githubMapped: githubMapped,
          jiraMapped: jiraMapped,
        ),
      );
    }

    // Preserve the project ID before configuring
    // team members and integrations.

    publishProgress();

    // Phase 2: Assign team members.

    for (final member in request.members) {
      if (!_canCreate) return;

      try {
        await _creationService.assignMember(
          projectId: project.id,
          member: member,
        );

        if (!_canCreate) return;

        completedMembers.add(member);
      } catch (_) {
        if (!_canCreate) return;

        failures.add('Assignment not confirmed: ${member.name}');
      }

      publishProgress();
    }

    // Phase 3: Map GitHub repository.

    if (request.githubRepositoryId != null) {
      if (!_canCreate) return;

      try {
        await _creationService.mapGitHub(
          projectId: project.id,
          repositoryId: request.githubRepositoryId!,
        );

        if (!_canCreate) return;

        githubMapped = true;
      } catch (_) {
        if (!_canCreate) return;

        failures.add('GitHub mapping could not be confirmed.');
      }

      publishProgress();
    }

    // Phase 4: Map Jira project.

    if (request.jiraProjectId != null) {
      if (!_canCreate) return;

      try {
        await _creationService.mapJira(
          projectId: project.id,
          jiraProjectId: request.jiraProjectId!,
        );

        if (!_canCreate) return;

        jiraMapped = true;
      } catch (_) {
        if (!_canCreate) return;

        failures.add('Jira mapping could not be confirmed.');
      }

      publishProgress();
    }

    if (!_canCreate) return;

    // Phase 5: Publish the actual result.

    emit(
      CreateProjectState(
        status: failures.isEmpty
            ? CreateProjectStatus.success
            : CreateProjectStatus.partialSuccess,
        clients: clients,
        createdProject: project,
        completedMembers: List.unmodifiable(completedMembers),
        githubMapped: githubMapped,
        jiraMapped: jiraMapped,
        errorMessage: failures.isEmpty
            ? null
            : 'The project was created, but some setup '
                  'operations could not be confirmed.\n\n'
                  '${failures.join('\n')}\n\n'
                  'Open the project and verify its configuration.',
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 400:
        case 422:
          return 'Check the project information.';

        case 401:
          return 'Your session has expired.';

        case 403:
          return 'You do not have permission.';

        case 404:
          return 'The selected resource is unavailable.';
      }
    }

    return 'Unable to create the project.';
  }

  @override
  Future<void> close() {
    _clientsToken?.cancel();

    return super.close();
  }
}
