import 'package:flutter/material.dart';

import 'package:syntrace/features/employees/data/models/employee_model.dart';
import 'package:syntrace/shared/widgets/design_system/design_system.dart';

import '../../../data/models/project_team_member.dart';

class ProjectTeamStep extends StatefulWidget {
  final List<EmployeeModel> employees;
  final List<ProjectTeamMember> selectedMembers;

  final ValueChanged<List<ProjectTeamMember>> onChanged;

  const ProjectTeamStep({
    super.key,
    required this.employees,
    required this.selectedMembers,
    required this.onChanged,
  });

  @override
  State<ProjectTeamStep> createState() => _ProjectTeamStepState();
}

class _ProjectTeamStepState extends State<ProjectTeamStep> {
  String _query = '';

  List<EmployeeModel> get _filteredEmployees {
    final query = _query.trim().toLowerCase();

    return widget.employees.where((employee) {
      return employee.id.isNotEmpty &&
          (query.isEmpty ||
              employee.fullName.toLowerCase().contains(query) ||
              employee.email.toLowerCase().contains(query));
    }).toList();
  }

  void _toggleEmployee(EmployeeModel employee) {
    final members = [...widget.selectedMembers];

    final index = members.indexWhere(
      (member) => member.employeeId == employee.id,
    );

    if (index >= 0) {
      members.removeAt(index);
    } else {
      members.add(
        ProjectTeamMember(
          employeeId: employee.id,
          name: employee.fullName,
          email: employee.email,
        ),
      );
    }

    widget.onChanged(members);
  }

  void _changeRole(String employeeId, ProjectMemberRole role) {
    widget.onChanged(
      widget.selectedMembers.map((member) {
        return member.employeeId == employeeId
            ? member.copyWith(role: role)
            : member;
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final employees = _filteredEmployees;

    final selectedById = {
      for (final member in widget.selectedMembers) member.employeeId: member,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'Build your team',
          subtitle: 'Select employees and assign their project roles.',
        ),
        const SizedBox(height: 20),

        AppCard(
          child: Row(
            children: [
              Icon(
                Icons.groups_outlined,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.selectedMembers.length} members selected',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        TextField(
          onChanged: (value) {
            setState(() => _query = value);
          },
          decoration: const InputDecoration(
            hintText: 'Search employees...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),

        const SizedBox(height: 20),

        if (employees.isEmpty)
          AppCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  widget.employees.isEmpty
                      ? 'No employees available.'
                      : 'No matching employees.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: employees.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final employee = employees[index];
              final selected = selectedById[employee.id];

              return _EmployeeSelectionCard(
                employee: employee,
                selectedMember: selected,
                onToggle: () => _toggleEmployee(employee),
                onRoleChanged: (role) {
                  _changeRole(employee.id, role);
                },
              );
            },
          ),
      ],
    );
  }
}

class _EmployeeSelectionCard extends StatelessWidget {
  final EmployeeModel employee;
  final ProjectTeamMember? selectedMember;

  final VoidCallback onToggle;
  final ValueChanged<ProjectMemberRole> onRoleChanged;

  const _EmployeeSelectionCard({
    required this.employee,
    required this.selectedMember,
    required this.onToggle,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isSelected = selectedMember != null;

    return AppCard(
      selected: isSelected,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    employee.initials,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        employee.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Checkbox(value: isSelected, onChanged: (_) => onToggle()),
              ],
            ),
          ),
          if (isSelected) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            DropdownButtonFormField<ProjectMemberRole>(
              initialValue: selectedMember!.role,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Project role',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: ProjectMemberRole.values.map((role) {
                return DropdownMenuItem<ProjectMemberRole>(
                  value: role,
                  child: Text(role.label),
                );
              }).toList(),
              onChanged: (role) {
                if (role != null) {
                  onRoleChanged(role);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
