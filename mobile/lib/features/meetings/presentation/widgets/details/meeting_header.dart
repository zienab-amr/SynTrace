import 'package:flutter/material.dart';
import '../../../data/models/knowledge_source_model.dart';
import '../../cubit/meeting_notes_state.dart';
import '../meeting_status_badge.dart';
import 'package:intl/intl.dart';

class MeetingHeader extends StatelessWidget {
  final KnowledgeSourceDetails details;
  final MeetingNotesState state;
  const MeetingHeader({super.key, required this.details, required this.state});
  @override
  Widget build(BuildContext context) =>
      _buildMeetingHeader(context, details, state);

  Widget _buildMeetingHeader(
    BuildContext context,
    KnowledgeSourceDetails details,
    MeetingNotesState state,
  ) {
    final theme = Theme.of(context);

    String? clientName;

    for (final client in state.clients) {
      if (client.id == details.source.clientId) {
        clientName = client.name;
        break;
      }
    }

    final meetingDate = details.meetingAt;

    final mode = details.meetingMode;

    return _buildSurface(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            details.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          MeetingStatusBadge(status: details.status),

          const SizedBox(height: 20),

          if (clientName != null)
            _buildInfoRow(
              context,
              icon: Icons.business_outlined,
              label: 'Client',
              value: clientName,
            ),

          if (meetingDate != null)
            _buildInfoRow(
              context,
              icon: Icons.calendar_today_outlined,
              label: 'Meeting Date',
              value: DateFormat(
                'MMM dd, yyyy • hh:mm a',
              ).format(meetingDate.toLocal()),
            ),

          if (mode != null)
            _buildInfoRow(
              context,
              icon: mode == KnowledgeMeetingMode.online
                  ? Icons.videocam_outlined
                  : Icons.groups_outlined,
              label: 'Meeting Mode',
              value: mode == KnowledgeMeetingMode.online
                  ? 'Online'
                  : 'In Person',
            ),

          _buildInfoRow(
            context,
            icon: Icons.layers_outlined,
            label: 'Current Version',
            value: '${details.source.version}',
          ),

          if (details.source.publishedVersion != null)
            _buildInfoRow(
              context,
              icon: Icons.verified_outlined,
              label: 'Published Version',
              value: '${details.source.publishedVersion}',
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),

          const SizedBox(width: 10),

          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),

          const SizedBox(width: 12),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
