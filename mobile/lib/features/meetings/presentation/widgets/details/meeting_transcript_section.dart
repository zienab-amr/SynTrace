import 'package:flutter/material.dart';
import '../../../data/models/knowledge_source_model.dart';

class MeetingTranscriptSection extends StatelessWidget {
  final KnowledgeSourceDetails details;
  const MeetingTranscriptSection({super.key, required this.details});
  @override
  Widget build(BuildContext context) =>
      _buildTranscriptSection(context, details);

  Widget _buildTranscriptSection(
    BuildContext context,
    KnowledgeSourceDetails details,
  ) {
    final theme = Theme.of(context);
    final sourceText = details.sourceText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Original Meeting Notes'),

        const SizedBox(height: 12),

        _buildSurface(
          context,
          child: SizedBox(
            width: double.infinity,

            child: sourceText == null || sourceText.trim().isEmpty
                ? Text(
                    'No source text available.',
                    style: theme.textTheme.bodyMedium,
                  )
                : SelectableText(
                    sourceText,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSurface(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),

      child: child,
    );
  }
}
