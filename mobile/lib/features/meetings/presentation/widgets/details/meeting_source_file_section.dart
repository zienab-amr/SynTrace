import 'package:flutter/material.dart';
import '../../../data/models/knowledge_source_model.dart';

class MeetingSourceFileSection extends StatelessWidget {
  final KnowledgeSourceDetails details;
  const MeetingSourceFileSection({super.key, required this.details});
  @override
  Widget build(BuildContext context) =>
      _buildSourceFileSection(context, details);

  Widget _buildSourceFileSection(
    BuildContext context,
    KnowledgeSourceDetails details,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Source File'),

        const SizedBox(height: 12),

        _buildSurface(
          context,
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 30,
                color: theme.colorScheme.primary,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      details.fileName!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Source file metadata',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
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
