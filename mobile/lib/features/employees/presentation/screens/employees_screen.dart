import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/employees/data/models/employee_model.dart';
import 'package:syntrace/features/employees/presentation/cubit/employees_cubit.dart';
import 'package:syntrace/features/employees/presentation/cubit/employees_state.dart';

class AllEmployeesScreen extends StatelessWidget {
  const AllEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('All Members'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: BlocConsumer<EmployeesCubit, EmployeesState>(
        listener: (context, state) {
          if (state is EmployeesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is EmployeesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is EmployeesLoaded) {
            if (state.employees.isEmpty) {
              return const Center(child: Text('No members found.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.employees.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final emp = state.employees[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _roleColor(emp.role).withOpacity(0.15),
                    child: Text(
                      emp.initials.isEmpty ? '?' : emp.initials,
                      style: TextStyle(
                        color: _roleColor(emp.role),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    emp.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${emp.email}\n${emp.role}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.blue,
                        ),
                        tooltip: 'Change Role',
                        onPressed: () => _showChangeRoleDialog(context, emp),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        tooltip: 'Delete',
                        onPressed: () => _showDeleteDialog(context, emp),
                      ),
                    ],
                  ),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showChangeRoleDialog(BuildContext context, EmployeeModel emp) {
    final roles = ['Admin', 'Manager', 'Developer', 'Viewer'];
    String selectedRole = emp.role;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Change Role for ${emp.fullName}'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<String>(
                value: roles.contains(selectedRole) ? selectedRole : null,
                items: roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setState(() => selectedRole = val!),
                decoration: const InputDecoration(labelText: 'New Role'),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<EmployeesCubit>().changeRole(emp.id, selectedRole);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, EmployeeModel emp) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Member'),
          content: Text('Are you sure you want to delete ${emp.fullName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<EmployeesCubit>().deleteEmployee(emp.id);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.orange;
      case 'developer':
        return AppColors.primary;
      default:
        return Colors.teal;
    }
  }
}
