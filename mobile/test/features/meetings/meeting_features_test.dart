import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/meetings/data/repositories/meeting_contract_repository.dart';
import 'package:syntrace/features/meetings/presentation/screens/live_meeting_screen.dart';
import 'package:syntrace/features/meetings/presentation/screens/meeting_contract_screen.dart';
import 'package:syntrace/features/meetings/presentation/screens/open_questions_screen.dart';
import 'package:syntrace/features/meetings/presentation/screens/project_requirements_screen.dart';
import 'package:syntrace/features/projects/data/models/project_api_model.dart';

class _Repository extends Fake implements MeetingContractRepository {
  Set<String> grants = {'Meetings.ReadApproved'};
  String status = 'approved';
  final calls = <String>[];
  String? lastQuery;
  List<String> lastDismiss = const [];
  String? endedTranscript;

  @override
  Future<Set<String>> permissions() async => grants;

  @override
  Future<Map<String, dynamic>> get(String id) async => {
    'sourceId': id,
    'title': 'Kickoff',
    'status': status,
    'projectKey': 'P1',
    'items': [
      {
        'id': 'i1',
        'type': 'requirement',
        'text': 'Login with SSO',
        'status': 'approved',
        'needsReview': false,
        'drafts': [
          {
            'id': 'd1',
            'title': 'SSO login',
            'status': 'approved',
            'jiraKey': calls.contains('publish d1') ? 'TEAM-9' : null,
          },
        ],
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> retry(String id) async {
    calls.add('retry $id');
    status = 'processing';
    return get(id);
  }

  @override
  Future<Map<String, dynamic>> publishDraft(String meetingId, String draftId) async {
    calls.add('publish $draftId');
    return {'jiraKey': 'TEAM-9', 'subtaskKeys': [], 'failedSubtasks': []};
  }

  @override
  Future<List<Map<String, dynamic>>> list(String projectKey, {String? status}) async {
    calls.add('list $projectKey ${status ?? 'all'}');
    return [
      {'sourceId': 'm1', 'title': 'Kickoff', 'status': 'approved', 'items': 3, 'toReview': 0},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> requirements(String projectKey, {String? query}) async {
    lastQuery = query;
    return [
      {
        'id': 'r1',
        'text': calls.contains('edit r1') ? 'Login with SSO and MFA' : 'Login with SSO',
        'status': 'active',
        'changes': [
          {'type': 'added', 'after': 'Login with SSO', 'meeting': 'Kickoff', 'meetingDate': '2026-11-20'},
        ],
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> editRequirement(String requirementId, String text) async {
    calls.add('edit $requirementId');
    expect(text, 'Login with SSO and MFA');
    return requirements('P1');
  }

  @override
  Future<List<Map<String, dynamic>>> openQuestions(String projectKey) async => [
    {'id': 'q1', 'text': 'Which identity provider?', 'meeting': 'Kickoff', 'meetingDate': '2026-11-20'},
  ];

  @override
  Future<Map<String, dynamic>> startLive(String projectKey, {String? title}) async {
    calls.add('start $projectKey');
    return {'sessionId': 's1', 'suggestions': []};
  }

  @override
  Future<Map<String, dynamic>> assistLive(
    String sessionId, {
    required String transcript,
    String? question,
    List<String> dismiss = const [],
  }) async {
    lastDismiss = dismiss;
    return {
      'suggestions': [
        {'id': 'g1', 'kind': 'ask_client', 'text': 'Ask which identity provider they use'},
      ],
      'answer': null,
    };
  }

  @override
  Future<Map<String, dynamic>> endLive(String sessionId, {String? transcript, DateTime? date}) async {
    endedTranscript = transcript;
    return {
      'sessionId': sessionId,
      'status': 'ended',
      'sourceId': transcript == null ? null : 'live-1',
      'nextMeeting': {'notAsked': [], 'openQuestions': []},
    };
  }
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  const project = ProjectApiModel(id: 'P1', name: 'Portal', clientId: 'c1');

  testWidgets('a failed meeting is retried without uploading it again', (tester) async {
    final repository = _Repository()
      ..status = 'failed'
      ..grants = {'Meetings.Create', 'Meetings.ReadPending'};
    await _pump(
      tester,
      MeetingContractScreen(
        initialMeetingId: 'm1',
        repository: repository,
        loadProjects: () async => [project],
      ),
    );
    final retry = find.text('Retry analysis');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pump();
    expect(repository.calls, contains('retry m1'));
    // stop the poll the processing state starts
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an approved draft is published to Jira', (tester) async {
    final repository = _Repository()
      ..grants = {'Meetings.ReadApproved', 'Meetings.PublishJiraTasks'};
    await _pump(
      tester,
      MeetingContractScreen(
        initialMeetingId: 'm1',
        repository: repository,
        loadProjects: () async => [project],
      ),
    );
    final drafts = find.textContaining('Jira drafts');
    await tester.ensureVisible(drafts);
    await tester.pumpAndSettle();
    await tester.tap(drafts);
    await tester.pumpAndSettle();
    final publish = find.text('Publish "SSO login" to Jira');
    await tester.ensureVisible(publish);
    await tester.pumpAndSettle();
    await tester.tap(publish);
    await tester.pumpAndSettle();
    expect(repository.calls, contains('publish d1'));
    expect(find.text('Created TEAM-9.'), findsOneWidget);
    expect(publish, findsNothing);
  });

  testWidgets('the project meetings list opens a meeting', (tester) async {
    final repository = _Repository();
    await _pump(
      tester,
      MeetingContractScreen(repository: repository, loadProjects: () async => [project]),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portal').last);
    await tester.pumpAndSettle();
    expect(repository.calls, contains('list P1 all'));
    expect(find.textContaining('3 items'), findsOneWidget);
    await tester.tap(find.text('Kickoff'));
    await tester.pumpAndSettle();
    expect(find.text('Approved'), findsWidgets);
  });

  testWidgets('requirements are searched and edited', (tester) async {
    final repository = _Repository();
    await _pump(
      tester,
      ProjectRequirementsScreen(
        repository: repository,
        projectKey: 'P1',
        projectName: 'Portal',
        canEdit: true,
      ),
    );
    expect(find.text('Login with SSO'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'login');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.lastQuery, 'login');
    await tester.tap(find.byTooltip('Edit requirement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Login with SSO and MFA');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Login with SSO and MFA'), findsOneWidget);
  });

  testWidgets('open questions are listed for the next meeting', (tester) async {
    await _pump(
      tester,
      OpenQuestionsScreen(repository: _Repository(), projectKey: 'P1', projectName: 'Portal'),
    );
    expect(find.text('Which identity provider?'), findsOneWidget);
    expect(find.text('1 question to ask in the next meeting'), findsOneWidget);
  });

  testWidgets('live help: start, get suggestions, dismiss one, end and send for review', (tester) async {
    final repository = _Repository();
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              opened = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => LiveMeetingScreen(
                    repository: repository,
                    projects: const [(key: 'P1', name: 'Portal')],
                    canSendForReview: true,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start live help'));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('start P1'));
    await tester.enterText(find.byType(TextField).first, 'Client: we need SSO');
    await tester.tap(find.text('Get help'));
    await tester.pumpAndSettle();
    expect(find.text('Ask which identity provider they use'), findsOneWidget);
    await tester.tap(find.byTooltip('Asked or not needed'));
    await tester.pumpAndSettle();
    expect(find.text('Ask which identity provider they use'), findsNothing);
    await tester.tap(find.text('Get help'));
    await tester.pumpAndSettle();
    expect(repository.lastDismiss, ['g1']);
    await tester.tap(find.text('End meeting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send for review'));
    await tester.pumpAndSettle();
    expect(repository.endedTranscript, 'Client: we need SSO');
    await tester.tap(find.text('Open the meeting for review'));
    await tester.pumpAndSettle();
    expect(opened, 'live-1');
  });
}
