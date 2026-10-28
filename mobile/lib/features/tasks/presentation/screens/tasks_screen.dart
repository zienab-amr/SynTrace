import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/tasks/presentation/cubit/tasks_cubit.dart';
import 'package:syntrace/features/tasks/presentation/cubit/tasks_state.dart';
import 'package:syntrace/features/tasks/presentation/widgets/task_card.dart';
import 'package:syntrace/features/tasks/presentation/widgets/task_filters.dart';
import 'package:syntrace/shared/widgets/empty_state_view.dart';
import 'package:syntrace/shared/widgets/error_state_view.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<TasksCubit>().loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Tasks',
      subtitle: 'Manage all tasks across your projects',
      searchBar: _buildSearchBar(),
      filterBar: BlocBuilder<TasksCubit, TasksState>(
        builder: (context, state) {
          final statusFilter =
              state is TasksLoaded ? state.statusFilter : null;
          final priorityFilter =
              state is TasksLoaded ? state.priorityFilter : null;
          final hasActiveFilters =
              state is TasksLoaded && state.hasActiveFilters;

          return TaskFilters(
            statusFilter: statusFilter,
            priorityFilter: priorityFilter,
            hasActiveFilters: hasActiveFilters,
            onStatusChanged: (value) =>
                context.read<TasksCubit>().setStatusFilter(value),
            onPriorityChanged: (value) =>
                context.read<TasksCubit>().setPriorityFilter(value),
            onClearAll: () {
              _searchController.clear();
              context.read<TasksCubit>().clearFilters();
            },
          );
        },
      ),
      child: BlocBuilder<TasksCubit, TasksState>(
        builder: (context, state) {
          if (state is TasksLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is TasksError) {
            return ErrorStateView(
              message: state.message,
              onRetry: () => context.read<TasksCubit>().loadTasks(),
            );
          }

          if (state is TasksLoaded) {
            if (state.tasks.isEmpty) {
              return EmptyStateView(
                icon: state.hasActiveFilters
                    ? Icons.search_off
                    : Icons.task_alt,
                title: state.hasActiveFilters
                    ? 'No tasks match your filters'
                    : 'No tasks yet',
                message: state.hasActiveFilters
                    ? 'Try adjusting your search or filters'
                    : 'Tasks will appear here',
                actionLabel:
                    state.hasActiveFilters ? 'Clear filters' : null,
                onAction: state.hasActiveFilters
                    ? () {
                        _searchController.clear();
                        context.read<TasksCubit>().clearFilters();
                      }
                    : null,
              );
            }

            return _buildTasksList(state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTasksList(TasksLoaded state) {
    return RefreshIndicator(
      onRefresh: () => context.read<TasksCubit>().loadTasks(),
      color: AppColors.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 115,
              ),
              itemCount: state.tasks.length,
              itemBuilder: (context, index) =>
                  TaskCard(task: state.tasks[index]),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                TaskCard(task: state.tasks[index]),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                context.read<TasksCubit>().search(value);
              },
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                context.read<TasksCubit>().search('');
              },
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                size: 18,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}