import 'package:flutter/material.dart';

class MeetingsToolbar extends StatelessWidget {
  final int meetingCount;
  final int processingCount;
  final bool hasRefreshError;
  final VoidCallback? onRefresh;
  const MeetingsToolbar({
    super.key,
    required this.meetingCount,
    required this.processingCount,
    required this.hasRefreshError,
    this.onRefresh,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${meetingCount} Meetings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              if (processingCount > 0) ...[
                const SizedBox(height: 4),

                Row(
                  children: [
                    if (!hasRefreshError)
                      const SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),

                    const SizedBox(width: 6),

                    Flexible(
                      child: Text(
                        hasRefreshError
                            ? '$processingCount last reported processing'
                            : '$processingCount processing',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        IconButton(
          tooltip: 'Refresh meetings',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}
