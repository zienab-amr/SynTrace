import 'package:dio/dio.dart';
import 'package:syntrace/core/cache/cache_service.dart';
import 'package:syntrace/core/cache/cache_policy.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/features/employees/data/models/employee_model.dart';

class ProfileDataService {
  static Future<({EmployeeModel employee, bool cached})> getProfileData(
    String employeeId,
  ) async {
    final scope = CacheScope.fromCurrentUser();
    if (scope == null) throw StateError('Session unavailable');
    final guard = CacheSessionGuard.capture(scope);
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.employeeById,
        queryParameters: {'EmployeeId': employeeId},
      );
      guard.ensureValid();
      if (response.statusCode != 200 || response.data is! Map) {
        throw StateError('Profile unavailable');
      }
      final employee = EmployeeModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (employee.id != employeeId || employee.companyId != scope.tenantId) {
        throw StateError('Profile unavailable');
      }
      return (employee: employee, cached: false);
    } on DioException catch (error) {
      guard.ensureValid();
      final status = error.response?.statusCode;
      if (!CacheService.instance.isInitialized ||
          !([502, 503, 504].contains(status) ||
              [
                DioExceptionType.connectionError,
                DioExceptionType.connectionTimeout,
                DioExceptionType.receiveTimeout,
              ].contains(error.type))) {
        rethrow;
      }
      final entry = await CacheService.instance.repository
          .read<List<EmployeeModel>>(
            scope: scope,
            resourceType: 'employees',
            resourceKey: 'directory',
            policy: CachePolicy.team,
            decode: (json) => (json as List)
                .map(
                  (e) => EmployeeModel.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList(),
          );
      guard.ensureValid();
      for (final employee in entry?.data ?? <EmployeeModel>[]) {
        if (employee.id == employeeId && employee.companyId == scope.tenantId) {
          return (employee: employee, cached: true);
        }
      }
      rethrow;
    }
  }
}
