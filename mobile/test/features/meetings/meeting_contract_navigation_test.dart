import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';
import 'package:syntrace/features/meetings/data/repositories/meeting_contract_repository.dart';
import 'package:syntrace/features/meetings/presentation/screens/meeting_contract_screen.dart';

class _Repository extends Fake implements MeetingContractRepository {
  bool approved = false;
  @override
  Future<Set<String>> permissions() async => {
    'Meetings.ReadPending',
    'Meetings.Approve',
  };

  @override
  Future<Map<String, dynamic>> get(String id) async => {
    'sourceId': id,
    'title': 'Sprint planning',
    'status': approved ? 'approved' : 'pending_review',
    'items': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> review(
    String id, {
    required List<String> approve,
    required List<String> delete,
    required Map<String, List<String>> links,
  }) async {
    expect(approve, isEmpty);
    expect(delete, isEmpty);
    expect(links, isEmpty);
    approved = true;
    return get(id);
  }
}

void main() {
  testWidgets(
    'open a meeting from chat, inspect drafts and approve an empty extraction',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: MeetingContractScreen(
            initialMeetingId: 'abc',
            repository: repository,
            loadProjects: () async => [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sprint planning'), findsOneWidget);
      await tester.tap(find.text('Jira drafts (0)'));
      await tester.pumpAndSettle();
      expect(find.text('This meeting has no Jira drafts.'), findsOneWidget);
      final approve = find.text('Approve meeting without items');
      await tester.ensureVisible(approve);
      await tester.pumpAndSettle();
      await tester.tap(approve);
      await tester.pumpAndSettle();
      expect(repository.approved, isTrue);
      // the status line, beside the project meetings filter chip of the same name
      expect(find.text('Approved'), findsWidgets);
      expect(find.text('Pending review'), findsOneWidget);
      expect(approve, findsNothing);
    },
  );
  test('meeting choices and review link survive chat serialization', () {
    final reply = ChatMessage.fromJson({
      'id': 'ai-1',
      'role': 'ai',
      'content': 'Review ready',
      'timestamp': '2026-01-01',
      'meeting': {
        'sourceId': 'abc',
        'choices': ['Delivery', 'Billing'],
      },
    });
    final restored = ChatMessage.fromJson(reply.copyWith().toJson());
    expect(restored.meetingSourceId, 'abc');
    expect(restored.choices, ['Delivery', 'Billing']);
  });
}
