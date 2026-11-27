import 'package:flutter/material.dart';

import '../../../../data/models/project_team_member.dart';

enum ProjectMemberAction { changeRole, remove }

class ProjectMemberTile extends StatelessWidget {
  final ProjectTeamMember member;
  final bool canManage;
  final bool isBusy;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;

  const ProjectMemberTile({
    super.key,
    required this.member,
    required this.canManage,
    required this.isBusy,
    required this.onChangeRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: Text(
              member.initials,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  member.role.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          if (canManage)
            PopupMenuButton<ProjectMemberAction>(
              enabled: !isBusy,
              tooltip: 'Manage member',
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (action) {
                switch (action) {
                  case ProjectMemberAction.changeRole:
                    onChangeRole();
                    break;

                  case ProjectMemberAction.remove:
                    onRemove();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: ProjectMemberAction.changeRole,
                  child: Row(
                    children: [
                      Icon(Icons.manage_accounts_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Change role'),
                    ],
                  ),
                ),

                PopupMenuItem(
                  value: ProjectMemberAction.remove,
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        size: 18,
                        color: colors.error,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Remove member',
                        style: TextStyle(color: colors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
