import 'package:dio/dio.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';

class JiraRepository {
  final ApiClient _apiClient;

  JiraRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  Future<Response> checkJiraStatus() =>
      _apiClient.get(ApiEndpoints.jiraSyncStatus);

  Future<Response> getEmployeeIdentity() =>
      _apiClient.get(ApiEndpoints.myIntegrationIdentities);

  Future<Response> connectJira({bool employee = false}) {
    return _apiClient.get(
      employee ? ApiEndpoints.jiraConnectEmployee : ApiEndpoints.jiraConnect,
      options: Options(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
  }

  Future<Response> disconnectJira() => _apiClient.delete(
    ApiEndpoints.jiraDisconnect,
    options: Options(extra: {'allow_retry': false}),
  );

  Future<Response> fetchJiraPendingSites(String pendingId) => _apiClient.get(
    ApiEndpoints.jiraPendingSites,
    queryParameters: {'pendingId': pendingId},
  );

  Future<Response> completeJiraConnection(String pendingId, String cloudId) {
    return _apiClient.post(
      ApiEndpoints.jiraCompleteConnection,
      queryParameters: {'pendingId': pendingId, 'cloudId': cloudId},
      options: Options(extra: {'allow_retry': false}),
      data: {'pendingId': pendingId, 'cloudId': cloudId},
    );
  }
}
