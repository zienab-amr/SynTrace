import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../data/models/project_client_model.dart';
import '../../../data/project_clients_repository.dart';

class ClientFormDialog extends StatefulWidget {
  final ProjectClientModel client;
  final bool Function()? canSubmit;
  final ProjectClientsRepository repository;
  const ClientFormDialog({
    super.key,
    required this.client,
    required this.repository,
    this.canSubmit,
  });
  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.client.name);
  late final _email = TextEditingController(text: widget.client.email);
  late final _phone = TextEditingController(text: widget.client.phoneNumber);
  late ClientStatus _status = widget.client.status;
  bool _busy = false;
  bool _uncertain = false;
  String? _error;
  Future<void> _save() async {
    if (widget.canSubmit?.call() == false) {
      setState(() => _error = 'Refresh clients before editing.');
      return;
    }
    if (_busy || _uncertain || !_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.updateClient(
        clientId: widget.client.id,
        name: _name.text,
        email: _email.text,
        phoneNumber: _phone.text,
        status: _status,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final rejected =
          e is DioException &&
          const [400, 401, 403, 404, 422].contains(e.response?.statusCode);
      setState(() {
        _uncertain = !rejected;
        _error = rejected
            ? 'Update rejected. Check your information and permissions.'
            : 'Update not confirmed. Close and refresh before retrying.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Edit client'),
      content: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy && !_uncertain,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty || v.trim().length > 200
                    ? 'Enter a name (max 200 characters)'
                    : null,
              ),
              TextFormField(
                controller: _email,
                enabled: !_busy && !_uncertain,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v?.trim().isNotEmpty ?? false) &&
                        (v!.trim().length > 254 ||
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v.trim()))
                    ? 'Invalid email'
                    : null,
              ),
              TextFormField(
                controller: _phone,
                enabled: !_busy && !_uncertain,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) => (v?.trim().length ?? 0) > 50
                    ? 'Maximum 50 characters'
                    : null,
              ),
              DropdownButton<ClientStatus>(
                value: _status,
                items: ClientStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: _busy || _uncertain
                    ? null
                    : (s) {
                        if (s != null) setState(() => _status = s);
                      },
              ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _busy || _uncertain ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}
