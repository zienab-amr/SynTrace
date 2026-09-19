import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/theme/theme_controller.dart';
import 'package:syntrace/features/onboarding/data/onboarding_data.dart';
import 'package:syntrace/features/onboarding/data/onboarding_service.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit() : super(const OnboardingInitial());

  void start() {
    emit(const OnboardingInProgress(
      currentStep: 0,
      data: OnboardingData(),
      canGoNext: true,
    ));
  }

  // ═══════════════════════════════════════════════════════
  // Navigation
  // ═══════════════════════════════════════════════════════
  void nextStep() {
    final state = _currentState;
    if (state.isLastStep) {
      _complete();
      return;
    }

    emit(state.copyWith(
      currentStep: state.currentStep + 1,
      canGoNext: _validateStep(state.currentStep + 1, state.data),
    ));
  }

  void previousStep() {
    final state = _currentState;
    if (state.isFirstStep) return;

    emit(state.copyWith(
      currentStep: state.currentStep - 1,
      canGoNext: true,
    ));
  }
  void goToStep(int step) {
  final state = _currentState;
  if (step < 0 || step >= OnboardingInProgress.totalSteps) return;

  emit(state.copyWith(
    currentStep: step,
    canGoNext: _validateStep(step, state.data),
  ));
}

  // ═══════════════════════════════════════════════════════
  // Data Updates
  // ═══════════════════════════════════════════════════════
  void updateOrganizationName(String name) {
    _updateData(_currentState.data.copyWith(organizationName: name));
  }

  void updateIndustry(String industry) {
    // لو اختار حاجة غير Other، امسحي الـ custom
    final data = _currentState.data.copyWith(
      industry: industry,
      customIndustry: industry == 'Other' ? _currentState.data.customIndustry : '',
    );
    _updateData(data);
  }

  void updateCustomIndustry(String value) {
    _updateData(_currentState.data.copyWith(customIndustry: value));
  }

  void updateTeamSize(String size) {
    _updateData(_currentState.data.copyWith(teamSize: size));
  }

  void updateUserRole(String role) {
    final data = _currentState.data.copyWith(
      userRole: role,
      customRole: role == 'Other' ? _currentState.data.customRole : '',
    );
    _updateData(data);
  }

  void updateCustomRole(String value) {
    _updateData(_currentState.data.copyWith(customRole: value));
  }

  void addTeamEmail(String email) {
    final emails = List<String>.from(_currentState.data.teamEmails)..add(email);
    _updateData(_currentState.data.copyWith(teamEmails: emails));
  }

  void removeTeamEmail(String email) {
    final emails = List<String>.from(_currentState.data.teamEmails)..remove(email);
    _updateData(_currentState.data.copyWith(teamEmails: emails));
  }

  void updateDarkMode(bool value) {
    _updateData(_currentState.data.copyWith(isDarkMode: value));
    ThemeController.setTheme(value ? ThemeMode.dark : ThemeMode.light);

  }

  void updateNotifications(bool value) {
    _updateData(_currentState.data.copyWith(notificationsEnabled: value));
  }

  // ═══════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════
  OnboardingInProgress get _currentState {
    final state = this.state;
    if (state is OnboardingInProgress) return state;
    return const OnboardingInProgress(
      currentStep: 0,
      data: OnboardingData(),
      canGoNext: true,
    );
  }

  void _updateData(OnboardingData newData) {
    final state = _currentState;
    emit(state.copyWith(
      data: newData,
      canGoNext: _validateStep(state.currentStep, newData),
    ));
  }

  bool _validateStep(int step, OnboardingData data) {
    switch (step) {
      case 0:
        return true;
      case 1: // Organization Info
        final hasIndustry = data.industry.isNotEmpty &&
            (data.industry != 'Other' || data.customIndustry.isNotEmpty);
        return data.organizationName.isNotEmpty &&
            hasIndustry &&
            data.teamSize.isNotEmpty;
      case 2:
        return true;
      case 3:
        return true;
      case 4:
        return true;
      default:
        return false;
    }
  }

  Future<void> _complete() async {
    final state = _currentState;
    // ─── حفظ الداتا ───
    await OnboardingService.instance.saveData(state.data);
    emit(OnboardingCompleted(state.data));
  }
}