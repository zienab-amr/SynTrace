import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/features/settings/data/models/github_model.dart';

import '../../cubit/github/project_github_cubit.dart';
import '../../cubit/github/project_github_state.dart';

import 'picker/github_picker_header.dart';
import 'picker/github_picker_search.dart';
import 'picker/github_repository_list.dart';
import 'picker/github_picker_empty.dart';
import 'picker/github_picker_error.dart';

class GitHubRepositoryPicker extends StatefulWidget {
  const GitHubRepositoryPicker({super.key});

  static Future<GitHubRepositoryOption?> show(BuildContext context) {
    final cubit = context.read<ProjectGitHubCubit>();

    return showModalBottomSheet<GitHubRepositoryOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const GitHubRepositoryPicker(),
      ),
    );
  }

  @override
  State<GitHubRepositoryPicker> createState() => _GitHubRepositoryPickerState();
}

class _GitHubRepositoryPickerState extends State<GitHubRepositoryPicker> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<ProjectGitHubCubit>().loadRepositories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // Search
  // ═══════════════════════════════════════════

  List<GitHubRepositoryOption> _filterRepositories(
    List<GitHubRepositoryOption> repositories,
  ) {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) return repositories;

    return repositories.where((repository) {
      return repository.fullName.toLowerCase().contains(query) ||
          repository.owner.toLowerCase().contains(query) ||
          repository.name.toLowerCase().contains(query) ||
          (repository.defaultBranch ?? '').toLowerCase().contains(query);
    }).toList();
  }

  // ═══════════════════════════════════════════
  // Main UI
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GitHubPickerHeader(),

                const SizedBox(height: 8),

                Text(
                  'Choose a GitHub repository to '
                  'connect to this project.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 20),

                GitHubPickerSearch(
                  controller: _searchController,
                  query: _query,
                  onChanged: (value) => setState(() => _query = value),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: BlocBuilder<ProjectGitHubCubit, ProjectGitHubState>(
                    builder: (context, state) {
                      return _buildContent(state);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ProjectGitHubState state) {
    if (state.isLoadingRepositories ||
        state.repositoriesStatus == ProjectGitHubRequestStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.repositoriesStatus == ProjectGitHubRequestStatus.failure) {
      return GitHubPickerError(
        message: state.repositoriesError ?? 'Please try again.',
        onRetry: () => context.read<ProjectGitHubCubit>().loadRepositories(),
      );
    }

    if (state.repositories.isEmpty) {
      return const GitHubPickerEmpty(
        icon: Icons.folder_off_outlined,
        title: 'No repositories available',
        description:
            'Make sure your company GitHub account '
            'is connected and has repository access.',
      );
    }

    final repositories = _filterRepositories(state.repositories);

    if (repositories.isEmpty) {
      return const GitHubPickerEmpty(
        icon: Icons.search_off_rounded,
        title: 'No matching repositories',
        description: 'Try a different search term.',
      );
    }

    return GitHubRepositoryList(
      repositories: repositories,
      total: state.repositories.length,
      onRefresh: () => context.read<ProjectGitHubCubit>().loadRepositories(),
      onSelected: (repository) => Navigator.pop(context, repository),
    );
  }
}
