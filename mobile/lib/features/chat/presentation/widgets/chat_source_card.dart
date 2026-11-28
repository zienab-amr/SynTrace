import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/chat_source_model.dart';

class ChatSourceCard extends StatelessWidget {
  final ChatSourceModel source;

  const ChatSourceCard({super.key, required this.source});

  IconData get _icon {
    switch (source.type) {
      case ChatSourceType.githubCommit:
        return Icons.commit_rounded;

      case ChatSourceType.githubPullRequest:
        return Icons.account_tree_outlined;

      case ChatSourceType.githubFile:
        return Icons.code_rounded;

      case ChatSourceType.githubRepository:
        return Icons.folder_outlined;

      case ChatSourceType.jira:
        return Icons.assignment_outlined;

      case ChatSourceType.unknown:
        return Icons.link_off_rounded;
    }
  }

  Future<void> _openSource(BuildContext context) async {
    final uri = source.safeUri;

    if (uri == null || !source.isAvailable) return;

    bool opened = false;

    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (!context.mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to open this source. Check the link and your access.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final available = source.isAvailable;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: available ? () => _openSource(context) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(context),

                const SizedBox(width: 12),

                Expanded(child: _buildContent(context)),

                const SizedBox(width: 8),

                Icon(
                  available
                      ? Icons.open_in_new_rounded
                      : Icons.link_off_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        _icon,
        size: 19,
        color: source.isAvailable ? colors.primary : colors.onSurfaceVariant,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          source.typeLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          source.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        if (source.repository != null &&
            source.type != ChatSourceType.githubRepository) ...[
          const SizedBox(height: 4),

          Text(
            source.repository!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],

        if (source.hasLineRange) ...[
          const SizedBox(height: 8),

          _buildLineReference(context),
        ],

        if (source.type == ChatSourceType.githubFile &&
            !source.isPreciseCodeReference) ...[
          const SizedBox(height: 6),

          Text(
            'Exact code revision or line reference '
            'is unavailable.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],

        if (!source.isAvailable) ...[
          const SizedBox(height: 6),

          Text(
            'This source cannot be opened safely.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLineReference(BuildContext context) {
    final theme = Theme.of(context);

    final label = source.startLine == source.endLine
        ? 'Line ${source.startLine}'
        : 'Lines ${source.startLine}–${source.endLine}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
