import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'models/role_model.dart';

class RolesRepository {
  final ApiClient _apiClient = ApiClient.instance;

  Future<ApiResponse<dynamic>> createRole(
    String name,
    String description,
  ) async {
    return await _apiClient.safeRequest<dynamic>(
      request: () => _apiClient.post(
        ApiEndpoints.createRole,
        data: {'name': name, 'description': description},
      ),
      fromData: (data) => data,
    );
  }

  Future<ApiResponse<dynamic>> updateRole(
    String id,
    String name,
    String description,
  ) async {
    return await _apiClient.safeRequest<dynamic>(
      request: () => _apiClient.put(
        ApiEndpoints.updateRole,
        data: {'id': id, 'name': name, 'description': description},
      ),
      fromData: (data) => data,
    );
  }

  Future<ApiResponse<dynamic>> deleteRole(String id) async {
    return await _apiClient.safeRequest<dynamic>(
      request: () =>
          _apiClient.delete(ApiEndpoints.deleteRole, data: {'id': id}),
      fromData: (data) => data,
    );
  }

  Future<ApiResponse<List<RoleModel>>> getAllRoles() async {
    return await _apiClient.safeRequest<List<RoleModel>>(
      request: () => _apiClient.get(ApiEndpoints.allRoles),
      fromData: (data) => (data as List)
          .map((e) => RoleModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
