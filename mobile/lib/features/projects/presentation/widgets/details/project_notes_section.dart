import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

// 1. تعريف أنواع النوتس
enum NoteType { aiGenerated, developerNote }

// 2. الموديل
class ProjectNote {
  final String id;
  final String content;
  final String author;
  final DateTime timestamp;
  final NoteType type;
  final String? pdfUrl; // لو النوتة AI هتكون فيها لينك PDF

  ProjectNote({
    required this.id,
    required this.content,
    required this.author,
    required this.timestamp,
    required this.type,
    this.pdfUrl,
  });
}

class ProjectNotesSection extends StatefulWidget {
  final String projectId;
  const ProjectNotesSection({super.key, required this.projectId});

  @override
  State<ProjectNotesSection> createState() => _ProjectNotesSectionState();
}

class _ProjectNotesSectionState extends State<ProjectNotesSection> {
  final TextEditingController _controller = TextEditingController();

  // Mock Data للنوعين
  late List<ProjectNote> _notes;

  @override
  void initState() {
    super.initState();
    _notes = [
      ProjectNote(
        id: '1',
        content: 'Meeting Summary: Q4 Architecture Plan',
        author: 'AI Assistant (SynTrace)',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: NoteType.aiGenerated,
        pdfUrl: 'https://example.com/report.pdf', // لينك وهمي
      ),
      ProjectNote(
        id: '2',
        content:
            'We need to refactor the Auth service before adding the new payment gateway.',
        author: 'Ahmed Hassan',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        type: NoteType.developerNote,
      ),
      ProjectNote(
        id: '3',
        content:
            'Client requested a change in the color scheme. Check with design team.',
        author: 'Rodaina Mohamed',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: NoteType.developerNote,
      ),
    ];
  }

  void _addNote() {
    if (_controller.text.trim().isNotEmpty) {
      setState(() {
        _notes.insert(
          0,
          ProjectNote(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: _controller.text.trim(),
            author: 'You (Developer)',
            timestamp: DateTime.now(),
            type: NoteType.developerNote,
          ),
        );
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Input Field (Offline Note) ───
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                Icons.edit_note,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Write a new note for the team...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _addNote(),
                ),
              ),
              IconButton(
                onPressed: _addNote,
                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ─── Notes List ───
        ..._notes.map((note) => _buildNoteCard(context, note, theme)),
      ],
    );
  }

  Widget _buildNoteCard(
    BuildContext context,
    ProjectNote note,
    ThemeData theme,
  ) {
    final isAi = note.type == NoteType.aiGenerated;
    final color = isAi ? Colors.purple : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Author & Date & Type)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(
                    isAi ? Icons.auto_awesome : Icons.person,
                    size: 16,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.author,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${note.timestamp.hour}:${note.timestamp.minute.toString().padLeft(2, '0')} - ${note.timestamp.day}/${note.timestamp.month}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isAi ? 'AI GENERATED' : 'MANUAL NOTE',
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body (Content)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              note.content,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Attachment (لو النوتة AI وفيها PDF)
          if (isAi && note.pdfUrl != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting_Report.pdf',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Generated by AI',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Open PDF URL
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opening PDF... (Coming soon)'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download, color: AppColors.primary),
                    tooltip: 'Download PDF',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
