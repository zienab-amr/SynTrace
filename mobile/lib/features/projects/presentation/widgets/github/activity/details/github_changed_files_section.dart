import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/models/github_activity_model.dart';
import 'github_details_section.dart';
import 'github_metadata_row.dart';
import 'github_information_message.dart';

class GitHubChangedFilesSection extends StatelessWidget {
  final GitHubActivityItem item;

  const GitHubChangedFilesSection({required this.item});

  @override
  Widget build(BuildContext context) {
    return GitHubDetailsSection(
      title: 'Changed Files',
      icon: Icons.folder_copy_outlined,
      children: [
        if (item.files.isEmpty)
          const GitHubInformationMessage(
            icon: Icons.description_outlined,
            message: 'No changed-file details were returned.',
          )
        else ...[
          Text(
            item.filesMayBeIncomplete
                ? '${item.files.length}+ files returned'
                : '${item.files.length} files returned',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: 12),

          ...item.files.map((file) => _ChangedFileCard(file: file)),
        ],

        if (item.filesMayBeIncomplete)
          const GitHubInformationMessage(
            icon: Icons.info_outline,
            message: 'The returned file list may be incomplete.',
          ),

        const SizedBox(height: 8),

        const GitHubInformationMessage(
          icon: Icons.code_off_rounded,
          message:
              'Inline code and diff previews are not '
              'available from the current activity API.',
        ),
      ],
    );
  }
}

class _ChangedFileCard extends StatelessWidget {
  final GitHubChangedFile file;

  const _ChangedFileCard({required this.file});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 20,
                color: colors.onSurfaceVariant,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: SelectableText(
                  file.path ?? 'File path unavailable',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          if (file.isRenamed) ...[
            const SizedBox(height: 8),

            GitHubMetadataRow(
              label: 'Previous path',
              value: file.previousPath,
              selectable: true,
            ),
          ],

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (file.status != null) Chip(label: Text(file.status!)),

              if (file.additions != null)
                _ChangeCount(
                  label: '+${file.additions}',
                  color: colors.tertiary,
                ),

              if (file.deletions != null)
                _ChangeCount(label: '-${file.deletions}', color: colors.error),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangeCount extends StatelessWidget {
  final String label;
  final Color color;

  const _ChangeCount({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
