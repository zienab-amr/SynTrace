import 'package:flutter/material.dart';

import 'package:syntrace/shared/widgets/design_system/design_system.dart';

import '../../../data/models/project_client_model.dart';

class ProjectDetailsForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  final TextEditingController nameController;
  final TextEditingController descriptionController;

  final List<ProjectClientModel> clients;

  final String? selectedClientId;
  final ValueChanged<String?> onClientChanged;

  final VoidCallback onCreateClient;

  final bool enabled;

  const ProjectDetailsForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.descriptionController,
    required this.clients,
    required this.selectedClientId,
    required this.onClientChanged,
    required this.onCreateClient,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              title: 'Project details',
              subtitle: 'Define your new project.',
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Project name',
              hint: 'Enter project name',
              controller: nameController,
              prefixIcon: Icons.folder_outlined,
              requiredField: true,
              enabled: enabled,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a project name';
                }

                return null;
              },
            ),
            const SizedBox(height: 20),
            _ClientSelector(
              clients: clients,
              selectedClientId: selectedClientId,
              onChanged: onClientChanged,
              onCreateClient: onCreateClient,
              enabled: enabled,
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Description',
              hint: 'Describe the project and its goals...',
              controller: descriptionController,
              enabled: enabled,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientSelector extends StatelessWidget {
  final List<ProjectClientModel> clients;
  final String? selectedClientId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreateClient;
  final bool enabled;

  const _ClientSelector({
    required this.clients,
    required this.selectedClientId,
    required this.onChanged,
    required this.onCreateClient,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final validSelection = clients.any(
      (client) => client.id == selectedClientId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Client *', style: theme.textTheme.labelLarge),
            ),
            TextButton.icon(
              onPressed: enabled ? onCreateClient : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New client'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (clients.isEmpty)
          _EmptyClientsCard(onCreateClient: onCreateClient, enabled: enabled)
        else
          DropdownButtonFormField<String>(
            key: ValueKey(clients.map((client) => client.id).join(',')),
            initialValue: validSelection ? selectedClientId : null,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.business_outlined),
              hintText: 'Select a client',
            ),
            items: clients.map((client) {
              return DropdownMenuItem<String>(
                value: client.id,
                child: Text(client.name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: enabled ? onChanged : null,
            validator: (value) {
              if (value == null ||
                  !clients.any((client) => client.id == value)) {
                return 'Select a valid client';
              }

              return null;
            },
          ),
      ],
    );
  }
}

class _EmptyClientsCard extends StatelessWidget {
  final VoidCallback onCreateClient;
  final bool enabled;

  const _EmptyClientsCard({
    required this.onCreateClient,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.business_outlined,
            size: 32,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('No clients yet', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            'Add your first client to continue.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: enabled ? onCreateClient : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add client'),
          ),
        ],
      ),
    );
  }
}
