import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/features/employees/data/employees_repository.dart';
import 'package:syntrace/features/developers/data/models/developer_model.dart';
import 'developers_state.dart';

class DevelopersCubit extends Cubit<DevelopersState> {
  DevelopersCubit() : super(DevelopersInitial()) {
    final scope = CacheScope.fromCurrentUser();
    if (scope != null) _guard = CacheSessionGuard.capture(scope);
    CurrentUserService.instance.userNotifier.addListener(_sessionChanged);
  }

  CacheSessionGuard? _guard;
  bool get _valid => !isClosed && _guard?.isValid == true;
  void _sessionChanged() {
    if (!isClosed && !_valid) {
      emit(const DevelopersError('Session changed. Reopen this page.'));
    }
  }

  @override
  Future<void> close() {
    CurrentUserService.instance.userNotifier.removeListener(_sessionChanged);
    _guard = null;
    return super.close();
  }

  Future<void> loadDevelopers() async {
    if (isClosed || state is DevelopersLoading) return;
    if (!_valid) {
      emit(const DevelopersError('Session unavailable.'));
      return;
    }
    emit(DevelopersLoading());
    try {
      final result = await EmployeesRepository().getAllEmployees(
        allowCache: true,
      );
      if (!_valid) return;
      if (!result.success || result.data == null) {
        emit(const DevelopersError('Unable to load team members.'));
        return;
      }
      emit(
        DevelopersLoaded(
          result.data!
              .where(
                (e) => e.roleNames.any((r) => r.toLowerCase() == 'developer'),
              )
              .map(
                (e) => DeveloperModel(
                  id: e.id,
                  name: e.fullName,
                  role: e.role,
                  email: e.email,
                  initials: e.initials,
                ),
              )
              .toList(),
          isFromCache: result.message == 'cached',
        ),
      );
    } catch (_) {
      if (_valid) emit(const DevelopersError('Unable to load team members.'));
    }
  }
}
