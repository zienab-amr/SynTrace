import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:syntrace/features/projects/presentation/cubit/projects_state.dart';
import 'package:syntrace/features/projects/presentation/widgets/create_buttom.dart';
import 'package:syntrace/features/projects/presentation/widgets/projects_filters.dart';
import 'package:syntrace/features/projects/presentation/widgets/projects_grid.dart';
import 'package:syntrace/shared/widgets/empty_state_view.dart';
import 'package:syntrace/shared/widgets/error_state_view.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ProjectsCubit>().loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Projects',
      subtitle: 'roudiiiii',
      actions: const [CreateButton()],
      searchBar: _buildSearchBar(),
      filterBar: BlocBuilder<ProjectsCubit, ProjectsState>(
        builder: (context, state) {
          final statusFilter =
              state is ProjectsLoaded ? state.statusFilter : null;
          final hasActiveFilters =
              state is ProjectsLoaded && state.hasActiveFilters;

          return ProjectsFilters(
            statusFilter: statusFilter,
            hasActiveFilters: hasActiveFilters,
            onStatusChanged: (value) {
              context.read<ProjectsCubit>().setStatusFilter(value);
            },
            onRiskChanged: (value) {
              context.read<ProjectsCubit>().setRiskFilter(value);
            },
            onClearAll: () {
              _searchController.clear();
              context.read<ProjectsCubit>().clearFilters();
            },
          );
        },
      ),
      child: BlocBuilder<ProjectsCubit, ProjectsState>(
        builder: (context, state) {
          if (state is ProjectsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is ProjectsError) {
            return ErrorStateView(
              message: state.message,
              onRetry: () => context.read<ProjectsCubit>().refresh(),
            );
          }

          if (state is ProjectsLoaded) {
            if (state.projects.isEmpty) {
              return EmptyStateView(
                icon: state.hasActiveFilters
                    ? Icons.search_off
                    : Icons.folder_open_outlined,
                title: state.hasActiveFilters
                    ? 'No projects match your filters'
                    : 'No projects yet',
                message: state.hasActiveFilters
                    ? 'Try adjusting your search or filters'
                    : 'Create your first project to get started',
                actionLabel:
                    state.hasActiveFilters ? 'Clear filters' : null,
                onAction: state.hasActiveFilters
                    ? () {
                        _searchController.clear();
                        context.read<ProjectsCubit>().clearFilters();
                      }
                    : null,
              );
            }

            return ProjectsGrid(
              projects: state.projects,
              onRefresh: () => context.read<ProjectsCubit>().refresh(),
              onProjectTap: (project) {
                context.go(AppRoutes.projectDetailsById(project.id));
              },
            );
          }

          return const SizedBox.shrink();
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
                context.read<ProjectsCubit>().search(value);
              },
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search projects...',
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
                context.read<ProjectsCubit>().search('');
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