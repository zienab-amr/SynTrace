import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/models/user_profile_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsInitial());

  UserProfileModel? _original;

  Future<void> loadProfile() async {
    emit(const SettingsLoading());

    final user = CurrentUserService.instance.user;

    if (user == null) {
      emit(const SettingsError('Failed to load profile'));
      return;
    }

    final storedName = await SecureStorageService.instance.getUserName();
    final storedCompany =
        await SecureStorageService.instance.getCompanyName();

    final profile = UserProfileModel(
      id: user.id,
      fullName: storedName ?? user.name,
      email: user.email,
      role: _capitalize(user.role.value),
      organizationName: storedCompany ?? user.companyName ?? 'Organization',
      organizationId: user.tenantId ?? '',
      avatarUrl: user.avatarUrl,
      permissions: const [
        'Projects',
        'Reports',
        'Knowledge Graph',
        'AI Assistant',
        'Security Center',
      ],
    );

    _original = profile;
    emit(SettingsLoaded(profile: profile));
  }

  void startEditing() {
    if (state is SettingsLoaded) {
      emit((state as SettingsLoaded).copyWith(isEditing: true));
    }
  }

  void cancelEditing() {
    if (state is SettingsLoaded && _original != null) {
      emit(SettingsLoaded(profile: _original!));
    }
  }

  void updateField({String? fullName, String? email}) {
    if (state is! SettingsLoaded) return;

    final current = state as SettingsLoaded;
    final updated = current.profile.copyWith(
      fullName: fullName,
      email: email,
    );

    emit(current.copyWith(profile: updated));
  }

  Future<void> saveChanges() async {
    if (state is! SettingsLoaded) return;

    final current = state as SettingsLoaded;
    emit(current.copyWith(isSaving: true));

    await SecureStorageService.instance.saveUserName(current.profile.fullName);
    await SecureStorageService.instance
        .saveCompanyName(current.profile.organizationName);

    final user = CurrentUserService.instance.user;
    if (user != null) {
      CurrentUserService.instance.setUser(
        user.copyWith(
          name: current.profile.fullName,
          email: current.profile.email,
          companyName: current.profile.organizationName,
        ),
      );
    }

    _original = current.profile;

    emit(current.copyWith(isSaving: false, isEditing: false));
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}