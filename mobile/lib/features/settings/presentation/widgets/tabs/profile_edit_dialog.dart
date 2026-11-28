import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/self_profile_service.dart';

class ProfileEditDialog extends StatefulWidget {
  final SelfProfileDetails details;
  final CacheSessionGuard guard;
  final SelfProfileService service;
  const ProfileEditDialog({
    super.key,
    required this.details,
    required this.guard,
    required this.service,
  });
  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  bool _saving = false;
  bool _requiresRefresh = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(text: widget.details.firstName);
    _last = TextEditingController(text: widget.details.lastName);
    _phone = TextEditingController(text: widget.details.user.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Required';
    if (name.length > 100) return 'Maximum 100 characters';
    return null;
  }

  Future<void> _save() async {
    if (_saving ||
        _requiresRefresh ||
        !widget.guard.isValid ||
        !(_form.currentState?.validate() ?? false))
      return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.service.update(
        firstName: _first.text,
        lastName: _last.text,
        phoneNumber: _phone.text,
      );
      if (mounted && widget.guard.isValid) Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      final status = error is DioException ? error.response?.statusCode : null;
      setState(() {
        _requiresRefresh = status != 400 && status != 422;
        _error = switch (status) {
          400 || 422 => 'Check your name and phone number.',
          401 || 403 => 'Your session or access could not be verified.',
          _ =>
            'Update could not be confirmed. Close and refresh before trying again.',
        };
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: CurrentUserService.instance.userNotifier,
    builder: (context, _, child) {
      if (!widget.guard.isValid) {
        return AlertDialog(
          title: const Text('Session changed'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      }
      return PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: const Text('Edit profile'),
          scrollable: true,
          content: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _first,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: _validateName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _last,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: _validateName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  validator: (value) => (value?.trim().length ?? 0) > 40
                      ? 'Maximum 40 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Email, organization and roles cannot be changed here.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _saving || _requiresRefresh ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save changes'),
            ),
          ],
        ),
      );
    },
  );
}
