import 'package:flutter/material.dart';

import '../../../../data/models/project_team_member.dart';

class ChangeProjectRoleDialog extends StatefulWidget {
  final ProjectTeamMember member;

  const ChangeProjectRoleDialog({super.key, required this.member});

  static Future<ProjectMemberRole?> show(
    BuildContext context,
    ProjectTeamMember member,
  ) {
    return showDialog<ProjectMemberRole>(
      context: context,
      builder: (_) => ChangeProjectRoleDialog(member: member),
    );
  }

  @override
  State<ChangeProjectRoleDialog> createState() =>
      _ChangeProjectRoleDialogState();
}

class _ChangeProjectRoleDialogState extends State<ChangeProjectRoleDialog> {
  late ProjectMemberRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.member.role;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change project role'),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.member.name,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<ProjectMemberRole>(
            initialValue: _selectedRole,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Project role'),
            items: ProjectMemberRole.values.map((role) {
              return DropdownMenuItem(value: role, child: Text(role.label));
            }).toList(),
            onChanged: (role) {
              if (role == null) return;

              setState(() {
                _selectedRole = role;
              });
            },
          ),
        ],
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),

        FilledButton(
          onPressed: _selectedRole == widget.member.role
              ? null
              : () => Navigator.of(context).pop(_selectedRole),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
