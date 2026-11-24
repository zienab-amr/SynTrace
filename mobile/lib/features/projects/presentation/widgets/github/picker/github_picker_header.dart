import 'package:flutter/material.dart';

class GitHubPickerHeader extends StatelessWidget {
  const GitHubPickerHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.account_tree_outlined,
            color: theme.colorScheme.primary,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            'Select Repository',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}
