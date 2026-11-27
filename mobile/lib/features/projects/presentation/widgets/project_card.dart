import 'package:flutter/material.dart';

import 'package:syntrace/shared/widgets/design_system/design_system.dart';

import '../../data/models/project_api_model.dart';

class ProjectCard extends StatelessWidget {
  final ProjectApiModel project;
  final VoidCallback? onTap;

  const ProjectCard({super.key, required this.project, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = project.description?.trim() ?? '';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _ProjectIcon(),
              const Spacer(),
              _ProjectStatusBadge(status: project.status),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            project.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description.isEmpty ? 'No description provided.' : description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ProjectIntegration(isLinked: project.hasJiraProject),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: scheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectIcon extends StatelessWidget {
  const _ProjectIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
      ),
      child: Icon(Icons.folder_copy_outlined, color: scheme.primary, size: 23),
    );
  }
}

class _ProjectStatusBadge extends StatelessWidget {
  final ProjectApiStatus? status;

  const _ProjectStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      ProjectApiStatus.inProgress => AppStatusTone.info,
      ProjectApiStatus.completed => AppStatusTone.success,
      ProjectApiStatus.onHold => AppStatusTone.warning,
      ProjectApiStatus.cancelled => AppStatusTone.error,
      _ => AppStatusTone.neutral,
    };

    return AppStatusBadge(
      label: status?.label ?? 'Status unavailable',
      tone: tone,
    );
  }
}

class _ProjectIntegration extends StatelessWidget {
  final bool isLinked;

  const _ProjectIntegration({required this.isLinked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          isLinked ? Icons.link_rounded : Icons.link_off_rounded,
          size: 18,
          color: isLinked ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            isLinked ? 'Jira linked' : 'Jira not linked',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isLinked ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
