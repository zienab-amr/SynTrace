import 'package:flutter/material.dart';

class MeetingEmptyView extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final VoidCallback? onCreate;
  const MeetingEmptyView({super.key, required this.onRefresh, this.onCreate});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,

      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight < 300
                    ? 300
                    : constraints.maxHeight,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_note_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'No meeting notes yet',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Create your first meeting note '
                          'to get started.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 20),

                        OutlinedButton.icon(
                          onPressed: onCreate,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Meeting'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
