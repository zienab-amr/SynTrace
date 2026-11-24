import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import '../../../data/models/knowledge_source_model.dart';
import '../meeting_status_badge.dart';

class MeetingCard extends StatelessWidget {
  final KnowledgeSourceSummary meeting;
  final String? clientName;
  final VoidCallback? onTap;

  const MeetingCard({
    super.key,
    required this.meeting,
    this.clientName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),

      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,

                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),

                    child: const Icon(
                      Icons.event_note_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      meeting.title,

                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (clientName != null)
                Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 15,
                      color: colorScheme.onSurfaceVariant,
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        clientName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    'Version ${meeting.version}',
                    style: theme.textTheme.bodySmall,
                  ),

                  const Spacer(),

                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              MeetingStatusBadge(status: meeting.status),
            ],
          ),
        ),
      ),
    );
  }
}
