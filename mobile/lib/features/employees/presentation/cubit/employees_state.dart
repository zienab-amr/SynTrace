import 'package:syntrace/core/state/base_state.dart';
import '../../data/models/employee_model.dart';

abstract class EmployeesState extends BaseState {
  const EmployeesState();
}

class EmployeesInitial extends EmployeesState {
  const EmployeesInitial();
}

class EmployeesLoading extends EmployeesState {
  const EmployeesLoading();
}

class EmployeesLoaded extends EmployeesState {
  final List<EmployeeModel> employees;
  const EmployeesLoaded(this.employees);

  @override
  List<Object?> get props => [employees];
}

class EmployeesError extends EmployeesState {
  final String message;
  const EmployeesError(this.message);

  @override
  List<Object?> get props => [message];
}
