import '../clients/client_session_boundary.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/shared/widgets/design_system/design_system.dart';

import '../../../data/models/project_client_model.dart';
import '../../../data/project_clients_repository.dart';

import 'create_project_feedback.dart';

class CreateClientDialog extends StatefulWidget {
  const CreateClientDialog({super.key});

  static Future<ProjectClientModel?> show(BuildContext context) {
    final guard = captureClientSession();
    return showDialog<ProjectClientModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClientSessionBoundary(
        guard: guard,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
        child: const CreateClientDialog(),
      ),
    );
  }

  @override
  State<CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<CreateClientDialog> {
  late final _sessionGuard = captureClientSession();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _repository = ProjectClientsRepository();

  bool _isSubmitting = false;
  bool _creationUncertain = false;

  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _creationUncertain || !_sessionGuard.isValid) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final user = CurrentUserService.instance.user;

    if (user == null ||
        user.role != UserRole.admin ||
        user.tenantId == null ||
        user.tenantId!.isEmpty) {
      setState(() {
        _errorMessage = 'You do not have permission to create clients.';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final client = await _repository.createClient(
        name: _nameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
      );

      if (!mounted || !_sessionGuard.isValid) return;

      final current = CurrentUserService.instance.user;

      if (current?.id != user.id || current?.tenantId != user.tenantId) {
        setState(() {
          _creationUncertain = true;
          _errorMessage = 'Your account changed. Close this form.';
        });

        return;
      }

      Navigator.of(context).pop(client);
    } catch (error) {
      if (!mounted || !_sessionGuard.isValid) return;

      final statusCode = error is DioException
          ? error.response?.statusCode
          : null;

      final rejected = const [400, 401, 403, 404, 422].contains(statusCode);

      setState(() {
        _creationUncertain = !rejected;

        _errorMessage = switch (statusCode) {
          400 || 422 => 'Check the client information and try again.',
          401 => 'Your session has expired.',
          403 => 'You do not have permission.',
          404 => 'The requested resource is unavailable.',
          _ =>
            'Client creation could not be confirmed. '
                'Close this form and refresh the clients list '
                'before trying again.',
        };
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Enter the client name';
    }

    if (name.length > 200) {
      return 'Maximum 200 characters';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return null;

    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

    if (!valid || email.length > 254) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    if ((value?.trim().length ?? 0) > 50) {
      return 'Maximum 50 characters';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_isSubmitting && !_creationUncertain;

    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: const Text('New client'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a client to your organization.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    label: 'Client name',
                    hint: 'Company or client name',
                    controller: _nameController,
                    prefixIcon: Icons.business_outlined,
                    requiredField: true,
                    enabled: enabled,
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Email (optional)',
                    hint: 'client@example.com',
                    controller: _emailController,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: enabled,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Phone (optional)',
                    hint: 'Enter phone number',
                    controller: _phoneController,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    enabled: enabled,
                    validator: _validatePhone,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    CreateProjectErrorBanner(message: _errorMessage!),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: Text(_creationUncertain ? 'Close' : 'Cancel'),
          ),
          if (!_creationUncertain)
            AppButton(
              label: 'Create client',
              icon: Icons.add_rounded,
              fullWidth: false,
              isLoading: _isSubmitting,
              onPressed: enabled ? _submit : null,
            ),
        ],
      ),
    );
  }
}
