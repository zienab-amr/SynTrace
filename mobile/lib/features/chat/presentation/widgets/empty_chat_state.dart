import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class EmptyChatState extends StatelessWidget {
  final Function(String) onSuggestionTap;

  const EmptyChatState({super.key, required this.onSuggestionTap});

  static const _suggestions = [
    'Why is Sprint 14 delayed?',
    'Show me recent bugs',
    'What changed in the last commit?',
    'Who worked on the auth module?',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ─── Icon ───
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.secondary.withOpacity(0.15),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Title ───
            Text(
              'Start a conversation',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // ─── Subtitle ───
            Text(
              'Ask me anything about your projects,\ncommits, bugs, or team.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // ─── Suggestions ───
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions.map((text) {
                return _SuggestionChip(
                  text: text,
                  onTap: () => onSuggestionTap(text),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.5),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}