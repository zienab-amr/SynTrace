import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';
import 'tasks_state.dart';

class TasksCubit extends Cubit<TasksState> {
  TasksCubit() : super(const TasksInitial());

  List<MockTaskItem> _allTasks = [];
  String _searchQuery = '';
  String? _statusFilter;
  String? _priorityFilter;

  Future<void> loadTasks() async {
    emit(const TasksLoading());
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      _allTasks = MockTasks.tasks;
      _emitFiltered();
    } catch (e) {
      emit(TasksError('Failed to load tasks: $e'));
    }
  }

  void search(String query) {
    _searchQuery = query;
    _emitFiltered();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    _emitFiltered();
  }

  void setPriorityFilter(String? priority) {
    _priorityFilter = priority;
    _emitFiltered();
  }

  void clearFilters() {
    _searchQuery = '';
    _statusFilter = null;
    _priorityFilter = null;
    _emitFiltered();
  }

  void _emitFiltered() {
    var filtered = List<MockTaskItem>.from(_allTasks);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.id.toLowerCase().contains(q) ||
            t.assigneeName.toLowerCase().contains(q);
      }).toList();
    }

    if (_statusFilter != null) {
      filtered = filtered.where((t) => t.status == _statusFilter).toList();
    }

    if (_priorityFilter != null) {
      filtered = filtered.where((t) => t.priority == _priorityFilter).toList();
    }

    emit(TasksLoaded(
      tasks: filtered,
      searchQuery: _searchQuery,
      statusFilter: _statusFilter,
      priorityFilter: _priorityFilter,
    ));
  }
}