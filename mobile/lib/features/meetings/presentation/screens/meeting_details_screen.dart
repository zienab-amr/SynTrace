import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:syntrace/features/meetings/presentation/cubit/meeting_notes_cubit.dart';
import '../../data/models/meeting_note_model.dart';
import 'create_meeting_screen.dart';

class MeetingDetailsScreen extends StatelessWidget {
  final MeetingNote note;

  const MeetingDetailsScreen({super.key, required this.note});

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Note'),
          content: const Text('Are you sure you want to delete this meeting note?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<MeetingNotesCubit>().deleteMeeting(note.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(note.title),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Note',
            onPressed: () => _showDeleteDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Note',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<MeetingNotesCubit>(),
                    child: CreateMeetingScreen(existingDraft: note),
                  ),
                ),
              ).then((_) {
                if (context.mounted) Navigator.pop(context);
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMMM dd, yyyy').format(note.date),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 16),
                if (note.projectName != null) ...[
                  Icon(
                    Icons.folder_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    note.projectName!,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            if (note.participants.isNotEmpty) ...[
              Text(
                'Participants',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: note.participants
                    .map(
                      (p) => Chip(
                        avatar: CircleAvatar(
                          child: Text(p[0].toUpperCase()),
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.3),
                        ),
                        label: Text(p),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],
            if (note.keyPoints.isNotEmpty) ...[
              Text(
                'Meeting Highlights',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...note.keyPoints.map(
                (point) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(
                        color: _getTypeColor(point.type),
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getTypeIcon(point.type),
                        size: 18,
                        color: _getTypeColor(point.type),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          point.text,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'Full Transcript',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
              ),
              child: Text(
                note.content,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.85),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(MeetingPointType type) {
    switch (type) {
      case MeetingPointType.note:
        return Colors.blue;
      case MeetingPointType.decision:
        return Colors.purple;
      case MeetingPointType.action:
        return Colors.green;
      case MeetingPointType.blocker:
        return Colors.red;
    }
  }

  IconData _getTypeIcon(MeetingPointType type) {
    switch (type) {
      case MeetingPointType.note:
        return Icons.sticky_note_2_outlined;
      case MeetingPointType.decision:
        return Icons.check_circle_outline;
      case MeetingPointType.action:
        return Icons.task_alt;
      case MeetingPointType.blocker:
        return Icons.block;
    }
  }
}