import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/network/api_response.dart';

class IntegrationsRepository {
  final ApiClient _apiClient = ApiClient.instance;

  Future<ApiResponse<dynamic>> checkJiraStatus() async {
    return await _apiClient.safeRequest<dynamic>(
      request: () => _apiClient.get(ApiEndpoints.jiraSyncStatus),
      fromData: (data) => data,
    );
  }

  Future<ApiResponse<dynamic>> connectJira() async {
    return await _apiClient.safeRequest<dynamic>(
      request: () => _apiClient.get(ApiEndpoints.jiraConnect),
      fromData: (data) => data,
    );
  }

  Future<ApiResponse<dynamic>> disconnectJira() async {
    return await _apiClient.safeRequest<dynamic>(
      request: () => _apiClient.delete(ApiEndpoints.jiraDisconnect),
      fromData: (data) => data,
    );
  }

  
  Future<ApiResponse<dynamic>> fetchJiraCallback() async {
    return await _apiClient.safeRequest<dynamic>(
      request: () => _apiClient.get(ApiEndpoints.jiraCallback),
      fromData: (data) => data,
    );
  }

  Future<ApiResponse<dynamic>> sendJiraWebhook(String connectionId, dynamic payload) async {
    return await _apiClient.safeRequest<dynamic>(
      request: () => _apiClient.post(
        ApiEndpoints.jiraWebhook(connectionId),
        data: payload,
      ),
      fromData: (data) => data,
    );
  }
}