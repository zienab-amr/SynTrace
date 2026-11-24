import 'package:flutter/material.dart';

import '../../data/models/knowledge_source_model.dart';

class MeetingStatusBadge extends StatelessWidget {
  final KnowledgeSourceStatus status;

  const MeetingStatusBadge({super.key, required this.status});

  Color _getColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case KnowledgeSourceStatus.pendingExtraction:
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

      case KnowledgeSourceStatus.extractionFailed:
      case KnowledgeSourceStatus.rejected:
        return isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);

      case KnowledgeSourceStatus.awaitingReview:
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);

      case KnowledgeSourceStatus.published:
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

      case KnowledgeSourceStatus.unknown:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  IconData get _icon {
    switch (status) {
      case KnowledgeSourceStatus.pendingExtraction:
        return Icons.hourglass_top_rounded;

      case KnowledgeSourceStatus.extractionFailed:
        return Icons.error_outline_rounded;

      case KnowledgeSourceStatus.awaitingReview:
        return Icons.rate_review_outlined;

      case KnowledgeSourceStatus.published:
        return Icons.check_circle_outline_rounded;

      case KnowledgeSourceStatus.rejected:
        return Icons.cancel_outlined;

      case KnowledgeSourceStatus.unknown:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.isProcessing)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
            )
          else
            Icon(_icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
