import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/network/api_response.dart';

import '../../data/employees_repository.dart';
import 'employees_state.dart';

class EmployeesCubit extends Cubit<EmployeesState> {
  final EmployeesRepository _repository;

  EmployeesCubit({EmployeesRepository? repository})
    : _repository = repository ?? EmployeesRepository(),
      super(const EmployeesInitial()) {
    final scope = CacheScope.fromCurrentUser();
    if (scope != null) _guard = CacheSessionGuard.capture(scope);
    CurrentUserService.instance.userNotifier.addListener(_sessionChanged);
  }

  CacheSessionGuard? _guard;
  bool get _sessionValid => !isClosed && _guard?.isValid == true;

  void _sessionChanged() {
    if (!isClosed && !_sessionValid) {
      emit(const EmployeesError('Session changed. Reopen this page.'));
    }
  }

  @override
  Future<void> close() {
    CurrentUserService.instance.userNotifier.removeListener(_sessionChanged);
    _guard = null;
    return super.close();
  }

  bool _isBusy = false;

  bool get isBusy => _isBusy;

  bool get canManage =>
      _sessionValid && CurrentUserService.instance.user?.isAdmin == true;

  bool _sameAccount(UserModel user) {
    final current = CurrentUserService.instance.user;

    return _sessionValid &&
        current?.id == user.id &&
        current?.tenantId == user.tenantId;
  }

  Future<void> loadEmployees() async {
    if (isClosed || _isBusy) return;

    final user = CurrentUserService.instance.user;

    if (user == null || !_sessionValid) {
      emit(const EmployeesError('Session unavailable.'));
      return;
    }

    _isBusy = true;

    try {
      await _fetchEmployees(user);
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _fetchEmployees(UserModel user) async {
    if (isClosed || !_sameAccount(user)) return;

    emit(const EmployeesLoading());

    try {
      final result = await _repository.getAllEmployees();

      if (isClosed || !_sameAccount(user)) return;

      if (result.success && result.data != null) {
        emit(
          EmployeesLoaded(
            List.unmodifiable(result.data!),
            isFromCache: result.message == 'cached',
          ),
        );
      } else {
        emit(
          const EmployeesError(
            'Unable to load team members. Please try again.',
          ),
        );
      }
    } catch (_) {
      if (isClosed || !_sameAccount(user)) return;

      emit(const EmployeesError('Unable to load team members.'));
    }
  }

  Future<void> refresh() => loadEmployees();

  Future<bool> addEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
  }) {
    return _executeMutation(
      operation: () => _repository.createEmployee(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim().toLowerCase(),
        password: password,
        phoneNumber: phoneNumber.trim(),
        role: role,
      ),
      failureMessage:
          'Unable to create member. Check the details and try again.',
    );
  }

  Future<bool> deleteEmployee(String employeeId) {
    if (!_canModifyMember(employeeId)) {
      return Future.value(false);
    }

    return _executeMutation(
      operation: () => _repository.deleteEmployee(employeeId),
      failureMessage: 'Unable to delete member.',
    );
  }

  Future<bool> changeRole(
    String employeeId,
    String newRole, {
    String? previousRoleId,
  }) {
    if (!_canModifyMember(employeeId) || newRole.trim().isEmpty) {
      return Future.value(false);
    }

    return _executeMutation(
      operation: () => _repository.changeRole(
        employeeId,
        newRole,
        previousRoleId: previousRoleId,
      ),
      failureMessage: 'Unable to update member role.',
    );
  }

  bool _canModifyMember(String employeeId) {
    final user = CurrentUserService.instance.user;

    return canManage &&
        user != null &&
        employeeId.trim().isNotEmpty &&
        employeeId != user.id;
  }

  Future<bool> _executeMutation({
    required Future<ApiResponse<bool>> Function() operation,
    required String failureMessage,
  }) async {
    if (isClosed ||
        _isBusy ||
        state is! EmployeesLoaded ||
        (state as EmployeesLoaded).isFromCache) {
      return false;
    }

    final user = CurrentUserService.instance.user;

    if (user == null || !canManage) {
      emit(
        const EmployeesError('You do not have permission to manage members.'),
      );

      return false;
    }

    _isBusy = true;

    emit(const EmployeesLoading());

    try {
      final result = await operation();

      if (isClosed || !_sameAccount(user)) {
        return false;
      }

      if (!result.success || result.data != true) {
        emit(EmployeesError(failureMessage));
        return false;
      }

      await _fetchEmployees(user);

      // The mutation succeeded even if refreshing
      // the employee list failed.
      return true;
    } catch (_) {
      if (!isClosed && _sameAccount(user)) {
        emit(EmployeesError(failureMessage));
      }

      return false;
    } finally {
      _isBusy = false;
    }
  }
}
