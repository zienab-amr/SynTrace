import 'package:syntrace/features/role/data/models/role_model.dart';

abstract class RolesState {}

class RolesInitial extends RolesState {}

class RolesLoading extends RolesState {}

class RolesActionSuccess extends RolesState {
  final String message;
  RolesActionSuccess(this.message);
}

class RolesError extends RolesState {
  final String message;
  RolesError(this.message);
}

class RolesLoaded extends RolesState {
  final List<RoleModel> roles;
  RolesLoaded(this.roles);
}
