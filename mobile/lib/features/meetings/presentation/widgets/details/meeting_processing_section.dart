import 'package:flutter/material.dart';
import '../../../data/models/knowledge_source_model.dart';
import '../../cubit/meeting_notes_state.dart';
import '../meeting_status_badge.dart';

class MeetingProcessingSection extends StatelessWidget {
  final KnowledgeSourceDetails details;
  final MeetingNotesState state;
  final VoidCallback onRetry;
  const MeetingProcessingSection({
    super.key,
    required this.details,
    required this.state,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) =>
      _buildProcessingSection(context, details, state);

  Widget _buildProcessingSection(
    BuildContext context,
    KnowledgeSourceDetails details,
    MeetingNotesState state,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isFailed = details.status == KnowledgeSourceStatus.extractionFailed;

    return _buildSurface(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: colors.primary),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  'AI Processing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          MeetingStatusBadge(status: details.status),

          const SizedBox(height: 12),

          Text(
            _getStatusDescription(context, details.status),
            style: theme.textTheme.bodyMedium,
          ),

          if (details.isProcessing) ...[
            const SizedBox(height: 16),

            if (!state.hasDetailsRefreshError) const LinearProgressIndicator(),

            const SizedBox(height: 10),

            Text(
              state.hasDetailsRefreshError
                  ? 'Automatic status update failed.'
                  : 'Status updates automatically.',
              style: theme.textTheme.bodySmall,
            ),
          ],

          if (isFailed) ...[
            if (details.extractionFailureMessage != null) ...[
              const SizedBox(height: 12),

              Text(
                details.extractionFailureMessage ??
                    'Unable to extract meeting results.',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,

              child: OutlinedButton.icon(
                onPressed: state.canUseSelectedMeeting && details.canRetry
                    ? onRetry
                    : null,

                icon: state.isRetrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),

                label: Text(
                  state.isRetrying ? 'Requesting Retry...' : 'Retry Processing',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusDescription(
    BuildContext context,
    KnowledgeSourceStatus status,
  ) {
    switch (status) {
      case KnowledgeSourceStatus.pendingExtraction:
        return 'Your meeting notes are waiting for '
            'or undergoing AI processing.';

      case KnowledgeSourceStatus.extractionFailed:
        return 'The meeting could not be processed. '
            'You can request another processing attempt.';

      case KnowledgeSourceStatus.awaitingReview:
        return 'The extracted information is ready '
            'for review before publication.';

      case KnowledgeSourceStatus.published:
        return 'The meeting source has been published.';

      case KnowledgeSourceStatus.rejected:
        return 'The meeting source has been rejected.';

      case KnowledgeSourceStatus.unknown:
        return 'The server returned an unknown status. '
            'Refresh to check for updates.';
    }
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
