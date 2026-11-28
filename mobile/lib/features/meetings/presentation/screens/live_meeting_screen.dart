import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/meeting_contract_repository.dart';
import '../../data/repositories/meeting_notes_repository.dart';

/// A project the live meeting can belong to.
typedef LiveProject = ({String key, String name});

/// Help during a client meeting: paste the transcript as it grows and get questions to ask,
/// missing details, conflicts and risks. Nothing reaches Jira or the project's memory before the
/// meeting is reviewed and approved. Ending can send the transcript for review as a meeting; the
/// screen then pops with that meeting's id.
class LiveMeetingScreen extends StatefulWidget {
  const LiveMeetingScreen({
    super.key,
    required this.repository,
    required this.projects,
    required this.canSendForReview,
  });

  final MeetingContractRepository repository;
  final List<LiveProject> projects;
  final bool canSendForReview;

  @override
  State<LiveMeetingScreen> createState() => _LiveMeetingScreenState();
}

class _LiveMeetingScreenState extends State<LiveMeetingScreen> {
  static const maxTranscript = 400000;
  final _title = TextEditingController();
  final _transcript = TextEditingController();
  final _question = TextEditingController();
  final _dismissed = <String>{};
  String? _project;
  String? _session;
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _wrapUp = [];
  Map<String, dynamic>? _answer;
  Map<String, dynamic>? _ended;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _transcript.dispose();
    _question.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = MeetingNotesRepository.getErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static List<Map<String, dynamic>> _rows(Object? value) => [
    for (final row in value as List? ?? const [])
      if (row is Map) Map<String, dynamic>.from(row),
  ];

  void _start() {
    final project = _project;
    if (project == null) {
      setState(() => _error = 'Select a project');
      return;
    }
    unawaited(
      _run(() async {
        final view = await widget.repository.startLive(
          project,
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _session = view['sessionId'] as String;
          _suggestions = _rows(view['suggestions']);
        });
      }),
    );
  }

  void _assist() => unawaited(
    _run(() async {
      final question = _question.text.trim();
      final result = await widget.repository.assistLive(
        _session!,
        transcript: _transcript.text,
        question: question.isEmpty ? null : question,
        dismiss: _dismissed.toList(),
      );
      if (!mounted) return;
      setState(() {
        final known = {for (final s in _suggestions) s['id']};
        _suggestions = [
          ..._suggestions,
          for (final s in _rows(result['suggestions']))
            if (!known.contains(s['id']) && !_dismissed.contains(s['id'])) s,
        ];
        _answer = result['answer'] is Map
            ? Map<String, dynamic>.from(result['answer'] as Map)
            : null;
        if (question.isNotEmpty) _question.clear();
      });
    }),
  );

  void _dismiss(String id) => setState(() {
    _dismissed.add(id);
    _suggestions = [
      for (final s in _suggestions)
        if (s['id'] != id) s,
    ];
  });

  void _wrap() {
    if (_transcript.text.trim().isEmpty) {
      setState(() => _error = 'Paste the transcript before the wrap-up.');
      return;
    }
    unawaited(_wrapNow());
  }

  Future<void> _wrapNow() => _run(() async {
      final result = await widget.repository.wrapUpLive(
        _session!,
        _transcript.text,
      );
      if (mounted) setState(() => _wrapUp = _rows(result['suggestions']));
    });

  Future<void> _end() async {
    final hasText = _transcript.text.trim().isNotEmpty;
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End the meeting?'),
        content: Text(
          hasText && widget.canSendForReview
              ? 'Send the transcript for review as a meeting? Its items reach the project only after approval.'
              : 'The help from this session is kept until it ends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (hasText && widget.canSendForReview)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('End without sending'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, hasText && widget.canSendForReview),
            child: Text(
              hasText && widget.canSendForReview ? 'Send for review' : 'End',
            ),
          ),
        ],
      ),
    );
    if (send == null) return;
    await _run(() async {
      final result = await widget.repository.endLive(
        _session!,
        transcript: send ? _transcript.text : null,
        date: send ? DateTime.now() : null,
      );
      if (mounted) setState(() => _ended = result);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Live meeting assistant')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error case final error?)
          Semantics(liveRegion: true, child: Text(error)),
        if (_session == null) ..._startForm(),
        if (_session != null && _ended == null) ..._live(context),
        if (_ended case final ended?) ..._summary(context, ended),
      ],
    ),
  );

  List<Widget> _startForm() => [
    const Text(
      'Get questions to ask, missing details and conflicts while the meeting is going on.',
    ),
    DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Project'),
      items: [
        for (final project in widget.projects)
          DropdownMenuItem(value: project.key, child: Text(project.name)),
      ],
      onChanged: _busy ? null : (value) => setState(() => _project = value),
    ),
    TextField(
      controller: _title,
      enabled: !_busy,
      maxLength: 300,
      decoration: const InputDecoration(labelText: 'Meeting title (optional)'),
    ),
    FilledButton(
      onPressed: _busy || _project == null ? null : _start,
      child: const Text('Start live help'),
    ),
  ];

  List<Widget> _live(BuildContext context) => [
    TextField(
      controller: _transcript,
      enabled: !_busy,
      minLines: 6,
      maxLines: 14,
      maxLength: maxTranscript,
      decoration: const InputDecoration(
        labelText: 'Transcript so far',
        helperText: 'Paste the whole transcript each time; only new lines are read.',
      ),
    ),
    TextField(
      controller: _question,
      enabled: !_busy,
      maxLength: 400,
      decoration: const InputDecoration(
        labelText: 'Ask about the project (optional)',
      ),
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : _assist,
          icon: const Icon(Icons.tips_and_updates_outlined),
          label: const Text('Get help'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _wrap,
          child: const Text('Wrap up'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _end,
          child: const Text('End meeting'),
        ),
      ],
    ),
    if (_answer case final answer?)
      Card(
        child: ListTile(
          leading: const Icon(Icons.question_answer_outlined),
          title: SelectableText(answer['text']?.toString() ?? ''),
          subtitle: answer['quote'] == null
              ? null
              : Text('“${answer['quote']}”'),
        ),
      ),
    if (_wrapUp.isNotEmpty) ...[
      Text(
        'Before you end',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      for (final s in _wrapUp) _suggestion(s, dismissible: false),
    ],
    if (_suggestions.isNotEmpty)
      Text('Suggestions', style: Theme.of(context).textTheme.titleMedium)
    else
      const Text('No suggestions yet. Paste the transcript and tap Get help.'),
    for (final s in _suggestions) _suggestion(s, dismissible: true),
  ];

  Widget _suggestion(Map<String, dynamic> s, {required bool dismissible}) {
    final ref = s['ref'] is Map ? Map<String, dynamic>.from(s['ref'] as Map) : null;
    return Card(
      child: ListTile(
        leading: Icon(switch (s['kind']) {
          'ask_client' => Icons.record_voice_over_outlined,
          'missing' => Icons.playlist_add_outlined,
          'conflict' => Icons.compare_arrows,
          'risk' => Icons.warning_amber_outlined,
          'reminder' => Icons.history,
          _ => Icons.info_outline,
        }),
        title: SelectableText(s['text']?.toString() ?? ''),
        subtitle: Text(
          [
            _kind(s['kind']?.toString()),
            if (s['quote'] case final quote?) '“$quote”',
            if (ref != null) 'Earlier: ${ref['text']}',
          ].join(' · '),
        ),
        trailing: dismissible
            ? IconButton(
                tooltip: 'Asked or not needed',
                icon: const Icon(Icons.check),
                onPressed: _busy ? null : () => _dismiss(s['id'] as String),
              )
            : null,
      ),
    );
  }

  static String _kind(String? kind) => switch (kind) {
    'ask_client' => 'Ask the client',
    'missing' => 'Missing detail',
    'conflict' => 'Conflict',
    'reminder' => 'Reminder',
    'risk' => 'Risk',
    'unverified' => 'Not confirmed',
    _ => 'Suggestion',
  };

  List<Widget> _summary(BuildContext context, Map<String, dynamic> ended) {
    final next = ended['nextMeeting'] is Map
        ? Map<String, dynamic>.from(ended['nextMeeting'] as Map)
        : const <String, dynamic>{};
    final notAsked = _rows(next['notAsked']);
    final open = _rows(next['openQuestions']);
    final sourceId = ended['sourceId'] as String?;
    return [
      Text('Meeting ended', style: Theme.of(context).textTheme.titleLarge),
      if (sourceId != null)
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, sourceId),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Open the meeting for review'),
        ),
      Text(
        'For the next meeting',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (notAsked.isEmpty && open.isEmpty)
        const Text('Nothing left to ask.'),
      for (final item in notAsked)
        ListTile(
          leading: const Icon(Icons.record_voice_over_outlined),
          title: Text(item['text']?.toString() ?? ''),
          subtitle: Text(_kind(item['kind']?.toString())),
        ),
      for (final question in open)
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(question['text']?.toString() ?? ''),
          subtitle: Text(
            [
              if (question['meeting'] case final meeting?) '$meeting',
              if (question['meetingDate'] case final date?) '$date',
            ].join(' · '),
          ),
        ),
    ];
  }
}
