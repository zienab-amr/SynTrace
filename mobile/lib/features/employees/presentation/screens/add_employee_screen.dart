import 'package:flutter/material.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/features/role/data/models/role_model.dart';
import 'package:syntrace/features/role/data/roles_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/features/employees/presentation/cubit/employees_cubit.dart';
import 'package:syntrace/shared/widgets/design_system/design_system.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedRole;

  bool _isSubmitting = false;
  String? _errorMessage;

  List<RoleModel> _roles = [];
  CacheSessionGuard? _guard;
  bool _loadingRoles = false;
  bool get _sessionValid => _guard?.isValid == true;
  @override
  void initState() {
    super.initState();
    final scope = CacheScope.fromCurrentUser();
    if (scope != null) _guard = CacheSessionGuard.capture(scope);
    CurrentUserService.instance.userNotifier.addListener(_sessionChanged);
    _loadRoles();
  }

  void _sessionChanged() {
    if (_sessionValid || !mounted) return;
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    setState(() {
      _roles = [];
      _selectedRole = null;
    });
  }

  Future<void> _loadRoles() async {
    if (!_sessionValid || _loadingRoles || _isSubmitting) return;
    setState(() => _loadingRoles = true);
    try {
      final result = await RolesRepository().getAllRoles();
      if (!mounted || !_sessionValid) return;
      setState(() {
        _roles = result.success ? (result.data ?? <RoleModel>[]) : [];
        _selectedRole = null;
        _errorMessage = result.success
            ? null
            : 'Unable to load workspace roles.';
      });
    } catch (_) {
      if (mounted && _sessionValid) {
        setState(() => _errorMessage = 'Unable to load workspace roles.');
      }
    } finally {
      if (mounted) setState(() => _loadingRoles = false);
    }
  }

  @override
  void dispose() {
    CurrentUserService.instance.userNotifier.removeListener(_sessionChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    if (value.trim().length > 100) return 'Use at most 100 characters';
    return null;
  }

  String? _validatePhone(String? value) {
    if ((value?.trim().length ?? 0) > 40) return 'Use at most 40 characters';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.length > 256 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 8 || value.length > 128) {
      return 'Use 8–128 characters';
    }

    return null;
  }

  Future<void> _submit() async {
    if (!_sessionValid ||
        _isSubmitting ||
        _loadingRoles ||
        !_roles.any((role) => role.id == _selectedRole)) {
      return;
    }

    final cubit = context.read<EmployeesCubit>();

    if (!cubit.canManage || cubit.isBusy) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await cubit.addEmployee(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phoneNumber: _phoneController.text,
        role: _selectedRole!,
      );

      if (!mounted || !_sessionValid) return;

      if (success) {
        _passwordController.clear();

        setState(() => _isSubmitting = false);

        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _errorMessage =
            'Member could not be created. '
            'Check the details and try again.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted && _isSubmitting) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_sessionValid || !context.read<EmployeesCubit>().canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add member')),
        body: const Center(
          child: Text('You do not have permission to add members.'),
        ),
      );
    }

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Add member'),
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppSectionHeader(
                        title: 'Expand your team',
                        subtitle:
                            'Create an account for a new '
                            'workspace member.',
                      ),
                      const SizedBox(height: 24),
                      _buildPersonalDetails(),
                      const SizedBox(height: 20),
                      _buildAccountDetails(),
                      const SizedBox(height: 20),
                      _buildRoleSelection(),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _EmployeeFormError(message: _errorMessage!),
                      ],
                      const SizedBox(height: 28),
                      AppButton(
                        label: 'Create member',
                        icon: Icons.person_add_outlined,
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting || _selectedRole == null
                            ? null
                            : _submit,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'The member will be able to sign in '
                        'using the account credentials.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalDetails() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Personal details'),
          const SizedBox(height: 20),
          AppTextField(
            label: 'First name',
            hint: 'Enter first name',
            controller: _firstNameController,
            enabled: !_isSubmitting,
            validator: _required,
            requiredField: true,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Last name',
            hint: 'Enter last name',
            controller: _lastNameController,
            enabled: !_isSubmitting,
            validator: _required,
            requiredField: true,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Phone number',
            hint: 'Enter phone number',
            controller: _phoneController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.phone,
            validator: _validatePhone,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetails() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Account credentials'),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Work email',
            hint: 'member@company.com',
            controller: _emailController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
            requiredField: true,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Password',
            hint: 'Enter account password',
            controller: _passwordController,
            enabled: !_isSubmitting,
            isPassword: true,
            validator: _validatePassword,
            requiredField: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Workspace access',
            subtitle: 'Assign a role to this member.',
          ),
          const SizedBox(height: 20),
          if (_loadingRoles) const LinearProgressIndicator(),
          if (_roles.isEmpty && !_loadingRoles)
            TextButton(
              onPressed: _isSubmitting ? null : _loadRoles,
              child: const Text('Load workspace roles'),
            ),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Workspace role',
              prefixIcon: Icon(Icons.shield_outlined),
            ),
            items: _roles.map((role) {
              return DropdownMenuItem(value: role.id, child: Text(role.name));
            }).toList(),
            onChanged: _isSubmitting || _loadingRoles
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedRole = value;
                    });
                  },
          ),
        ],
      ),
    );
  }
}

class _EmployeeFormError extends StatelessWidget {
  final String message;

  const _EmployeeFormError({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
