import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class AiNote {
  final String id;
  final String title;
  final String summary;
  final DateTime date;
  final String pdfUrl;

  AiNote({
    required this.id,
    required this.title,
    required this.summary,
    required this.date,
    required this.pdfUrl,
  });
}

class ProjectAiNotesSection extends StatelessWidget {
  const ProjectAiNotesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final notes = [
      AiNote(
        id: '1',
        title: 'Sprint 14 Planning Meeting',
        summary:
            'The AI extracted 5 action items and 2 key decisions regarding the new payment gateway.',
        date: DateTime.now().subtract(const Duration(days: 1)),
        pdfUrl: 'https://example.com/sprint14.pdf',
      ),
      AiNote(
        id: '2',
        title: 'Client Feedback Session',
        summary:
            'Analyzed the client call. Main concern is the performance of the ERP dashboard.',
        date: DateTime.now().subtract(const Duration(days: 3)),
        pdfUrl: 'https://example.com/client_feedback.pdf',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Generated Meeting Summaries',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...notes.map(
          (note) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.purple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note.title,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd').format(note.date),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  note.summary,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Meeting_Report.pdf',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Opening PDF...')),
                          );
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
