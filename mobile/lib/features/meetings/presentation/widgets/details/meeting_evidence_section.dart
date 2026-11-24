import 'package:flutter/material.dart';
import '../../../data/models/knowledge_source_model.dart';

class MeetingEvidenceSection extends StatelessWidget {
  final KnowledgeSourceDetails details;
  const MeetingEvidenceSection({super.key, required this.details});
  @override
  Widget build(BuildContext context) => _buildEvidenceSection(context, details);

  Widget _buildEvidenceSection(
    BuildContext context,
    KnowledgeSourceDetails details,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSectionTitle(context, 'Extracted Insights')),

            Text(
              '${details.uniqueEvidence.length} items',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (details.isProcessing ||
            details.status == KnowledgeSourceStatus.extractionFailed ||
            details.status == KnowledgeSourceStatus.unknown ||
            details.uniqueEvidence.isEmpty)
          _buildSurface(
            context,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    details.isProcessing
                        ? 'Extracted insights will appear '
                              'when processing is complete.'
                        : details.status ==
                              KnowledgeSourceStatus.extractionFailed
                        ? 'Extraction failed. Results could not be generated.'
                        : details.status == KnowledgeSourceStatus.unknown
                        ? 'Results unavailable. Refresh to check the status.'
                        : 'No evidence items are available for this meeting version.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (details.isAwaitingReview)
            _buildSurface(
              context,
              child: const Text(
                'These results are awaiting review and have not been published.',
              ),
            ),
          if (details.isRejected)
            _buildSurface(
              context,
              child: const Text('These results belong to a rejected version.'),
            ),
          ...KnowledgeEvidenceKind.values.map((kind) {
            final items = details.evidenceByKind(kind);

            if (items.isEmpty) {
              return const SizedBox.shrink();
            }

            return _buildEvidenceGroup(context, kind, items);
          }),
        ],
      ],
    );
  }

  Widget _buildEvidenceGroup(
    BuildContext context,
    KnowledgeEvidenceKind kind,
    List<KnowledgeEvidenceModel> items,
  ) {
    final theme = Theme.of(context);
    final color = _getEvidenceColor(context, kind);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getEvidenceIcon(context, kind), color: color, size: 20),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  _getEvidenceGroupTitle(context, kind),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),

                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ...items.map((item) => _buildEvidenceCard(context, item)),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard(BuildContext context, KnowledgeEvidenceModel item) {
    final theme = Theme.of(context);

    final color = _getEvidenceColor(context, item.kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),

      clipBehavior: Clip.antiAlias,

      child: ExpansionTile(
        key: PageStorageKey<String>('evidence-${item.id}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),

        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

        leading: Icon(
          _getEvidenceIcon(context, item.kind),
          color: color,
          size: 20,
        ),

        title: Text(
          item.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildDecisionBadge(context, item.decision),
          ),
        ),

        children: [
          if (item.quote.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),

                borderRadius: BorderRadius.circular(8),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Source Evidence',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  SelectableText(
                    item.quote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else
            const Text('No source quote available.'),
        ],
      ),
    );
  }

  Widget _buildDecisionBadge(
    BuildContext context,
    KnowledgeEvidenceDecision decision,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    late final Color color;
    late final String label;

    switch (decision) {
      case KnowledgeEvidenceDecision.pending:
        color = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        label = 'Pending Review';
        break;

      case KnowledgeEvidenceDecision.approved:
        color = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
        label = 'Approved';
        break;

      case KnowledgeEvidenceDecision.rejected:
        color = theme.colorScheme.error;
        label = 'Rejected';
        break;

      case KnowledgeEvidenceDecision.unknown:
        color = theme.colorScheme.onSurfaceVariant;
        label = 'Unknown';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getEvidenceGroupTitle(
    BuildContext context,
    KnowledgeEvidenceKind kind,
  ) {
    switch (kind) {
      case KnowledgeEvidenceKind.requirement:
        return 'Requirements';

      case KnowledgeEvidenceKind.decision:
        return 'Decisions';

      case KnowledgeEvidenceKind.actionItem:
        return 'Action Items';

      case KnowledgeEvidenceKind.openQuestion:
        return 'Open Questions';

      case KnowledgeEvidenceKind.blocker:
        return 'Blockers';

      case KnowledgeEvidenceKind.unknown:
        return 'Other Insights';
    }
  }

  IconData _getEvidenceIcon(BuildContext context, KnowledgeEvidenceKind kind) {
    switch (kind) {
      case KnowledgeEvidenceKind.requirement:
        return Icons.checklist_rounded;

      case KnowledgeEvidenceKind.decision:
        return Icons.account_tree_outlined;

      case KnowledgeEvidenceKind.actionItem:
        return Icons.task_alt_rounded;

      case KnowledgeEvidenceKind.openQuestion:
        return Icons.help_outline_rounded;

      case KnowledgeEvidenceKind.blocker:
        return Icons.warning_amber_rounded;

      case KnowledgeEvidenceKind.unknown:
        return Icons.info_outline;
    }
  }

  Color _getEvidenceColor(BuildContext context, KnowledgeEvidenceKind kind) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (kind) {
      case KnowledgeEvidenceKind.requirement:
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);

      case KnowledgeEvidenceKind.decision:
        return isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED);

      case KnowledgeEvidenceKind.actionItem:
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

      case KnowledgeEvidenceKind.openQuestion:
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

      case KnowledgeEvidenceKind.blocker:
        return theme.colorScheme.error;

      case KnowledgeEvidenceKind.unknown:
        return theme.colorScheme.onSurfaceVariant;
    }
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
