import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/features/projects/presentation/widgets/projects_filters.dart';

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

        return BlocBuilder<ProjectsCubit, ProjectsState>(
          builder: (context, state) {
            return AppPageScaffold(
              title: 'Projects',
              subtitle: 'Your engineering workspace',
              scrollable: false,
              actions: [
                IconButton(
                  tooltip: 'Clients',
                  icon: const Icon(Icons.business_outlined),
                  onPressed: () => context.push('/projects/clients'),
                ),
                if (isAdmin) const CreateButton(),
              ],
              searchBar: _buildSearchBar(),
              filterBar: state is ProjectsLoaded
                  ? ProjectStatusFilter(
                      selectedStatus: state.selectedStatus,
                      onChanged: context.read<ProjectsCubit>().filterByStatus,
                    )
                  : null,
              child: _buildContent(state, isAdmin),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(ProjectsState state, bool isAdmin) {
    if (state is ProjectsInitial || state is ProjectsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ProjectsError) {
      return ErrorStateView(
        message: state.message,
        onRetry: context.read<ProjectsCubit>().refresh,
      );
    }

    if (state is ProjectsLoaded) {
      if (state.projects.isEmpty) {
        return _buildEmptyState(state, isAdmin);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProjectsResultHeader(
            visibleCount: state.projects.length,
            totalCount: state.totalCount ?? state.projects.length,
            hasFilters: state.hasActiveFilters,
            onRefresh: context.read<ProjectsCubit>().refresh,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ProjectsGrid(
              projects: state.projects,
              onRefresh: context.read<ProjectsCubit>().refresh,
              onProjectTap: (project) {
                context.go(AppRoutes.projectDetailsById(project.id));
              },
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState(ProjectsLoaded state, bool isAdmin) {
    final hasFilters = state.hasActiveFilters;

    return EmptyStateView(
      icon: hasFilters ? Icons.search_off_rounded : Icons.folder_open_outlined,
      title: hasFilters ? 'No matching projects' : 'No projects yet',
      message: hasFilters
          ? 'Try another search or change the status filter.'
          : isAdmin
          ? 'Create a project to get started.'
          : 'No projects are currently available to you.',
      actionLabel: hasFilters ? 'Clear filters' : 'Refresh',
      onAction: () {
        if (hasFilters) {
          _clearFilters();
        } else {
          context.read<ProjectsCubit>().refresh();
        }
      },
    );
  }

  Widget _buildSearchBar() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        return TextField(
          controller: _searchController,
          onChanged: context.read<ProjectsCubit>().search,
          decoration: InputDecoration(
            hintText: 'Search projects...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();

                      context.read<ProjectsCubit>().search('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        );
      },
    );
  }

  void _clearFilters() {
    _searchController.clear();

    context.read<ProjectsCubit>().clearFilters();
  }
}

class _ProjectsResultHeader extends StatelessWidget {
  final int visibleCount;
  final int totalCount;
  final bool hasFilters;
  final VoidCallback onRefresh;

  const _ProjectsResultHeader({
    required this.visibleCount,
    required this.totalCount,
    required this.hasFilters,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            hasFilters
                ? '$visibleCount of $totalCount projects'
                : '$totalCount projects',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Refresh projects',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
      ],
    );
  }
}
