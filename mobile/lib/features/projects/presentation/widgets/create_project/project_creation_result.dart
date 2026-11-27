import 'package:flutter/material.dart';

import 'package:syntrace/shared/widgets/design_system/design_system.dart';

class ProjectCreationResult extends StatelessWidget {
  final String projectName;

  final int completedMembers;
  final int totalMembers;

  final bool githubRequested;
  final bool githubMapped;

  final bool jiraRequested;
  final bool jiraMapped;

  final String? message;

  final VoidCallback onOpenProject;

  const ProjectCreationResult({
    super.key,
    required this.projectName,
    required this.completedMembers,
    required this.totalMembers,
    required this.githubRequested,
    required this.githubMapped,
    required this.jiraRequested,
    required this.jiraMapped,
    required this.onOpenProject,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),

          const SizedBox(height: 20),

          Text(
            'Project created',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),

          const SizedBox(height: 8),

          Text(
            projectName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),

          const SizedBox(height: 24),

          const _ResultItem(label: 'Project creation', completed: true),

          const SizedBox(height: 16),

          _ResultItem(
            label: 'Team ($completedMembers/$totalMembers)',
            completed: completedMembers == totalMembers,
          ),

          if (githubRequested) ...[
            const SizedBox(height: 16),
            _ResultItem(label: 'GitHub repository', completed: githubMapped),
          ],

          if (jiraRequested) ...[
            const SizedBox(height: 16),
            _ResultItem(label: 'Jira project', completed: jiraMapped),
          ],

          if (message != null) ...[
            const SizedBox(height: 24),
            Text(message!, style: theme.textTheme.bodyMedium),
          ],

          const SizedBox(height: 24),

          AppButton(
            label: 'Open project',
            icon: Icons.arrow_forward_rounded,
            onPressed: onOpenProject,
          ),
        ],
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final bool completed;

  const _ResultItem({required this.label, required this.completed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        AppStatusBadge(
          label: completed ? 'Completed' : 'Not confirmed',
          tone: completed ? AppStatusTone.success : AppStatusTone.warning,
        ),
      ],
    );
  }
}
