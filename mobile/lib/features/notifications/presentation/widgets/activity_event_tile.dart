import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/core/theme/app_premium_icons.dart';
import 'package:syntrace/shared/widgets/app_icon.dart';

import '../../data/models/jira_event_model.dart';

class ActivityEventTile extends StatelessWidget {
  final JiraEventModel event;

  const ActivityEventTile({super.key, required this.event});

  AppIconData get _icon {
    switch (event.category) {
      case JiraEventCategory.comment:
        return AppPremiumIcons.chat;

      case JiraEventCategory.project:
        return AppPremiumIcons.projects;

      case JiraEventCategory.board:
        return AppPremiumIcons.dashboard;

      default:
        return AppPremiumIcons.activity;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = context.appText;
    final scheme = Theme.of(context).colorScheme;

    final timestamp = DateFormat(
      'MMM d · h:mm a',
    ).format(event.timestamp.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              _icon,
              size: 19,
              strokeWidth: 1.6,
              color: scheme.primary,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.actorName,
                  style: text.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),

                const SizedBox(height: 5),

                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${event.action} '),
                      TextSpan(
                        text: event.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  style: text.bodySmall?.copyWith(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.textPrimary,
                  ),
                ),

                if (event.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),

                  Text(
                    event.description,
                    style: text.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],

                const SizedBox(height: 9),

                Text(
                  timestamp,
                  style: text.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
