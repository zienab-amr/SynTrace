import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/employees_repository.dart';
import 'employees_state.dart';

class EmployeesCubit extends Cubit<EmployeesState> {
  final EmployeesRepository _repository;

  EmployeesCubit({EmployeesRepository? repository})
    : _repository = repository ?? EmployeesRepository(),
      super(const EmployeesInitial());

  Future<void> loadEmployees() async {
    emit(const EmployeesLoading());

    final result = await _repository.getAllEmployees();
    if (result.success && result.data != null) {
      emit(EmployeesLoaded(result.data!));
    } else {
      emit(EmployeesError(result.message));
    }
  }

  Future<void> addEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phoneNumber,
    required String role,
  }) async {
    emit(const EmployeesLoading());
    final result = await _repository.createEmployee(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
      role: role,
    );
    if (result.success) {
      await loadEmployees();
    } else {
      emit(EmployeesError(result.message));
    }
  }

  Future<void> deleteEmployee(String employeeId) async {
    emit(const EmployeesLoading());
    final result = await _repository.deleteEmployee(employeeId);
    if (result.success) {
      await loadEmployees();
    } else {
      emit(EmployeesError(result.message));
    }
  }

  Future<void> changeRole(String employeeId, String newRole) async {
    emit(const EmployeesLoading());
    final result = await _repository.changeRole(employeeId, newRole);
    if (result.success) {
      await loadEmployees();
    } else {
      emit(EmployeesError(result.message));
    }
  }
}
