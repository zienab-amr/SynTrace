import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import 'package:syntrace/shared/widgets/empty_state_view.dart';
import 'package:syntrace/shared/widgets/error_state_view.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

import '../cubit/projects_cubit.dart';
import '../cubit/projects_state.dart';

import '../widgets/create_buttom.dart';
import '../widgets/projects_grid.dart';

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
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,

      builder: (context, user, _) {
        final isAdmin = user?.isAdmin ?? false;

        return AppPageScaffold(
          title: 'Projects',

          actions: [if (isAdmin) const CreateButton()],

          searchBar: _buildSearchBar(),

          child: BlocBuilder<ProjectsCubit, ProjectsState>(
            builder: (context, state) {
              if (state is ProjectsLoading || state is ProjectsInitial) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is ProjectsError) {
                return ErrorStateView(
                  message: state.message,

                  onRetry: () {
                    context.read<ProjectsCubit>().refresh();
                  },
                );
              }

              if (state is ProjectsLoaded) {
                if (state.projects.isEmpty) {
                  return _buildEmptyState(state, isAdmin);
                }

                return ProjectsGrid(
                  projects: state.projects,

                  onRefresh: () {
                    return context.read<ProjectsCubit>().refresh();
                  },

                  onProjectTap: (project) {
                    context.go(AppRoutes.projectDetailsById(project.id));
                  },
                );
              }

              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // Empty State
  // ═══════════════════════════════════════════

  Widget _buildEmptyState(ProjectsLoaded state, bool isAdmin) {
    final hasSearch = state.hasActiveFilters;

    return EmptyStateView(
      icon: hasSearch ? Icons.search_off_rounded : Icons.folder_open_outlined,

      title: hasSearch ? 'No matching projects' : 'No projects yet',

      message: hasSearch
          ? 'Try a different search term.'
          : isAdmin
          ? 'Create a project to get started.'
          : 'No projects are currently '
                'assigned to you.',

      actionLabel: hasSearch ? 'Clear search' : 'Refresh',

      onAction: () {
        if (hasSearch) {
          _clearSearch();
        } else {
          context.read<ProjectsCubit>().refresh();
        }
      },
    );
  }

  // ═══════════════════════════════════════════
  // Search
  // ═══════════════════════════════════════════

  Widget _buildSearchBar() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,

      builder: (context, value, _) {
        return TextField(
          controller: _searchController,

          onChanged: (query) {
            context.read<ProjectsCubit>().search(query);
          },

          decoration: InputDecoration(
            hintText: 'Search projects...',

            prefixIcon: const Icon(Icons.search_rounded),

            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close_rounded),
                  ),

            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),

            isDense: true,
          ),
        );
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();

    context.read<ProjectsCubit>().clearFilters();
  }
}
