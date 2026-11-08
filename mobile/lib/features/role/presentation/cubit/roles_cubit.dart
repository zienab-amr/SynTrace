import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/roles_repository.dart';
import 'roles_state.dart';

class RolesCubit extends Cubit<RolesState> {
  final RolesRepository _repository = RolesRepository();

  RolesCubit() : super(RolesInitial());

  Future<void> fetchRoles() async {
    emit(RolesLoading());
    final response = await _repository.getAllRoles();

    if (response.success && response.data != null) {
      emit(RolesLoaded(response.data!));
    } else {
      emit(RolesError(response.message));
    }
  }

  Future<void> createRole(String name, String description) async {
    emit(RolesLoading());
    final response = await _repository.createRole(name, description);

    if (response.success) {
      emit(RolesActionSuccess(response.message));
      fetchRoles();
    } else {
      emit(RolesError(response.message));
    }
  }

  Future<void> deleteRole(String id) async {
    emit(RolesLoading());
    final response = await _repository.deleteRole(id);

    if (response.success) {
      emit(RolesActionSuccess(response.message));
      fetchRoles();
    } else {
      emit(RolesError(response.message));
    }
  }
}
