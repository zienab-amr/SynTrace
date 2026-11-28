import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/meeting_contract_repository.dart';
import '../../data/repositories/meeting_notes_repository.dart';

/// Questions asked in the project's approved meetings that no later meeting answered:
/// the list to bring to the next meeting with the client.
class OpenQuestionsScreen extends StatefulWidget {
  const OpenQuestionsScreen({
    super.key,
    required this.repository,
    required this.projectKey,
    required this.projectName,
  });

  final MeetingContractRepository repository;
  final String projectKey;
  final String projectName;

  @override
  State<OpenQuestionsScreen> createState() => _OpenQuestionsScreenState();
}

class _OpenQuestionsScreenState extends State<OpenQuestionsScreen> {
  List<Map<String, dynamic>>? _questions;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final found = await widget.repository.openQuestions(widget.projectKey);
      if (mounted) setState(() => _questions = found);
    } catch (error) {
      if (mounted) {
        setState(() => _error = MeetingNotesRepository.getErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    return Scaffold(
      appBar: AppBar(title: Text('Open questions · ${widget.projectName}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error case final error?) ...[
              Semantics(liveRegion: true, child: Text(error)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
            if (questions != null && questions.isEmpty)
              const Text('Every question from approved meetings has an answer.'),
            if (questions != null && questions.isNotEmpty)
              Text(
                '${questions.length} question${questions.length == 1 ? '' : 's'} to ask in the next meeting',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            for (final question in questions ?? const <Map<String, dynamic>>[])
              Card(
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: SelectableText(question['text']?.toString() ?? ''),
                  subtitle: Text(
                    [
                      if (question['meeting'] case final meeting?) '$meeting',
                      if (question['meetingDate'] case final date?) '$date',
                      if (question['quote'] case final quote?) '“$quote”',
                    ].join(' · '),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
