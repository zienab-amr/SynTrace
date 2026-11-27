import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/cache/cache_session.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import '../../data/project_setup_repository.dart';

import 'project_setup_state.dart';

class ProjectSetupCubit extends Cubit<ProjectSetupState> {
  final ProjectSetupRepository _repository;
  final int _generation = CacheSession.instance.generation;

  ProjectSetupCubit({ProjectSetupRepository? repository})
    : _repository = repository ?? ProjectSetupRepository(),
      super(const ProjectSetupState());

  bool _canAccess(UserModel? user) {
    final current = CurrentUserService.instance.user;

    return !isClosed &&
        CacheSession.instance.generation == _generation &&
        user != null &&
        user.tenantId?.isNotEmpty == true &&
        current?.id == user.id &&
        current?.tenantId == user.tenantId &&
        current?.role == UserRole.admin;
  }

  Future<void> loadEmployees() async {
    if (isClosed || state.employees.isLoading) return;

    final user = CurrentUserService.instance.user;

    if (!_canAccess(user)) return;

    emit(
      state.copyWith(
        employees: const SetupOptions(status: SetupStatus.loading),
      ),
    );

    try {
      final employees = await _repository.getEmployees();

      if (!_canAccess(user)) return;

      emit(
        state.copyWith(
          employees: SetupOptions(
            status: SetupStatus.success,
            items: employees,
          ),
        ),
      );
    } catch (_) {
      if (!_canAccess(user)) return;

      emit(
        state.copyWith(
          employees: const SetupOptions(
            status: SetupStatus.failure,
            error: 'Unable to load workspace employees.',
          ),
        ),
      );
    }
  }

  Future<void> loadGitHubRepositories() async {
    if (isClosed || state.github.isLoading) return;

    final user = CurrentUserService.instance.user;

    if (!_canAccess(user)) return;

    emit(
      state.copyWith(github: const SetupOptions(status: SetupStatus.loading)),
    );

    try {
      final repositories = await _repository.getGitHubRepositories();

      if (!_canAccess(user)) return;

      emit(
        state.copyWith(
          github: SetupOptions(
            status: SetupStatus.success,
            items: repositories,
          ),
        ),
      );
    } catch (_) {
      if (!_canAccess(user)) return;

      emit(
        state.copyWith(
          github: const SetupOptions(
            status: SetupStatus.failure,
            error:
                'Unable to load GitHub repositories. '
                'Check your workspace integration.',
          ),
        ),
      );
    }
  }

  Future<void> loadJiraProjects() async {
    if (isClosed || state.jira.isLoading) return;

    final user = CurrentUserService.instance.user;

    if (!_canAccess(user)) return;

    emit(state.copyWith(jira: const SetupOptions(status: SetupStatus.loading)));

    try {
      final projects = await _repository.getJiraProjects();

      if (!_canAccess(user)) return;

      emit(
        state.copyWith(
          jira: SetupOptions(status: SetupStatus.success, items: projects),
        ),
      );
    } catch (_) {
      if (!_canAccess(user)) return;

      emit(
        state.copyWith(
          jira: const SetupOptions(
            status: SetupStatus.failure,
            error:
                'Unable to load Jira projects. '
                'Check your workspace integration.',
          ),
        ),
      );
    }
  }

  Future<void> loadIntegrations() async {
    await Future.wait<void>([loadGitHubRepositories(), loadJiraProjects()]);
  }
}
