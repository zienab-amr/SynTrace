import 'package:flutter/material.dart';

import 'package:syntrace/shared/widgets/design_system/design_system.dart';

import '../../../data/models/project_team_member.dart';

class ProjectReviewStep extends StatelessWidget {
  final String name;
  final String description;
  final String clientName;

  final List<ProjectTeamMember> members;

  final String? githubRepository;
  final String? jiraProject;

  final ValueChanged<int> onEdit;

  const ProjectReviewStep({
    super.key,
    required this.name,
    required this.description,
    required this.clientName,
    required this.members,
    required this.githubRepository,
    required this.jiraProject,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Ready to launch?',
          subtitle: 'Review your project configuration before creating it.',
        ),

        const SizedBox(height: 24),

        _ReviewCard(
          title: 'Project details',
          icon: Icons.folder_outlined,
          onEdit: () => onEdit(0),
          children: [
            _ReviewValue(label: 'Project name', value: name),
            _ReviewValue(label: 'Client', value: clientName),
            _ReviewValue(
              label: 'Description',
              value: description.trim().isEmpty
                  ? 'No description provided'
                  : description,
            ),
          ],
        ),

        const SizedBox(height: 16),

        _ReviewCard(
          title: 'Project team',
          icon: Icons.groups_outlined,
          onEdit: () => onEdit(1),
          children: [
            Text('${members.length} selected members'),

            if (members.isEmpty) const Text('Team members can be added later.'),

            for (final member in members) _ReviewMember(member: member),
          ],
        ),

        const SizedBox(height: 16),

        _ReviewCard(
          title: 'Integrations',
          icon: Icons.link_rounded,
          onEdit: () => onEdit(2),
          children: [
            _ReviewValue(
              label: 'GitHub',
              value: githubRepository ?? 'Not selected',
            ),
            _ReviewValue(label: 'Jira', value: jiraProject ?? 'Not selected'),
          ],
        ),

        const SizedBox(height: 20),

        const _ReviewNotice(),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onEdit;
  final List<Widget> children;

  const _ReviewCard({
    required this.title,
    required this.icon,
    required this.onEdit,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 16),

          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _ReviewValue extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _ReviewMember extends StatelessWidget {
  final ProjectTeamMember member;

  const _ReviewMember({required this.member});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.name, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(member.role.label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice();

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
            'Your project will be created first. '
            'Team assignments and selected integrations '
            'will be configured afterwards.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
