import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';

abstract class TasksState extends BaseState {
  const TasksState();
}

class TasksInitial extends TasksState {
  const TasksInitial();
}

class TasksLoading extends TasksState {
  const TasksLoading();
}

class TasksLoaded extends TasksState {
  final List<MockTaskItem> tasks;
  final String searchQuery;
  final String? statusFilter;
  final String? priorityFilter;

  const TasksLoaded({
    required this.tasks,
    this.searchQuery = '',
    this.statusFilter,
    this.priorityFilter,
  });

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      statusFilter != null ||
      priorityFilter != null;

  @override
  List<Object?> get props => [tasks, searchQuery, statusFilter, priorityFilter];
}

class TasksError extends TasksState {
  final String message;
  const TasksError(this.message);

  @override
  List<Object?> get props => [message];
}