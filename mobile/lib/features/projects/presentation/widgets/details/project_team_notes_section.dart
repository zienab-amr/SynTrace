import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/meetings/data/models/meeting_note_model.dart';
import 'package:syntrace/features/meetings/presentation/cubit/meeting_notes_cubit.dart';
import 'package:syntrace/features/meetings/presentation/cubit/meeting_notes_state.dart';
import 'package:syntrace/features/meetings/presentation/screens/create_meeting_screen.dart';
import 'package:syntrace/features/meetings/presentation/screens/meeting_details_screen.dart';

class ProjectTeamNotesSection extends StatelessWidget {
  final String projectId;
  const ProjectTeamNotesSection({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MeetingNotesCubit()..loadMeetings(),
      child: _ProjectTeamNotesView(projectId: projectId),
    );
  }
}

class _ProjectTeamNotesView extends StatelessWidget {
  final String projectId;
  const _ProjectTeamNotesView({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MeetingNotesCubit, MeetingNotesState>(
      builder: (context, state) {
        if (state is MeetingNotesLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (state is MeetingNotesLoaded) {
          final projectNotes = state.meetings
              .where((n) => n.projectId == projectId)
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Project Notes',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<MeetingNotesCubit>(),
                              child: CreateMeetingScreen(
                                initialProjectId: projectId,
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Note'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (projectNotes.isEmpty)
                Center(
                  child: Text(
                    'No notes for this project yet.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                )
              else
                ...projectNotes.map((note) => _NoteCard(note: note)),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final MeetingNote note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return GestureDetector(
      onTap: () {
        if (note.isDraft) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<MeetingNotesCubit>(),
                child: CreateMeetingScreen(existingDraft: note),
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MeetingDetailsScreen(note: note)),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: note.isDraft
                ? Colors.orange.withOpacity(0.5)
                : theme.dividerColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: note.isDraft
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    note.isDraft ? 'Draft' : 'AI Processed',
                    style: TextStyle(
                      color: note.isDraft ? Colors.orange : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              dateFormat.format(note.date),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${note.participants.length} participants',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
