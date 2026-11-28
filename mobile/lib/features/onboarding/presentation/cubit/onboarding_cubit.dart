import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/core/theme/theme_controller.dart';
import 'package:syntrace/features/employees/data/employees_repository.dart';
import 'package:syntrace/features/onboarding/data/onboarding_data.dart';
import 'package:syntrace/features/onboarding/data/onboarding_service.dart';

import 'package:syntrace/features/role/data/roles_repository.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';

import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final EmployeesRepository _employeesRepository;

  OnboardingCubit({EmployeesRepository? employeesRepository})
    : _employeesRepository = employeesRepository ?? EmployeesRepository(),
      super(const OnboardingInitial());

  bool _isSubmitting = false;

  void start() {
    if (_isSubmitting || isClosed) return;

    final user = CurrentUserService.instance.user;

    final data = OnboardingData(
      organizationName: user?.companyName ?? '',
      isDarkMode: ThemeController.themeMode.value == ThemeMode.dark,
    );

    emit(OnboardingInProgress(currentStep: 0, data: data, canGoNext: true));
  }

  OnboardingInProgress? get _currentState {
    final current = state;

    return current is OnboardingInProgress ? current : null;
  }

  void nextStep() {
    final current = _currentState;

    if (current == null || _isSubmitting || !current.canGoNext) {
      return;
    }

    if (current.isLastStep) {
      _complete(current);
      return;
    }

    final next = current.currentStep + 1;

    emit(
      current.copyWith(
        currentStep: next,
        canGoNext: _validateStep(next, current.data),
      ),
    );
  }

  void previousStep() {
    final current = _currentState;

    if (current == null || current.isFirstStep || _isSubmitting) {
      return;
    }

    final previous = current.currentStep - 1;

    emit(
      current.copyWith(
        currentStep: previous,
        canGoNext: _validateStep(previous, current.data),
      ),
    );
  }

  void goToStep(int step) {
    final current = _currentState;

    if (current == null || _isSubmitting) return;

    if (step < 0 || step >= OnboardingInProgress.totalSteps) {
      return;
    }

    for (var i = 0; i < step; i++) {
      if (!_validateStep(i, current.data)) return;
    }

    emit(
      current.copyWith(
        currentStep: step,
        canGoNext: _validateStep(step, current.data),
      ),
    );
  }

  void updateOrganizationName(String name) {
    final current = _currentState;
    if (current == null) return;

    _updateData(current.data.copyWith(organizationName: name));
  }

  void updateIndustry(String industry) {
    final current = _currentState;
    if (current == null) return;

    _updateData(
      current.data.copyWith(
        industry: industry,
        customIndustry: industry == 'Other' ? current.data.customIndustry : '',
      ),
    );
  }

  void updateCustomIndustry(String value) {
    final current = _currentState;
    if (current == null) return;

    _updateData(current.data.copyWith(customIndustry: value));
  }

  void updateTeamSize(String size) {
    final current = _currentState;
    if (current == null) return;

    _updateData(current.data.copyWith(teamSize: size));
  }

  void addTeamMember(Map<String, String> member) {
    final current = _currentState;

    if (current == null || _isSubmitting) return;

    final email = (member['email'] ?? '').trim().toLowerCase();

    if (email.isEmpty) return;

    final members = current.data.teamMembers;

    final alreadyExists = members.any(
      (item) => item['email']?.trim().toLowerCase() == email,
    );

    if (alreadyExists) return;

    _updateData(
      current.data.copyWith(
        teamMembers: [
          ...members,
          {...member, 'email': email},
        ],
      ),
    );
  }

  void removeTeamMember(String email) {
    final current = _currentState;

    if (current == null || _isSubmitting) return;

    final normalizedEmail = email.trim().toLowerCase();

    final members = current.data.teamMembers
        .where(
          (member) => member['email']?.trim().toLowerCase() != normalizedEmail,
        )
        .toList();

    _updateData(current.data.copyWith(teamMembers: members));
  }

  void updateDarkMode(bool value) {
    final current = _currentState;

    if (current == null || _isSubmitting) return;

    ThemeController.setTheme(value ? ThemeMode.dark : ThemeMode.light);

    _updateData(current.data.copyWith(isDarkMode: value));
  }

  // Retained temporarily for UI compatibility.
  void updateNotifications(bool value) {}

  void _updateData(OnboardingData data) {
    final current = _currentState;

    if (current == null || _isSubmitting || isClosed) {
      return;
    }

    emit(
      current.copyWith(
        data: data,
        canGoNext: _validateStep(current.currentStep, data),
      ),
    );
  }

  bool _validateStep(int step, OnboardingData data) {
    return step >= 0 && step < OnboardingInProgress.totalSteps;
  }

  Future<void> _complete(OnboardingInProgress current) async {
    if (_isSubmitting || isClosed) return;

    final user = CurrentUserService.instance.user;

    final scope = CacheScope.fromCurrentUser();
    if (user == null || scope == null) return;
    final guard = CacheSessionGuard.capture(scope);

    final pendingMembers = current.data.teamMembers
        .map((member) => Map<String, String>.from(member))
        .toList();

    _isSubmitting = true;

    emit(const OnboardingLoading());

    try {
      final rolesResult = pendingMembers.isEmpty
          ? null
          : await RolesRepository().getAllRoles();
      if (isClosed || !guard.isValid) return;
      if (pendingMembers.isNotEmpty &&
          (rolesResult?.success != true || rolesResult?.data == null)) {
        _restoreAfterError(
          current,
          pendingMembers,
          'Unable to verify workspace roles. Please retry.',
        );
        return;
      }
      while (pendingMembers.isNotEmpty) {
        if (isClosed ||
            CurrentUserService.instance.user?.id != user.id ||
            CurrentUserService.instance.user?.tenantId != user.tenantId) {
          return;
        }

        final member = pendingMembers.first;

        final selectedRole = (member['roleId'] ?? member['role'] ?? '').trim();
        final matches = rolesResult!.data!
            .where(
              (role) =>
                  role.id == selectedRole ||
                  role.name.trim().toLowerCase() == selectedRole.toLowerCase(),
            )
            .toList();
        if (matches.length != 1) {
          _restoreAfterError(
            current,
            pendingMembers,
            'Select a valid workspace role for ${member['email']}.',
          );
          return;
        }
        final result = await _employeesRepository.createEmployee(
          firstName: member['firstName'] ?? '',
          lastName: member['lastName'] ?? '',
          email: member['email'] ?? '',
          password: member['password'] ?? '',
          phoneNumber: member['phoneNumber'] ?? '',
          role: matches.single.id,
        );

        if (isClosed || !guard.isValid) return;

        if (!result.success || result.data != true) {
          _restoreAfterError(
            current,
            pendingMembers,
            'Could not create ${member['email']}. '
            'Please review the member details and try again.',
          );

          return;
        }

        // Remove successfully created members from the queue.
        pendingMembers.removeAt(0);
      }

      if (isClosed ||
          CurrentUserService.instance.user?.id != user.id ||
          CurrentUserService.instance.user?.tenantId != user.tenantId) {
        return;
      }

      final completedData = current.data.copyWith(
        teamMembers: <Map<String, String>>[],
      );

      await OnboardingService.instance.saveData(completedData);

      if (isClosed || !guard.isValid) return;
      await SecureStorageService.instance.saveOnboardingCompleted(true);

      if (isClosed || !guard.isValid) return;

      emit(OnboardingCompleted(completedData));
    } catch (_) {
      if (isClosed || !guard.isValid) return;
      _restoreAfterError(
        current,
        pendingMembers,
        'Unable to complete setup. Please try again.',
      );
    } finally {
      _isSubmitting = false;
    }
  }

  void _restoreAfterError(
    OnboardingInProgress previous,
    List<Map<String, String>> pendingMembers,
    String message,
  ) {
    if (isClosed) return;

    emit(OnboardingError(message));

    emit(
      previous.copyWith(
        currentStep: pendingMembers.isNotEmpty ? 2 : previous.currentStep,
        data: previous.data.copyWith(teamMembers: pendingMembers),
        canGoNext: true,
      ),
    );
  }
}
