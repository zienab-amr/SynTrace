import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/meetings/data/models/meeting_note_model.dart';

void main() {
  group('MeetingNote Model Tests', () {
    test('copyWith creates a new instance with updated fields', () {
      final original = MeetingNote(
        id: '1',
        title: 'Sprint Planning',
        date: DateTime(2026, 11, 4),
        participants: const ['Rodaina', 'Zienab'],
        content: 'Discussing Jira integration',
        isDraft: false,
      );

      final updated = original.copyWith(
        title: 'Sprint Planning (Updated)',
        isDraft: true,
      );

      expect(updated.title, 'Sprint Planning (Updated)');
      expect(updated.isDraft, isTrue);
      expect(updated.participants.length, 2);
      expect(updated.id, original.id); 
    });
  });
}