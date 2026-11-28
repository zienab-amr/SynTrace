import 'package:flutter_bloc/flutter_bloc.dart';
import 'tasks_state.dart';

class TasksCubit extends Cubit<TasksState> {
  TasksCubit() : super(const TasksInitial());

  Future<void> loadTasks() async {
    if (!isClosed) emit(const TasksUnavailable());
  }

  void search(String query) {}
  void setStatusFilter(String? status) {}
  void setPriorityFilter(String? priority) {}
  void clearFilters() {}
}
