import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/core/models/user_profile_model.dart';

abstract class SettingsState extends BaseState {
  const SettingsState();
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

class SettingsLoaded extends SettingsState {
  final UserProfileModel profile;
  final bool isEditing;
  final bool isSaving;

  const SettingsLoaded({
    required this.profile,
    this.isEditing = false,
    this.isSaving = false,
  });

  SettingsLoaded copyWith({
    UserProfileModel? profile,
    bool? isEditing,
    bool? isSaving,
  }) {
    return SettingsLoaded(
      profile: profile ?? this.profile,
      isEditing: isEditing ?? this.isEditing,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props => [profile, isEditing, isSaving];
}

class SettingsError extends SettingsState {
  final String message;
  const SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

class SettingsLoggedOut extends SettingsState {
  const SettingsLoggedOut();
}