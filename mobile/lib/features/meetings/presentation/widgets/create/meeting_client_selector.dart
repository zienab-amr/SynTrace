import 'package:flutter/material.dart';

import '../../../data/models/meeting_client_model.dart';

class MeetingClientSelector extends StatelessWidget {
  final List<MeetingClientModel> clients;
  final String? selectedClientId;
  final String? errorMessage;
  final bool isLoading;
  final bool enabled;

  final ValueChanged<String?> onChanged;
  final VoidCallback onRetry;

  const MeetingClientSelector({
    super.key,
    required this.clients,
    required this.selectedClientId,
    required this.onChanged,
    required this.onRetry,
    this.errorMessage,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Loading clients...'),
          SizedBox(height: 10),
          LinearProgressIndicator(),
        ],
      );
    }

    if (errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
          TextButton.icon(
            onPressed: enabled ? onRetry : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    final uniqueClients = {
      for (final client in clients) client.id: client,
    }.values.toList(growable: false);

    if (uniqueClients.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No clients available. A client must be '
            'created before adding a meeting.',
          ),
          TextButton.icon(
            onPressed: enabled ? onRetry : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh clients'),
          ),
        ],
      );
    }

    final selectedValue =
        uniqueClients.any((client) => client.id == selectedClientId)
        ? selectedClientId
        : null;

    return DropdownButtonFormField<String>(
      key: ValueKey(selectedValue),
      initialValue: selectedValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Client',
        prefixIcon: Icon(Icons.business_outlined),
        border: OutlineInputBorder(),
      ),
      items: uniqueClients.map((client) {
        return DropdownMenuItem<String>(
          value: client.id,
          child: Text(client.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      validator: (value) {
        return value == null ? 'Please select a client' : null;
      },
    );
  }
}
