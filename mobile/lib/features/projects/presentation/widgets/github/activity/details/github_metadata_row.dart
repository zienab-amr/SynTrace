import 'package:flutter/material.dart';

class GitHubMetadataRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool selectable;

  const GitHubMetadataRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 4),

          if (selectable)
            SelectableText(value!, style: theme.textTheme.bodyMedium)
          else
            Text(value!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
