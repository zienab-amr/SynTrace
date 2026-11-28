import 'package:dio/dio.dart';

import 'package:syntrace/features/settings/data/repositories/github_repository.dart';

import 'models/project_api_model.dart';
import 'models/project_creation_request.dart';
import 'models/project_team_member.dart';

import 'projects_repository.dart';

class ProjectCreationService {
  final ProjectsRepository _projectsRepository;
  final GitHubRepository _integrationsRepository;

  ProjectCreationService({
    ProjectsRepository? projectsRepository,
    GitHubRepository? integrationsRepository,
  }) : _projectsRepository = projectsRepository ?? ProjectsRepository(),
       _integrationsRepository = integrationsRepository ?? GitHubRepository();

  Future<ProjectApiModel> createProject(ProjectCreationRequest request) async {
    if (!request.isValid) {
      throw ArgumentError('Invalid project configuration.');
    }

    final project = await _projectsRepository.createProject(
      clientId: request.clientId,
      name: request.name,
      description: request.description.isEmpty ? null : request.description,
    );

    if (project.id.trim().isEmpty) {
      throw const FormatException('Project creation could not be confirmed.');
    }

    return project;
  }

  Future<void> assignMember({
    required String projectId,
    required ProjectTeamMember member,
  }) {
    return _projectsRepository.addProjectMember(
      projectId: projectId,
      employeeId: member.employeeId,
      role: member.role.apiValue,
    );
  }

  Future<void> mapGitHub({
    required String projectId,
    required int repositoryId,
  }) async {
    final response = await _integrationsRepository.mapGitHubRepository(
      projectId: projectId,
      repositoryId: repositoryId,
    );

    final status = response.statusCode ?? 0;

    if (status < 200 || status >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }

  Future<void> mapJira({
    required String projectId,
    required String jiraProjectId,
  }) {
    return _projectsRepository.mapJiraProject(
      projectId: projectId,
      jiraProjectId: jiraProjectId,
    );
  }
}
