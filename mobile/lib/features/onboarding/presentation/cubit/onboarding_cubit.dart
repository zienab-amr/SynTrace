import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/features/onboarding/data/onboarding_data.dart';
import 'package:syntrace/features/onboarding/data/onboarding_service.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit() : super(const OnboardingInitial());

  void start() {
    emit(
      const OnboardingInProgress(
        currentStep: 0,
        data: OnboardingData(),
        canGoNext: true,
      ),
    );
  }

  void nextStep() {
    final state = _currentState;
    if (state.isLastStep) {
      _complete();
      return;
    }
    emit(
      state.copyWith(
        currentStep: state.currentStep + 1,
        canGoNext: _validateStep(state.currentStep + 1, state.data),
      ),
    );
  }

  void previousStep() {
    final state = _currentState;
    if (state.isFirstStep) return;
    emit(state.copyWith(currentStep: state.currentStep - 1, canGoNext: true));
  }

  void goToStep(int step) {
    final state = _currentState;
    if (step < 0 || step >= OnboardingInProgress.totalSteps) return;
    emit(
      state.copyWith(
        currentStep: step,
        canGoNext: _validateStep(step, state.data),
      ),
    );
  }

  void updateOrganizationName(String name) =>
      _updateData(_currentState.data.copyWith(organizationName: name));
  void updateIndustry(String industry) {
    final data = _currentState.data.copyWith(
      industry: industry,
      customIndustry: industry == 'Other'
          ? _currentState.data.customIndustry
          : '',
    );
    _updateData(data);
  }

  void updateCustomIndustry(String value) =>
      _updateData(_currentState.data.copyWith(customIndustry: value));
  void updateTeamSize(String size) =>
      _updateData(_currentState.data.copyWith(teamSize: size));

  void addTeamMember(Map<String, String> member) {
    final members = List<Map<String, String>>.from(
      _currentState.data.teamMembers,
    )..add(member);
    _updateData(_currentState.data.copyWith(teamMembers: members));
  }

  void removeTeamMember(String email) {
    final members = List<Map<String, String>>.from(
      _currentState.data.teamMembers,
    )..removeWhere((m) => m['email'] == email);
    _updateData(_currentState.data.copyWith(teamMembers: members));
  }

  void updateDarkMode(bool value) =>
      _updateData(_currentState.data.copyWith(isDarkMode: value));
  void updateNotifications(bool value) =>
      _updateData(_currentState.data.copyWith(notificationsEnabled: value));

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
    emit(
      state.copyWith(
        data: newData,
        canGoNext: _validateStep(state.currentStep, newData),
      ),
    );
  }

  bool _validateStep(int step, OnboardingData data) {
    switch (step) {
      case 0:
        return true;
      case 1:
        final hasIndustry =
            data.industry.isNotEmpty &&
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
    emit(const OnboardingLoading());

    // ═══ 1. نحفظ محلياً إنه خلص أونبوردينج فوراً (قبل أي API) ═══
    await OnboardingService.instance.saveData(state.data);
    await SecureStorageService.instance.saveOnboardingCompleted(true);

    // ═══ 2. نحاول نبعت الموظفين للباك إند (لو فشل، منوقفش المستخدم) ═══
    try {
      for (var member in state.data.teamMembers) {
        await ApiClient.instance.post(
          ApiEndpoints.createEmployee,
          data: {
            'firstName': member['firstName'],
            'lastName': member['lastName'],
            'phoneNumber': member['phoneNumber'],
            'email': member['email'],
            'password': member['password'],
            'role': member['role'],
          },
        );
      }
      print('✅ All employees created successfully');
    } catch (e) {
      // ═══ 3. لو فشل، بنطبع إيرور بس منمنعش المستخدم ═══
      print('⚠️ Failed to create employees: $e');
      // ممكن نضيف قائمة بالموظفين اللي فشلوا عشان يبعتهم بعدين
    }

    // ═══ 4. في كل الحالات، بنقفل الأونبوردينج ═══
    emit(OnboardingCompleted(state.data));
  }
}
