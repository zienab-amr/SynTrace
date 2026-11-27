import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/features/settings/data/models/github_model.dart';
import 'package:syntrace/shared/widgets/design_system/design_system.dart';

import '../../../data/models/project_api_model.dart';

import '../../cubit/project_setup_cubit.dart';
import '../../cubit/project_setup_state.dart';

class ProjectIntegrationsStep extends StatelessWidget {
  final GitHubRepositoryOption? selectedRepository;
  final JiraProjectOption? selectedJiraProject;

  final ValueChanged<GitHubRepositoryOption?> onGitHubChanged;
  final ValueChanged<JiraProjectOption?> onJiraChanged;

  const ProjectIntegrationsStep({
    super.key,
    required this.selectedRepository,
    required this.selectedJiraProject,
    required this.onGitHubChanged,
    required this.onJiraChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectSetupCubit, ProjectSetupState>(
      builder: (context, state) {
        final cubit = context.read<ProjectSetupCubit>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              title: 'Connect your tools',
              subtitle: 'Link your engineering tools to this project.',
            ),
            const SizedBox(height: 24),

            _IntegrationSelector<GitHubRepositoryOption>(
              title: 'GitHub',
              description: 'Connect source code, commits and pull requests.',
              icon: Icons.code_rounded,
              placeholder: 'Select a repository',
              emptyMessage: 'No repositories available.',
              options: state.github,
              selected: selectedRepository,
              itemKey: (item) => item.repositoryId.toString(),
              itemLabel: (item) => item.fullName,
              onChanged: onGitHubChanged,
              onRetry: cubit.loadGitHubRepositories,
            ),

            const SizedBox(height: 16),

            _IntegrationSelector<JiraProjectOption>(
              title: 'Jira',
              description: 'Connect project issues and development tasks.',
              icon: Icons.task_alt_rounded,
              placeholder: 'Select a Jira project',
              emptyMessage: 'No Jira projects available.',
              options: state.jira,
              selected: selectedJiraProject,
              itemKey: (item) => item.id,
              itemLabel: (item) => '${item.key} · ${item.name}',
              onChanged: onJiraChanged,
              onRetry: cubit.loadJiraProjects,
            ),

            const SizedBox(height: 20),

            const _OptionalIntegrationNotice(),
          ],
        );
      },
    );
  }
}

class _IntegrationSelector<T> extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String placeholder;
  final String emptyMessage;

  final SetupOptions<T> options;
  final T? selected;

  final String Function(T) itemKey;
  final String Function(T) itemLabel;

  final ValueChanged<T?> onChanged;
  final VoidCallback onRetry;

  const _IntegrationSelector({
    required this.title,
    required this.description,
    required this.icon,
    required this.placeholder,
    required this.emptyMessage,
    required this.options,
    required this.selected,
    required this.itemKey,
    required this.itemLabel,
    required this.onChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final items = <String, T>{
      for (final item in options.items) itemKey(item): item,
    };

    final selectedItem = selected;

    final selectedKey = selectedItem == null ? null : itemKey(selectedItem);

    final validSelection =
        selectedKey != null && items.containsKey(selectedKey);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              const AppStatusBadge(
                label: 'Optional',
                tone: AppStatusTone.neutral,
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(description, style: theme.textTheme.bodyMedium),

          const SizedBox(height: 20),

          if (options.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (options.hasError)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  options.error ?? 'Unable to load options.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            )
          else if (items.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emptyMessage, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey('$selectedKey:${items.keys.join(",")}'),
              initialValue: validSelection ? selectedKey : null,
              isExpanded: true,
              decoration: InputDecoration(hintText: placeholder),
              items: items.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    itemLabel(entry.value),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                onChanged(items[value]);
              },
            ),

          if (selected != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Remove selection'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionalIntegrationNotice extends StatelessWidget {
  const _OptionalIntegrationNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'You can skip integrations now and connect '
            'your tools later from project settings.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
