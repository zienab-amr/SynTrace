import 'package:dio/dio.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';

class IntegrationsRepository {
  final ApiClient _apiClient;

  IntegrationsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  Future<Response> checkJiraStatus() =>
      _apiClient.get(ApiEndpoints.jiraSyncStatus);

  Future<Response> connectJira({bool employee = false}) {
    return _apiClient.get(
      employee ? ApiEndpoints.jiraConnectEmployee : ApiEndpoints.jiraConnect,
      options: Options(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
  }

  Future<Response> disconnectJira() =>
      _apiClient.delete(ApiEndpoints.jiraDisconnect);

  Future<Response> fetchJiraCallback() =>
      _apiClient.get(ApiEndpoints.jiraCallback);

  Future<Response> fetchJiraPendingSites(String pendingId) => _apiClient.get(
    ApiEndpoints.jiraPendingSites,
    queryParameters: {'pendingId': pendingId},
  );

  Future<Response> completeJiraConnection(String pendingId, String cloudId) {
    return _apiClient.post(
      ApiEndpoints.jiraCompleteConnection,
      queryParameters: {'pendingId': pendingId, 'cloudId': cloudId},
      data: {'pendingId': pendingId, 'cloudId': cloudId},
    );
  }

  Future<Response> sendJiraWebhook(String connectionId, dynamic payload) {
    return _apiClient.post(
      ApiEndpoints.jiraWebhook(connectionId),
      data: payload,
    );
  }

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
      data: {'completionId': completionId, 'installationId': installationId},
    );
  }

  Future<Response> disconnectGitHubCompany() =>
      _apiClient.delete(ApiEndpoints.githubCompany);

  Future<Response> disconnectGitHubEmployee() =>
      _apiClient.delete(ApiEndpoints.githubEmployee);

  Future<Response> getGitHubRepositories() =>
      _apiClient.get(ApiEndpoints.githubRepositories);
}
