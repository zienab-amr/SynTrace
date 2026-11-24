import 'package:dio/dio.dart';

import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';

import 'models/project_api_model.dart';

class ProjectsRepository {
  final ApiClient _apiClient;

  ProjectsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  static const int _pageSize = 100;

  // ═══════════════════════════════════════════
  // Get All Projects
  // ═══════════════════════════════════════════

  Future<List<ProjectApiModel>> getProjects({CancelToken? cancelToken}) async {
    final projects = <ProjectApiModel>[];
    var offset = 0;

    while (true) {
      final response = await _apiClient.get(
        ApiEndpoints.projects,
        queryParameters: {'offset': offset},
        cancelToken: cancelToken,
      );

      _ensureSuccess(response);

      final page = _asList(
        response.data,
      ).map((item) => ProjectApiModel.fromJson(_asMap(item))).toList();

      projects.addAll(page);

      if (page.length < _pageSize) {
        break;
      }

      offset += page.length;
    }

    return List.unmodifiable(projects);
  }

  // ═══════════════════════════════════════════
  // Get Project Details
  // ═══════════════════════════════════════════

  Future<ProjectApiModel> getProjectById(
    String projectId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.projectById(projectId),
      cancelToken: cancelToken,
    );

    _ensureSuccess(response);

    final project = ProjectApiModel.fromJson(_asMap(response.data));

    if (project.id != projectId) {
      throw const FormatException('Project ID does not match the request.');
    }

    return project;
  }

  // ═══════════════════════════════════════════
  // Create Project
  // ═══════════════════════════════════════════

  Future<ProjectApiModel> createProject({
    required String clientId,
    required String name,
    String? description,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.projects,
      data: {
        'clientId': clientId,
        'name': name.trim(),
        'description': description?.trim(),
      },
    );

    _ensureSuccess(response);

    return ProjectApiModel.fromJson(_asMap(response.data));
  }

  // ═══════════════════════════════════════════
  // Update Project
  // ═══════════════════════════════════════════

  Future<void> updateProject({
    required String projectId,
    required String name,
    required ProjectApiStatus status,
    String? description,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.projectById(projectId),
      data: {
        'name': name.trim(),
        'description': description?.trim(),
        'status': status.apiValue,
      },
    );

    _ensureSuccess(response);
  }

  // ═══════════════════════════════════════════
  // Jira Project Options
  // ═══════════════════════════════════════════

  Future<List<JiraProjectOption>> getJiraProjectOptions({
    CancelToken? cancelToken,
  }) async {
    final options = <JiraProjectOption>[];
    var offset = 0;

    while (true) {
      final response = await _apiClient.get(
        ApiEndpoints.projectJiraOptions,
        queryParameters: {'offset': offset},
        cancelToken: cancelToken,
      );

      _ensureSuccess(response);

      final page = _asList(
        response.data,
      ).map((item) => JiraProjectOption.fromJson(_asMap(item))).toList();

      options.addAll(page);

      if (page.length < _pageSize) {
        break;
      }

      offset += page.length;
    }

    return List.unmodifiable(options);
  }

  // ═══════════════════════════════════════════
  // Map / Unmap Jira Project
  // ═══════════════════════════════════════════

  Future<void> mapJiraProject({
    required String projectId,
    required String? jiraProjectId,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.projectJira(projectId),
      data: {'jiraProjectId': jiraProjectId},
    );

    _ensureSuccess(response);
  }

  // ═══════════════════════════════════════════
  // Add Project Member
  // ═══════════════════════════════════════════

  Future<void> addProjectMember({
    required String projectId,
    required String employeeId,
    String role = 'Member',
  }) async {
    const allowedRoles = ['Member', 'ProductOwner', 'ProjectManager'];

    if (!allowedRoles.contains(role)) {
      throw ArgumentError('Invalid project member role.');
    }

    final response = await _apiClient.put(
      ApiEndpoints.projectMember(projectId, employeeId),
      queryParameters: {'role': role},
    );

    _ensureSuccess(response);
  }

  // ═══════════════════════════════════════════
  // Remove Project Member
  // ═══════════════════════════════════════════

  Future<void> removeProjectMember({
    required String projectId,
    required String employeeId,
  }) async {
    final response = await _apiClient.delete(
      ApiEndpoints.projectMember(projectId, employeeId),
    );

    _ensureSuccess(response);
  }

  // ═══════════════════════════════════════════
  // Response Helpers
  // ═══════════════════════════════════════════

  void _ensureSuccess(Response response) {
    final status = response.statusCode ?? 0;

    if (status >= 200 && status < 300) {
      return;
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const FormatException('Expected a JSON object.');
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }

    throw const FormatException('Expected a JSON array.');
  }
}
