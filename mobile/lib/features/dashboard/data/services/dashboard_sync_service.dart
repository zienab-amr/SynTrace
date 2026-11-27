import 'package:dio/dio.dart';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/features/employees/data/employees_repository.dart';
import 'package:syntrace/features/employees/data/models/employee_model.dart';
import 'package:syntrace/core/network/api_response.dart';

import '../cache/dashboard_local_data_source.dart';

class DashboardSyncService {
  DashboardSyncService._();

  static final instance = DashboardSyncService._();

  final local = DashboardLocalDataSource();
  final _employeesRepository = EmployeesRepository();

  Future<int>? _inFlight;
  CacheSessionGuard? _activeGuard;

  void _ensureNotCancelled(CancelToken? token) {
    final error = token?.cancelError;

    if (error != null) {
      throw error;
    }
  }

  Future<int> refreshTeamCount({
    required CacheScope scope,
    CancelToken? cancelToken,
  }) async {
    final guard = CacheSessionGuard.capture(scope);

    guard.ensureValid();
    _ensureNotCancelled(cancelToken);

    if (CurrentUserService.instance.user?.isAdmin != true) {
      throw StateError('Team access is restricted.');
    }

    final active = _inFlight;
    final activeGuard = _activeGuard;

    if (active != null &&
        activeGuard != null &&
        activeGuard.isValid &&
        activeGuard.scope == scope &&
        activeGuard.generation == guard.generation) {
      final count = await active;

      guard.ensureValid();
      _ensureNotCancelled(cancelToken);

      return count;
    }

    final operation = _refresh(
      scope: scope,
      guard: guard,
      cancelToken: cancelToken,
    );

    _inFlight = operation;
    _activeGuard = guard;

    try {
      return await operation;
    } finally {
      if (identical(_inFlight, operation)) {
        _inFlight = null;
        _activeGuard = null;
      }
    }
  }

  Future<int> _refresh({
    required CacheScope scope,
    required CacheSessionGuard guard,
    CancelToken? cancelToken,
  }) async {
    guard.ensureValid();
    _ensureNotCancelled(cancelToken);

    final result = await _loadEmployees(scope, guard, cancelToken);

    guard.ensureValid();
    _ensureNotCancelled(cancelToken);

    if (!result.success || result.data == null) {
      throw StateError('Unable to verify team members.');
    }

    final employees = result.data!;
    final ids = <String>{};

    for (final employee in employees) {
      if (employee.id.trim().isEmpty || employee.companyId != scope.tenantId) {
        await local.invalidateTeamCount(scope);

        throw const FormatException('Invalid employee account scope.');
      }

      ids.add(employee.id);
    }

    guard.ensureValid();
    _ensureNotCancelled(cancelToken);

    await local.saveTeamCount(scope: scope, guard: guard, count: ids.length);

    guard.ensureValid();
    _ensureNotCancelled(cancelToken);

    return ids.length;
  }

  Future<ApiResponse<List<EmployeeModel>>> _loadEmployees(
    CacheScope scope,
    CacheSessionGuard guard,
    CancelToken? cancelToken,
  ) async {
    try {
      return await _employeesRepository.getAllEmployees(
        allowCache: false,
        propagateNetworkErrors: true,
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      if (guard.isValid &&
          const [401, 403].contains(error.response?.statusCode)) {
        await local.invalidateTeamCount(scope);
      }
      rethrow;
    }
  }
}
