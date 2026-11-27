import 'package:dio/dio.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/sync/services/connectivity_service.dart';
import 'package:syntrace/core/sync/services/sync_runtime.dart';
import 'package:syntrace/core/cache/cache_service.dart';
import 'package:syntrace/core/cache/cache_policy.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'models/employee_model.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';

class EmployeesRepository {
  Future<CacheSessionGuard> _prepareMutation([String? employeeId]) async {
    final scope = CacheScope.fromCurrentUser();
    if (scope == null ||
        CurrentUserService.instance.user?.isAdmin != true ||
        employeeId == scope.userId) {
      throw StateError('Operation not permitted.');
    }
    final guard = CacheSessionGuard.capture(scope);
    if (!await ConnectivityService().hasNetworkConnection()) {
      throw StateError('Connection required.');
    }
    guard.ensureValid();
    if (CacheService.instance.isInitialized) {
      await CacheService.instance.repository.invalidateType(
        scope: scope,
        resourceType: 'employees',
      );
      guard.ensureValid();
      await CacheService.instance.repository.invalidate(
        scope: scope,
        resourceType: 'dashboard',
        resourceKey: 'team_members_count',
      );
    }
    guard.ensureValid();
    return guard;
  }

  Future<void> _afterMutation(CacheSessionGuard guard) async {
    guard.ensureValid();
    if (CacheService.instance.isInitialized) {
      await CacheService.instance.repository.invalidateType(
        scope: guard.scope,
        resourceType: 'employees',
      );
      guard.ensureValid();
      await CacheService.instance.repository.invalidate(
        scope: guard.scope,
        resourceType: 'dashboard',
        resourceKey: 'team_members_count',
      );
    }
    guard.ensureValid();
    await SyncRuntime.instance.refresh();
  }

  Future<ApiResponse<List<EmployeeModel>>> getAllEmployees({
    bool allowCache = true,
    bool propagateNetworkErrors = false,
    CancelToken? cancelToken,
  }) async {
    final scope = CacheScope.fromCurrentUser();
    if (scope == null) {
      return ApiResponse.failure(message: 'Session unavailable.');
    }
    final guard = CacheSessionGuard.capture(scope);
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.allEmployees,
        options: Options(
          extra: {'auth_generation': guard.generation, 'allow_retry': false},
        ),

        cancelToken: cancelToken,
      );

      if (response.statusCode != 200) {
        if (guard.isValid &&
            CacheService.instance.isInitialized &&
            [401, 403].contains(response.statusCode)) {
          await CacheService.instance.repository.invalidateType(
            scope: scope,
            resourceType: 'employees',
          );
        }
        if (propagateNetworkErrors) {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          );
        }
        return ApiResponse.failure(
          message: 'Failed to load employees (${response.statusCode})',
        );
      }

      guard.ensureValid();
      final data = response.data;

      final List<dynamic> list;

      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else {
        return ApiResponse.failure(message: 'Invalid employees response.');
      }

      final employees = list.map((item) {
        if (item is! Map) {
          throw const FormatException('Invalid employee data.');
        }

        final employee = EmployeeModel.fromJson(
          Map<String, dynamic>.from(item),
        );

        if (employee.id.trim().isEmpty ||
            employee.companyId != scope.tenantId) {
          throw const FormatException('Missing employee ID.');
        }

        return employee;
      }).toList();

      if (CacheService.instance.isInitialized) {
        try {
          await CacheService.instance.repository.save(
            scope: scope,
            resourceType: 'employees',
            resourceKey: 'directory',
            data: employees,
            encode: (items) => items.map((e) => e.toJson()).toList(),
            policy: CachePolicy.team,
            guard: guard,
          );
        } catch (_) {}
      }
      guard.ensureValid();
      return ApiResponse.success(data: List.unmodifiable(employees));
    } on DioException catch (e) {
      if (guard.isValid && CacheService.instance.isInitialized) {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          await CacheService.instance.repository.invalidateType(
            scope: scope,
            resourceType: 'employees',
          );
        } else if (allowCache &&
            (e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                [502, 503, 504].contains(status))) {
          final entry = await CacheService.instance.repository
              .read<List<EmployeeModel>>(
                scope: scope,
                resourceType: 'employees',
                resourceKey: 'directory',
                decode: (json) => (json as List)
                    .map(
                      (e) => EmployeeModel.fromJson(
                        Map<String, dynamic>.from(e as Map),
                      ),
                    )
                    .toList(),
                policy: CachePolicy.team,
              );
          if (guard.isValid &&
              entry != null &&
              entry.data.every((e) => e.companyId == scope.tenantId)) {
            return ApiResponse.success(data: entry.data, message: 'cached');
          }
        }
      }
      if (propagateNetworkErrors) rethrow;
      return ApiResponse.failure(message: 'Unable to load employees.');
    } catch (_) {
      return ApiResponse.failure(message: 'Unable to load employees.');
    }
  }

  Future<ApiResponse<bool>> createEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
  }) async {
    try {
      if (role.trim().isEmpty || role.trim().length > 256) {
        return ApiResponse.failure(message: 'Select a valid workspace role.');
      }
      final guard = await _prepareMutation();
      final response = await ApiClient.instance.post(
        ApiEndpoints.createEmployee,
        options: Options(
          extra: {'auth_generation': guard.generation, 'allow_retry': false},
        ),
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
          'phoneNumber': phoneNumber.trim().isEmpty ? null : phoneNumber.trim(),
          'roleId': role.trim(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        guard.ensureValid();
        try {
          await _afterMutation(guard);
        } catch (_) {}
        guard.ensureValid();
        return ApiResponse.success(data: true);
      }
      return ApiResponse.failure(
        message: 'Failed to create employee (${response.statusCode})',
      );
    } catch (_) {
      return ApiResponse.failure(
        message: 'Request failed. Refresh before retrying.',
      );
    }
  }

  Future<ApiResponse<bool>> deleteEmployee(String employeeId) async {
    try {
      final guard = await _prepareMutation(employeeId);
      final response = await ApiClient.instance.delete(
        ApiEndpoints.deleteEmployee,
        options: Options(
          extra: {'auth_generation': guard.generation, 'allow_retry': false},
        ),
        data: {'employeeId': employeeId},
      );

      if ((response.statusCode == 200 || response.statusCode == 204) &&
          response.data != false) {
        guard.ensureValid();
        try {
          await _afterMutation(guard);
        } catch (_) {}
        guard.ensureValid();
        return ApiResponse.success(data: true);
      }
      return ApiResponse.failure(
        message: 'Failed to delete employee (${response.statusCode})',
      );
    } catch (_) {
      return ApiResponse.failure(
        message: 'Request failed. Refresh before retrying.',
      );
    }
  }

  Future<ApiResponse<bool>> changeRole(
    String employeeId,
    String newRole, {
    String? previousRoleId,
  }) async {
    try {
      final guard = await _prepareMutation(employeeId);
      final response = await ApiClient.instance.put(
        ApiEndpoints.changeRole,
        options: Options(
          extra: {'auth_generation': guard.generation, 'allow_retry': false},
        ),
        data: {
          'employeeId': employeeId,
          'newRoleId': newRole,
          if (previousRoleId != null) 'previousRoleId': previousRoleId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        guard.ensureValid();
        try {
          await _afterMutation(guard);
        } catch (_) {}
        guard.ensureValid();
        return ApiResponse.success(data: true);
      }
      return ApiResponse.failure(
        message: 'Failed to change role (${response.statusCode})',
      );
    } catch (_) {
      return ApiResponse.failure(
        message: 'Request failed. Refresh before retrying.',
      );
    }
  }
}
