import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/role_model.dart';
import '../cubit/roles_cubit.dart';
import '../cubit/roles_state.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RolesCubit>().fetchRoles();
  }

  bool _reserved(RoleModel role) => role.name.trim().toLowerCase() == 'admin';

  Future<void> _edit([RoleModel? role]) async {
    final cubit = context.read<RolesCubit>();
    if (!cubit.canManage ||
        cubit.state is! RolesLoaded ||
        (role != null && _reserved(role))) {
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RoleNameDialog(initialName: role?.name),
    );
    if (!mounted ||
        name == null ||
        !cubit.canManage ||
        cubit.state is! RolesLoaded) {
      return;
    }
    if (role == null) {
      await cubit.createRole(name, '');
    } else if (name != role.name) {
      await cubit.updateRole(role.id, name);
    }
  }

  Future<void> _delete(RoleModel role) async {
    final cubit = context.read<RolesCubit>();
    if (!cubit.canManage || cubit.state is! RolesLoaded || _reserved(role)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete role?'),
        content: Text(
          'Delete ${role.name}? Employees must be reassigned before a role in use can be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !cubit.canManage ||
        cubit.state is! RolesLoaded) {
      return;
    }
    await cubit.deleteRole(role.id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RolesCubit, RolesState>(
      listener: (context, state) {
        if (state is RolesError || state is RolesActionSuccess) {
          final message = state is RolesError
              ? state.message
              : (state as RolesActionSuccess).message;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final cubit = context.read<RolesCubit>();
        final ready = cubit.canManage && state is RolesLoaded;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Roles Management'),
            actions: [
              IconButton(
                tooltip: 'Refresh roles',
                onPressed: cubit.canManage && state is! RolesLoading
                    ? cubit.fetchRoles
                    : null,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _body(state, cubit),
          floatingActionButton: ready
              ? FloatingActionButton(
                  tooltip: 'Create role',
                  onPressed: () => _edit(),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  Widget _body(RolesState state, RolesCubit cubit) {
    if (!cubit.canManage) {
      return const Center(
        child: Text('Admin access required. Reopen this page.'),
      );
    }
    if (state is RolesLoading ||
        state is RolesInitial ||
        state is RolesActionSuccess) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is RolesError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: cubit.fetchRoles,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }
    if (state is! RolesLoaded) return const SizedBox.shrink();
    if (state.roles.isEmpty) {
      return const Center(child: Text('No roles found. Tap + to add.'));
    }
    return RefreshIndicator(
      onRefresh: cubit.fetchRoles,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.roles.length,
        itemBuilder: (context, index) {
          final role = state.roles[index];
          return ListTile(
            title: Text(role.name),
            subtitle: _reserved(role)
                ? const Text('Reserved company administrator role')
                : null,
            trailing: _reserved(role)
                ? const Icon(Icons.lock_outline)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit role',
                        onPressed: () => _edit(role),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete role',
                        onPressed: () => _delete(role),
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _RoleNameDialog extends StatefulWidget {
  final String? initialName;
  const _RoleNameDialog({this.initialName});

  @override
  State<_RoleNameDialog> createState() => _RoleNameDialogState();
}

class _RoleNameDialogState extends State<_RoleNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() == true) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName == null ? 'Create role' : 'Edit role'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 256,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: 'Role name'),
          validator: (value) {
            final name = value?.trim() ?? '';
            if (name.isEmpty || name.length > 256) {
              return 'Enter a role name (1–256 characters).';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
