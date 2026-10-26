import 'package:syntrace/core/models/user_profile_model.dart';
import 'package:syntrace/core/state/base_state.dart';

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
  final bool isSaving;
  final bool isEditing;

  const SettingsLoaded({
    required this.profile,
    this.isSaving = false,
    this.isEditing = false,
  });

  SettingsLoaded copyWith({
    UserProfileModel? profile,
    bool? isSaving,
    bool? isEditing,
  }) {
    return SettingsLoaded(
      profile: profile ?? this.profile,
      isSaving: isSaving ?? this.isSaving,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  @override
  List<Object?> get props => [profile, isSaving, isEditing];
}

class SettingsError extends SettingsState {
  final String message;
  const SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}