import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/network/api_response.dart';
import '../../data/roles_repository.dart';
import 'roles_state.dart';

class RolesCubit extends Cubit<RolesState> {
  final RolesRepository _repository = RolesRepository();
  CacheSessionGuard? _guard;
  bool _busy = false;

  RolesCubit() : super(RolesInitial()) {
    final scope = CacheScope.fromCurrentUser();
    if (scope != null) {
      try {
        _guard = CacheSessionGuard.capture(scope);
      } catch (_) {}
    }
    CurrentUserService.instance.userNotifier.addListener(_sessionChanged);
  }

  bool get canManage =>
      !isClosed &&
      _guard?.isValid == true &&
      CurrentUserService.instance.user?.isAdmin == true;

  void _sessionChanged() {
    if (canManage) return;
    _guard = null;
    if (!isClosed) emit(RolesError('Session changed or access revoked.'));
  }

  bool _begin() {
    if (isClosed || _busy) return false;
    if (!canManage) {
      emit(RolesError('Admin access required. Reopen this page.'));
      return false;
    }
    _busy = true;
    emit(RolesLoading());
    return true;
  }

  Future<void> fetchRoles() async {
    if (!_begin()) return;
    try {
      await _load();
    } finally {
      _busy = false;
    }
  }

  Future<void> _load() async {
    final response = await _repository.getAllRoles();
    if (!canManage) return;
    if (response.success && response.data != null) {
      emit(RolesLoaded(response.data!));
    } else {
      emit(RolesError(response.message));
    }
  }

  Future<void> _mutate(Future<ApiResponse<dynamic>> Function() action) async {
    if (!_begin()) return;
    try {
      final response = await action();
      if (!canManage) return;
      if (response.success) {
        emit(RolesActionSuccess(response.message));
        await _load();
      } else {
        emit(RolesError(response.message));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> createRole(String name, String description) =>
      _mutate(() => _repository.createRole(name, description));

  Future<void> updateRole(String id, String name, [String description = '']) =>
      _mutate(() => _repository.updateRole(id, name, description));

  Future<void> deleteRole(String id) =>
      _mutate(() => _repository.deleteRole(id));

  @override
  Future<void> close() {
    CurrentUserService.instance.userNotifier.removeListener(_sessionChanged);
    _guard = null;
    return super.close();
  }
}
