import 'package:flutter/material.dart';

class GitHubPickerSearch extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  const GitHubPickerSearch({
    super.key,
    required this.controller,
    required this.query,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,

      textInputAction: TextInputAction.search,

      onChanged: onChanged,

      decoration: InputDecoration(
        hintText: 'Search repositories...',

        prefixIcon: const Icon(Icons.search_rounded),

        suffixIcon: query.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  controller.clear();

                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              )
            : null,

        filled: true,
        fillColor: theme.colorScheme.surface,

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
