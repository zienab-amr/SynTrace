import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import '../../../data/models/project_team_member.dart';
import '../../../data/projects_repository.dart';

import 'project_members_state.dart';

class ProjectMembersCubit extends Cubit<ProjectMembersState> {
  final String projectId;
  final ProjectsRepository _repository;

  final UserModel? _owner = CurrentUserService.instance.user;

  CancelToken? _cancelToken;

  ProjectMembersCubit({required this.projectId, ProjectsRepository? repository})
    : _repository = repository ?? ProjectsRepository(),
      super(const ProjectMembersState());

  bool get _hasValidSession {
    final current = CurrentUserService.instance.user;

    return !isClosed &&
        _owner != null &&
        _owner.id.isNotEmpty &&
        _owner.tenantId?.isNotEmpty == true &&
        current?.id == _owner.id &&
        current?.tenantId == _owner.tenantId;
  }

  bool get canManage =>
      _hasValidSession &&
      CurrentUserService.instance.user?.role == UserRole.admin;

  Future<void> loadMembers() async {
    if (!_hasValidSession || state.isBusy) return;

    await _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    if (!_hasValidSession) return;

    _cancelToken?.cancel();

    final token = CancelToken();
    _cancelToken = token;

    final hasLoaded = state.hasLoaded;

    emit(
      state.copyWith(
        status: hasLoaded
            ? ProjectMembersStatus.success
            : ProjectMembersStatus.loading,
        isRefreshing: hasLoaded,
        isUnavailable: false,
        clearError: true,
      ),
    );

    try {
      final members = await _repository.getProjectMembers(
        projectId,
        cancelToken: token,
      );

      if (!_hasValidSession || token.isCancelled || _cancelToken != token) {
        return;
      }

      emit(
        ProjectMembersState(
          status: ProjectMembersStatus.success,
          members: members,
        ),
      );
    } catch (error) {
      if (!_hasValidSession || token.isCancelled || _cancelToken != token) {
        return;
      }

      final code = error is DioException ? error.response?.statusCode : null;

      final unavailable = code == 404 || code == 405 || code == 501;

      final accessDenied = code == 401 || code == 403;

      final clearMembers = unavailable || accessDenied;

      emit(
        ProjectMembersState(
          status: ProjectMembersStatus.failure,
          members: clearMembers ? const [] : state.members,
          isUnavailable: unavailable,
          errorMessage: _errorMessage(error),
        ),
      );
    }
  }

  Future<bool> addMember({
    required String employeeId,
    required ProjectMemberRole role,
  }) async {
    if (employeeId.trim().isEmpty) return false;

    if (state.members.any((member) => member.employeeId == employeeId)) {
      return false;
    }

    return _mutate(
      () => _repository.addProjectMember(
        projectId: projectId,
        employeeId: employeeId,
        role: role.apiValue,
      ),
    );
  }

  Future<bool> changeRole({
    required String employeeId,
    required ProjectMemberRole role,
  }) async {
    if (!state.members.any((member) => member.employeeId == employeeId)) {
      return false;
    }

    return _mutate(
      () => _repository.addProjectMember(
        projectId: projectId,
        employeeId: employeeId,
        role: role.apiValue,
      ),
    );
  }

  Future<bool> removeMember(String employeeId) async {
    if (!state.members.any((member) => member.employeeId == employeeId)) {
      return false;
    }

    return _mutate(
      () => _repository.removeProjectMember(
        projectId: projectId,
        employeeId: employeeId,
      ),
    );
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    if (!canManage || state.isBusy || !state.hasLoaded || state.isUnavailable) {
      return false;
    }

    emit(state.copyWith(isMutating: true, clearError: true));

    try {
      await operation();

      if (!_hasValidSession) return false;

      await _fetchMembers();

      return _hasValidSession;
    } catch (error) {
      if (!_hasValidSession) return false;

      final code = error is DioException ? error.response?.statusCode : null;

      if (code == 401 || code == 403 || code == 404) {
        emit(
          ProjectMembersState(
            status: ProjectMembersStatus.failure,
            errorMessage: _errorMessage(error),
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: ProjectMembersStatus.failure,
            isMutating: false,
            errorMessage:
                'The operation could not be confirmed. '
                'Refresh the team before trying again.',
          ),
        );
      }

      return false;
    } finally {
      if (_hasValidSession && state.isMutating) {
        emit(state.copyWith(isMutating: false));
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
          return 'Your session has expired.';

        case 403:
          return 'You do not have permission '
              'to access project members.';

        case 404:
          return 'Project or member information '
              'is unavailable.';

        case 405:
        case 501:
          return 'Project member information '
              'is not available on the server yet.';

        case 409:
          return 'The requested change conflicts '
              'with the current project configuration.';
      }
    }

    if (error is FormatException) {
      return 'Invalid member data received '
          'from the server.';
    }

    return 'Unable to load project members. '
        'Please try again.';
  }

  @override
  Future<void> close() {
    _cancelToken?.cancel();

    return super.close();
  }
}
