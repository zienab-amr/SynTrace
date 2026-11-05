import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/employees/presentation/cubit/employees_cubit.dart';
import 'package:syntrace/features/employees/presentation/cubit/employees_state.dart';
import 'package:syntrace/features/employees/presentation/screens/add_employee_screen.dart';
import 'package:syntrace/features/employees/presentation/screens/employees_screen.dart';

class OrganizationTab extends StatefulWidget {
  const OrganizationTab({super.key});

  @override
  State<OrganizationTab> createState() => _OrganizationTabState();
}

class _OrganizationTabState extends State<OrganizationTab> {
  final _nameController = TextEditingController();
  final _planController = TextEditingController(text: 'Enterprise');
  final _regionController = TextEditingController(text: 'Egypt');

  bool _isEditingOrg = false;
  bool _isSavingOrg = false;

  @override
  void initState() {
    super.initState();
    _loadOrgData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _planController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _loadOrgData() async {
    final user = CurrentUserService.instance.user;
    final storedCompany = await SecureStorageService.instance.getCompanyName();
    if (!mounted) return;
    setState(() {
      _nameController.text =
          storedCompany ?? user?.companyName ?? 'My Organization';
    });
  }

  Future<void> _saveOrgData() async {
    setState(() => _isSavingOrg = true);

    await SecureStorageService.instance.saveCompanyName(_nameController.text);
    final user = CurrentUserService.instance.user;
    if (user != null) {
      await CurrentUserService.instance.setUser(
        user.copyWith(companyName: _nameController.text),
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() {
      _isSavingOrg = false;
      _isEditingOrg = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Organization updated successfully'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrganizationDetails(context),
          const SizedBox(height: 24),
          _buildMembersList(context),
        ],
      ),
    );
  }

  Widget _buildOrganizationDetails(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORGANIZATION DETAILS',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              if (!_isEditingOrg)
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  onPressed: () => setState(() => _isEditingOrg = true),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildField(
                  theme,
                  'Organization Name',
                  _isEditingOrg
                      ? _nameController
                      : TextEditingController(text: _nameController.text),
                  enabled: _isEditingOrg,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildField(
                  theme,
                  'Plan',
                  _isEditingOrg
                      ? _planController
                      : TextEditingController(text: _planController.text),
                  enabled: _isEditingOrg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  theme,
                  'Region',
                  _isEditingOrg
                      ? _regionController
                      : TextEditingController(text: _regionController.text),
                  enabled: _isEditingOrg,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),
          if (_isEditingOrg) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _isEditingOrg = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSavingOrg ? null : _saveOrgData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: _isSavingOrg
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembersList(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEMBERS',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          BlocBuilder<EmployeesCubit, EmployeesState>(
            builder: (context, state) {
              if (state is EmployeesLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              if (state is EmployeesError) {
                return Center(
                  child: Text(
                    state.message,
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (state is EmployeesLoaded) {
                if (state.employees.isEmpty) {
                  return const Center(child: Text('No members found.'));
                }

                final displayedMembers = state.employees.take(4).toList();

                return Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedMembers.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: theme.dividerColor.withOpacity(0.2)),
                      itemBuilder: (context, index) {
                        final emp = displayedMembers[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: _roleColor(
                              emp.role,
                            ).withOpacity(0.15),
                            child: Text(
                              emp.initials.isEmpty ? '?' : emp.initials,
                              style: TextStyle(
                                color: _roleColor(emp.role),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            emp.fullName.isEmpty ? 'Unknown' : emp.fullName,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            emp.email,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            emp.role,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => context.push('/profile/${emp.id}'),
                        );
                      },
                    ),
                    if (state.employees.length > 4)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<EmployeesCubit>(),
                                  child: const AllEmployeesScreen(),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'View all members (${state.employees.length})',
                          ),
                        ),
                      ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<EmployeesCubit>(),
                    child: const AddEmployeeScreen(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add member'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
              side: BorderSide(color: theme.dividerColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    ThemeData theme,
    String label,
    TextEditingController controller, {
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? theme.scaffoldBackgroundColor.withOpacity(0.5)
                : theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.3),
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.1),
              ),
            ),
          ),
        ),
      ],
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
