import 'package:flutter/material.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import 'package:syntrace/features/employees/data/employees_repository.dart';
import 'package:syntrace/features/employees/data/models/employee_model.dart';

import '../../../../data/models/project_team_member.dart';

class AddProjectMemberDialog extends StatefulWidget {
  final Set<String> existingMemberIds;

  const AddProjectMemberDialog({super.key, required this.existingMemberIds});

  static Future<ProjectTeamMember?> show(
    BuildContext context, {
    required Set<String> existingMemberIds,
  }) {
    return showDialog<ProjectTeamMember>(
      context: context,
      builder: (_) =>
          AddProjectMemberDialog(existingMemberIds: existingMemberIds),
    );
  }

  @override
  State<AddProjectMemberDialog> createState() => _AddProjectMemberDialogState();
}

class _AddProjectMemberDialogState extends State<AddProjectMemberDialog> {
  final _repository = EmployeesRepository();

  final _searchController = TextEditingController();

  final _owner = CurrentUserService.instance.user;

  List<EmployeeModel> _employees = [];

  EmployeeModel? _selectedEmployee;

  ProjectMemberRole _selectedRole = ProjectMemberRole.member;

  bool _isLoading = true;

  String? _error;

  bool get _hasValidSession {
    final current = CurrentUserService.instance.user;

    return _owner != null &&
        _owner.id.isNotEmpty &&
        _owner.tenantId?.isNotEmpty == true &&
        current?.id == _owner.id &&
        current?.tenantId == _owner.tenantId &&
        current?.role == UserRole.admin;
  }

  @override
  void initState() {
    super.initState();

    CurrentUserService.instance.userNotifier.addListener(_onSessionChanged);

    _loadEmployees();
  }

  void _onSessionChanged() {
    if (!mounted || _hasValidSession) return;

    setState(() {
      _employees = [];
      _selectedEmployee = null;
      _isLoading = false;
      _error = 'Your session or permissions have changed.';
    });
  }

  @override
  void dispose() {
    CurrentUserService.instance.userNotifier.removeListener(_onSessionChanged);

    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadEmployees() async {
    if (!_hasValidSession) {
      setState(() {
        _isLoading = false;
        _error = 'You cannot manage project members.';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _selectedEmployee = null;
    });

    try {
      final response = await _repository.getAllEmployees();

      if (!mounted || !_hasValidSession) return;

      final data = response.data;

      if (!response.success || data == null) {
        throw StateError('Unable to load employees.');
      }

      final employees = data.where((employee) {
        return employee.id.isNotEmpty &&
            !widget.existingMemberIds.contains(employee.id) &&
            (employee.companyId == null ||
                employee.companyId == _owner?.tenantId);
      }).toList();

      employees.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || !_hasValidSession) return;

      setState(() {
        _employees = [];
        _isLoading = false;
        _error = 'Unable to load employees. Please try again.';
      });
    }
  }

  List<EmployeeModel> get _filteredEmployees {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return _employees;

    return _employees.where((employee) {
      return employee.fullName.toLowerCase().contains(query) ||
          employee.email.toLowerCase().contains(query);
    }).toList();
  }

  void _submit() {
    final employee = _selectedEmployee;

    if (employee == null || !_hasValidSession) return;

    Navigator.of(context).pop(
      ProjectTeamMember(
        employeeId: employee.id,
        name: employee.fullName.isNotEmpty ? employee.fullName : employee.email,
        email: employee.email,
        role: _selectedRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add project member'),

      content: SizedBox(width: 420, height: 340, child: _buildContent(context)),

      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),

        FilledButton(
          onPressed:
              _selectedEmployee == null || _isLoading || !_hasValidSession
              ? null
              : _submit,
          child: const Text('Add member'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),

            const SizedBox(height: 8),

            if (_hasValidSession)
              TextButton(
                onPressed: _loadEmployees,
                child: const Text('Try again'),
              ),
          ],
        ),
      );
    }

    if (_employees.isEmpty) {
      return const Center(
        child: Text(
          'No additional employees available.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final employees = _filteredEmployees;

    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search employees',
            prefixIcon: Icon(Icons.search_rounded, size: 20),
            isDense: true,
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: employees.isEmpty
              ? const Center(child: Text('No matching employees.'))
              : ListView.builder(
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];

                    return _EmployeeOption(
                      employee: employee,
                      selected: _selectedEmployee?.id == employee.id,
                      onTap: () {
                        setState(() {
                          _selectedEmployee = employee;
                        });
                      },
                    );
                  },
                ),
        ),

        const SizedBox(height: 12),

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
    );
  }
}

class _EmployeeOption extends StatelessWidget {
  final EmployeeModel employee;
  final bool selected;
  final VoidCallback onTap;

  const _EmployeeOption({
    required this.employee,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      selected: selected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,

      leading: CircleAvatar(
        radius: 17,
        child: Text(
          employee.initials.isEmpty ? '?' : employee.initials,
          style: const TextStyle(fontSize: 12),
        ),
      ),

      title: Text(
        employee.fullName.isNotEmpty ? employee.fullName : employee.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),

      subtitle: Text(
        employee.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),

      trailing: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        size: 20,
        color: selected ? colors.primary : colors.onSurfaceVariant,
      ),
    );
  }
}
