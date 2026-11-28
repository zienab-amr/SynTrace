import 'package:dio/dio.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';

class GitHubRepository {
  final ApiClient _apiClient;

  GitHubRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  Future<Response> startGitHubCompanyConnection({
    bool authorizeExisting = false,
  }) {
    return _apiClient.get(
      authorizeExisting
          ? ApiEndpoints.githubAuthorizeCompany
          : ApiEndpoints.githubConnect,
    );
  }

  Future<Response> startGitHubEmployeeConnection() {
    return _apiClient.get(ApiEndpoints.githubConnectEmployee);
  }

  Future<Response> getGitHubCompanyStatus() =>
      _apiClient.get(ApiEndpoints.githubCompany);

  Future<Response> getGitHubEmployeeStatus() =>
      _apiClient.get(ApiEndpoints.githubEmployee);

  Future<Response> getGitHubPendingConnection(String completionId) {
    return _apiClient.get(
      ApiEndpoints.githubPending,
      queryParameters: {'completionId': completionId},
    );
  }

  Future<Response> completeGitHubConnection(
    String completionId,
    int? installationId,
  ) {
    return _apiClient.post(
      ApiEndpoints.githubComplete,
      options: Options(extra: {'allow_retry': false}),
      data: {'completionId': completionId, 'installationId': installationId},
    );
  }

  Future<Response> disconnectGitHubCompany() => _apiClient.delete(
    ApiEndpoints.githubCompany,
    options: Options(extra: {'allow_retry': false}),
  );

  Future<Response> disconnectGitHubEmployee() => _apiClient.delete(
    ApiEndpoints.githubEmployee,
    options: Options(extra: {'allow_retry': false}),
  );

  Future<Response> getGitHubRepositories() =>
      _apiClient.get(ApiEndpoints.githubRepositories);

  // ═══════════════════════════════════════════
  // GitHub Project Integration
  // ═══════════════════════════════════════════

  Future<Response> getGitHubProjectStatus(String projectId) {
    return _apiClient.get(ApiEndpoints.githubProject(projectId));
  }

  Future<Response> mapGitHubRepository({
    required String projectId,
    required int repositoryId,
  }) {
    return _apiClient.put(
      ApiEndpoints.githubProjectRepository(projectId),
      options: Options(extra: {'allow_retry': false}),
      data: {'repositoryId': repositoryId},
    );
  }

  Future<Response> unmapGitHubRepository(String projectId) {
    return _apiClient.delete(
      ApiEndpoints.githubProjectRepository(projectId),
      options: Options(extra: {'allow_retry': false}),
    );
  }

  Future<Response> requestGitHubProjectSync(String projectId) {
    return _apiClient.post(
      ApiEndpoints.githubProjectSync(projectId),
      options: Options(extra: {'allow_retry': false}),
    );
  }

  Future<Response> getGitHubProjectActivity(
    String projectId, {
    String kind = 'commit',
    int offset = 0,
    CancelToken? cancelToken,
  }) {
    return _apiClient.get(
      ApiEndpoints.githubProjectActivity(projectId),
      queryParameters: {'kind': kind, 'offset': offset},
      cancelToken: cancelToken,
    );
  }
}
