import 'package:dio/dio.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/cache/cache_service.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/sync/services/connectivity_service.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'models/role_model.dart';

class RolesRepository {
  final ApiClient _apiClient = ApiClient.instance;

  Future<ApiResponse<dynamic>> _mutate(
    Future<Response<dynamic>> Function(Options options) request,
  ) async {
    try {
      final scope = CacheScope.fromCurrentUser();
      if (scope == null || CurrentUserService.instance.user?.isAdmin != true) {
        return ApiResponse.failure(message: 'Admin access required.');
      }
      final guard = CacheSessionGuard.capture(scope);
      if (!await ConnectivityService().hasNetworkConnection()) {
        return ApiResponse.failure(message: 'Connection required.');
      }
      guard.ensureValid();
      final response = await request(_options(guard));
      guard.ensureValid();
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return ApiResponse.failure(
          message: 'Role operation failed.',
          statusCode: status,
        );
      }
      if (CacheService.instance.isInitialized) {
        await CacheService.instance.repository.invalidateType(
          scope: scope,
          resourceType: 'employees',
        );
      }
      guard.ensureValid();
      return ApiResponse.success(
        data: true,
        message: 'Role operation completed successfully.',
      );
    } on DioException catch (error) {
      return ApiResponse.failure(
        message: _errorMessage(error),
        statusCode: error.response?.statusCode ?? 0,
      );
    } catch (_) {
      return ApiResponse.failure(
        message: 'Request failed. Refresh before retrying.',
      );
    }
  }

  Options _options(CacheSessionGuard guard) => Options(
    extra: {'auth_generation': guard.generation, 'allow_retry': false},
  );

  String _errorMessage(DioException error) {
    switch (error.response?.statusCode) {
      case 400:
        return 'Invalid role information.';
      case 401:
        return 'Your session has expired.';
      case 403:
        return 'Admin access required.';
      case 404:
        return 'Role not found. Refresh the list.';
      case 409:
        return 'Role conflict: duplicate name, reserved role, or assigned employees.';
      default:
        return 'Request not confirmed. Refresh before retrying.';
    }
  }

  bool _validName(String name) =>
      name.trim().isNotEmpty && name.trim().length <= 256;
  bool _validId(String id) => id.trim().isNotEmpty && id.trim().length <= 256;

  Future<ApiResponse<dynamic>> createRole(
    String name,
    String description,
  ) async {
    if (!_validName(name)) {
      return ApiResponse.failure(
        message: 'Enter a role name (1–256 characters).',
      );
    }
    return _mutate(
      (options) => _apiClient.post(
        ApiEndpoints.createRole,
        data: {'role': name.trim()},
        options: options,
      ),
    );
  }

  Future<ApiResponse<dynamic>> updateRole(
    String id,
    String name,
    String description,
  ) async {
    if (!_validId(id) || !_validName(name)) {
      return ApiResponse.failure(message: 'Invalid role information.');
    }
    return _mutate(
      (options) => _apiClient.put(
        ApiEndpoints.updateRole,
        data: {'roleId': id.trim(), 'newRoleName': name.trim()},
        options: options,
      ),
    );
  }

  Future<ApiResponse<dynamic>> deleteRole(String id) async {
    if (!_validId(id)) {
      return ApiResponse.failure(message: 'Invalid role ID.');
    }
    return _mutate(
      (options) => _apiClient.delete(
        ApiEndpoints.deleteRole,
        data: {'roleId': id.trim()},
        options: options,
      ),
    );
  }

  Future<ApiResponse<List<RoleModel>>> getAllRoles() async {
    try {
      final scope = CacheScope.fromCurrentUser();
      if (scope == null || CurrentUserService.instance.user?.isAdmin != true) {
        return ApiResponse.failure(message: 'Admin access required.');
      }
      final guard = CacheSessionGuard.capture(scope);
      guard.ensureValid();
      final response = await _apiClient.get(
        ApiEndpoints.allRoles,
        options: _options(guard),
      );
      guard.ensureValid();
      if (response.statusCode != 200 || response.data is! List) {
        return ApiResponse.failure(message: 'Unable to load roles.');
      }
      final roles = (response.data as List)
          .map((e) => RoleModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final ids = <String>{};
      if (roles.any(
        (r) => r.id.trim().isEmpty || r.name.trim().isEmpty || !ids.add(r.id),
      )) {
        return ApiResponse.failure(message: 'Invalid role response.');
      }
      return ApiResponse.success(data: List<RoleModel>.unmodifiable(roles));
    } on DioException catch (error) {
      return ApiResponse.failure(message: _errorMessage(error));
    } catch (_) {
      return ApiResponse.failure(message: 'Unable to load roles.');
    }
  }
}
