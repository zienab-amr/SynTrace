import 'package:flutter/material.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/features/role/data/roles_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/features/employees/data/models/employee_model.dart';
import 'package:syntrace/features/employees/presentation/cubit/employees_cubit.dart';
import 'package:syntrace/features/employees/presentation/cubit/employees_state.dart';
import 'package:syntrace/features/employees/presentation/screens/add_employee_screen.dart';
import 'package:syntrace/shared/widgets/design_system/design_system.dart';

class AllEmployeesScreen extends StatefulWidget {
  const AllEmployeesScreen({super.key});

  @override
  State<AllEmployeesScreen> createState() => _AllEmployeesScreenState();
}

class _AllEmployeesScreenState extends State<AllEmployeesScreen> {
  final _searchController = TextEditingController();

  String _query = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final cubit = context.read<EmployeesCubit>();

      if (cubit.state is EmployeesInitial) {
        cubit.loadEmployees();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddMember() async {
    final cubit = context.read<EmployeesCubit>();

    final scope = CacheScope.fromCurrentUser();
    if (scope == null ||
        !cubit.canManage ||
        cubit.isBusy ||
        cubit.state is! EmployeesLoaded ||
        (cubit.state as EmployeesLoaded).isFromCache) {
      return;
    }
    final guard = CacheSessionGuard.capture(scope);

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            BlocProvider.value(value: cubit, child: const AddEmployeeScreen()),
      ),
    );

    if (!mounted || !guard.isValid) return;

    if (created == true) {
      _showMessage('Member created successfully.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _changeRole(EmployeeModel employee) async {
    final cubit = context.read<EmployeesCubit>();
    final scope = CacheScope.fromCurrentUser();
    if (scope == null || !cubit.canManage || cubit.isBusy) return;
    final guard = CacheSessionGuard.capture(scope);
    if (employee.rolesById.length != employee.roleNames.length) {
      _showMessage('Refresh the directory to verify existing role IDs.');
      return;
    }
    final result = await RolesRepository().getAllRoles();
    if (!mounted || !guard.isValid || !cubit.canManage) return;
    if (!result.success) {
      _showMessage('Unable to load workspace roles.');
      return;
    }
    final roles = <String, String>{
      for (final r in result.data ?? [])
        if (!employee.rolesById.containsKey(r.id)) r.id: r.name,
    };
    if (roles.isEmpty) {
      _showMessage('No replacement roles available.');
      return;
    }
    final selection = await showDialog<(String?, String)>(
      context: context,
      builder: (_) => _ChangeRoleDialog(employee: employee, roles: roles),
    );
    if (!mounted || !guard.isValid || selection == null) return;
    final success = await cubit.changeRole(
      employee.id,
      selection.$2,
      previousRoleId: selection.$1,
    );

    if (!mounted || !guard.isValid) return;

    if (success) {
      _showMessage('Member role updated.');
    }
  }

  Future<void> _deleteMember(EmployeeModel employee) async {
    final cubit = context.read<EmployeesCubit>();

    final scope = CacheScope.fromCurrentUser();
    if (scope == null || !cubit.canManage || cubit.isBusy) return;
    final guard = CacheSessionGuard.capture(scope);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove member?'),
          content: Text(
            'Remove ${employee.fullName} from '
            'your workspace? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (!mounted || !guard.isValid || confirmed != true || !cubit.canManage) {
      return;
    }

    final success = await cubit.deleteEmployee(employee.id);

    if (!mounted || !guard.isValid) return;

    if (success) {
      _showMessage('Member removed successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Session unavailable.')),
          );
        }

        final isAdmin = user.role == UserRole.admin;

        return Scaffold(
          appBar: AppBar(title: const Text('Team members')),
          body: SafeArea(
            child: BlocBuilder<EmployeesCubit, EmployeesState>(
              builder: (context, state) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSectionHeader(
                            title: 'Your team',
                            subtitle: state is EmployeesLoaded
                                ? '${state.employees.length} '
                                      'workspace members'
                                : 'Manage workspace access',
                          ),
                          if (isAdmin) ...[
                            const SizedBox(height: 16),
                            AppButton(
                              label: 'Add member',
                              icon: Icons.person_add_outlined,
                              onPressed:
                                  state is EmployeesLoaded && !state.isFromCache
                                  ? _openAddMember
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 20),
                          TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _query = value.trim().toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search members...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _searchController.clear();

                                        setState(() {
                                          _query = '';
                                        });
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildContent(state, user)),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(EmployeesState state, UserModel user) {
    if (state is EmployeesLoading || state is EmployeesInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is EmployeesError) {
      return _EmployeesFeedback(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load members',
        message: state.message,
        actionLabel: 'Try again',
        onAction: context.read<EmployeesCubit>().loadEmployees,
      );
    }

    if (state is! EmployeesLoaded) {
      return const SizedBox.shrink();
    }

    final employees = state.employees.where((employee) {
      return _query.isEmpty ||
          employee.fullName.toLowerCase().contains(_query) ||
          employee.email.toLowerCase().contains(_query) ||
          employee.role.toLowerCase().contains(_query);
    }).toList();

    if (employees.isEmpty) {
      return _EmployeesFeedback(
        icon: _query.isEmpty ? Icons.people_outline : Icons.search_off,
        title: _query.isEmpty ? 'No members yet' : 'No matching members',
        message: _query.isEmpty
            ? 'No team members were returned.'
            : 'Try a different name, email or role.',
        actionLabel: _query.isEmpty ? 'Refresh' : 'Clear search',
        onAction: _query.isEmpty
            ? context.read<EmployeesCubit>().refresh
            : () {
                _searchController.clear();

                setState(() => _query = '');
              },
      );
    }

    return Column(
      children: [
        if (state.isFromCache)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Saved data — read only'),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: context.read<EmployeesCubit>().refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: employees.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final employee = employees[index];

                final isCurrentUser = employee.id == user.id;

                return _EmployeeCard(
                  employee: employee,
                  isCurrentUser: isCurrentUser,
                  canManage:
                      !state.isFromCache &&
                      user.role == UserRole.admin &&
                      !isCurrentUser &&
                      employee.id.isNotEmpty,
                  onChangeRole: () => _changeRole(employee),
                  onDelete: () => _deleteMember(employee),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  final bool isCurrentUser;
  final bool canManage;
  final VoidCallback onChangeRole;
  final VoidCallback onDelete;

  const _EmployeeCard({
    required this.employee,
    required this.isCurrentUser,
    required this.canManage,
    required this.onChangeRole,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Text(
              employee.initials.isEmpty ? '?' : employee.initials,
              style: TextStyle(
                color: scheme.primary,
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
                  employee.fullName.isEmpty
                      ? employee.email
                      : employee.fullName,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  employee.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    AppStatusBadge(
                      label: employee.role,
                      tone: employee.role.toLowerCase() == 'admin'
                          ? AppStatusTone.info
                          : AppStatusTone.neutral,
                      showDot: false,
                    ),
                    if (isCurrentUser)
                      const AppStatusBadge(
                        label: 'You',
                        tone: AppStatusTone.neutral,
                        showDot: false,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              tooltip: 'Manage member',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'role') onChangeRole();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'role', child: Text('Change role')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Remove member',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChangeRoleDialog extends StatefulWidget {
  final EmployeeModel employee;
  final Map<String, String> roles;
  const _ChangeRoleDialog({required this.employee, required this.roles});
  @override
  State<_ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<_ChangeRoleDialog> {
  String? previous;
  String? next;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.employee.rolesById.isEmpty
          ? 'Assign workspace role'
          : 'Replace workspace role',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.employee.fullName),
          if (widget.employee.rolesById.isNotEmpty)
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Existing role'),
              items: widget.employee.rolesById.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => previous = v),
            ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Replacement role'),
            items: widget.roles.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => next = v),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed:
            (widget.employee.rolesById.isNotEmpty && previous == null) ||
                next == null
            ? null
            : () => Navigator.pop(context, (previous, next!)),
        child: Text(widget.employee.rolesById.isEmpty ? 'Assign' : 'Replace'),
      ),
    ],
  );
}

class _EmployeesFeedback extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmployeesFeedback({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: actionLabel,
              fullWidth: false,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}
