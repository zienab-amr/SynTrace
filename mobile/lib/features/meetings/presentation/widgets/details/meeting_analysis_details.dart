import 'package:flutter/material.dart';

List<Map<String, dynamic>> meetingObjects(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().where((text) => text.trim().isNotEmpty).toList()
    : const [];

class MeetingAnalysisOverview extends StatelessWidget {
  const MeetingAnalysisOverview({super.key, required this.meeting});
  final Map<String, dynamic> meeting;

  @override
  Widget build(BuildContext context) {
    final scope = meeting['scope'];
    final items = {
      for (final item in meetingObjects(meeting['items']))
        if (item['id'] is String && item['text'] is String)
          item['id'] as String: item['text'] as String,
    };
    Iterable<String> scopeText(Object? ids) =>
        _strings(ids).map((id) => items[id]).whereType<String>();
    final references = _strings(meeting['unresolvedReferences']);
    final rejected = meeting['rejectedItems'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scope is Map) ...[
          _details('Agreed scope', scopeText(scope['agreed'])),
          _details('Out of scope', scopeText(scope['outOfScope'])),
          _details('Open points', scopeText(scope['open'])),
        ],
        _details('Unresolved Jira references', references),
        if (rejected is num && rejected > 0)
          Text('Items rejected during extraction: $rejected'),
      ],
    );
  }
}

class MeetingAnalysisItemDetails extends StatelessWidget {
  const MeetingAnalysisItemDetails({super.key, required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item['needsReview'] == true)
          const Chip(label: Text('Needs review')),
        _details('Speaker', [item['speaker']]),
        _details('Relationship to existing work', [
          item['relation'],
          item['relationNote'],
          ..._strings(item['relatedKeys']),
        ]),
        _details('User story', [item['userStory']]),
        _details('Category and clarity', [item['category'], item['clarity']]),
        _details('Clarifying question', [item['clarifyingQuestion']]),
        _details('Priority', [item['priority'], item['priorityQuote']]),
        _details(
          'Acceptance criteria stated in the meeting',
          _strings(item['acceptanceSaid']),
        ),
        _details(
          'Suggested acceptance criteria',
          _strings(item['acceptanceSuggested']),
        ),
        MeetingItemHistory(item: item),
        MeetingItemDrafts(item: item),
      ],
    );
  }
}

class MeetingItemDrafts extends StatelessWidget {
  const MeetingItemDrafts({super.key, required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final draft in meetingObjects(item['drafts']))
        ExpansionTile(
          title: Text(draft['title']?.toString() ?? 'Jira draft'),
          subtitle: Text(
            [
              if (draft['status'] != null) draft['status'],
              if (draft['jiraKey'] != null) draft['jiraKey'],
              if (draft['stale'] == true) 'Needs refresh',
            ].join(' · '),
          ),
          childrenPadding: const EdgeInsets.all(12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _details('Description', [draft['description']]),
            _details('Acceptance criteria', _strings(draft['acceptance'])),
            _details(
              'Subtasks',
              (draft['subtasks'] as List? ?? const []).map(
                (task) =>
                    task is Map ? (task['title'] ?? task['summary']) : task,
              ),
            ),
            _details('Estimate', [
              if (draft['storyPoints'] != null)
                "${draft['storyPoints']} story points",
              if (draft['estimateHours'] != null)
                "${draft['estimateHours']} hours",
              ..._strings(draft['estimateBasedOn']),
            ]),
          ],
        ),
    ],
  );
}

class MeetingItemHistory extends StatelessWidget {
  const MeetingItemHistory({super.key, required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _details(
        'Answered by',
        meetingObjects(item['answeredBy']).map(_meetingReference),
      ),
      _details(
        'Related earlier meetings',
        meetingObjects(item['relatedEarlier']).map(_meetingReference),
      ),
    ],
  );
  String _meetingReference(Map<String, dynamic> entry) => [
    entry['title'],
    entry['meetingDate'],
    entry['text'],
  ].whereType<String>().where((text) => text.isNotEmpty).join(' · ');
}

Widget _details(String label, Iterable<Object?> values) {
  final text = values.whereType<String>().where(
    (value) => value.trim().isNotEmpty,
  );
  if (text.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        for (final line in text) SelectableText(line),
      ],
    ),
  );
}
