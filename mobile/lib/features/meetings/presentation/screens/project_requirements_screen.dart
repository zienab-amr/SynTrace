import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/meeting_contract_repository.dart';
import '../../data/repositories/meeting_notes_repository.dart';
import '../widgets/shared/text_edit_dialog.dart';

/// Every requirement of a project and its story across meetings: added, changed, cancelled,
/// restored or edited, with the quote and the meeting it came from.
class ProjectRequirementsScreen extends StatefulWidget {
  const ProjectRequirementsScreen({
    super.key,
    required this.repository,
    required this.projectKey,
    required this.projectName,
    required this.canEdit,
  });

  final MeetingContractRepository repository;
  final String projectKey;
  final String projectName;
  final bool canEdit;

  @override
  State<ProjectRequirementsScreen> createState() =>
      _ProjectRequirementsScreenState();
}

class _ProjectRequirementsScreenState extends State<ProjectRequirementsScreen> {
  static const maxRequirement = 400;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _requirements = [];
  String? _error;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
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

  Future<void> _load() => _run(() async {
    final found = await widget.repository.requirements(
      widget.projectKey,
      query: _search.text,
    );
    if (!mounted) return;
    setState(() {
      _requirements = found;
      _loaded = true;
    });
  });

  Future<void> _edit(Map<String, dynamic> requirement) async {
    final text = await TextEditDialog.show(
      context,
      TextEditDialog(
        title: 'Edit requirement',
        label: 'Requirement',
        action: 'Save',
        maxLength: maxRequirement,
        initialText: requirement['text']?.toString() ?? '',
      ),
    );
    if (text == null || text.isEmpty || text == requirement['text']) return;
    await _run(() async {
      final updated = await widget.repository.editRequirement(
        requirement['id'] as String,
        text,
      );
      if (!mounted) return;
      final byId = {for (final r in updated) r['id']: r};
      setState(() {
        _requirements = [
          for (final r in _requirements) byId[r['id']] ?? r,
        ];
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Requirements · ${widget.projectName}')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error case final error?)
          Semantics(liveRegion: true, child: Text(error)),
        TextField(
          controller: _search,
          enabled: !_busy,
          maxLength: 300,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => unawaited(_load()),
          decoration: InputDecoration(
            labelText: 'Search requirements',
            suffixIcon: IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: _busy ? null : () => unawaited(_load()),
            ),
          ),
        ),
        if (_loaded && _requirements.isEmpty)
          const Text('No requirements from approved meetings yet.'),
        for (final requirement in _requirements) _card(requirement),
      ],
    ),
  );

  Widget _card(Map<String, dynamic> requirement) {
    final changes = [
      for (final c in requirement['changes'] as List? ?? const [])
        if (c is Map) Map<String, dynamic>.from(c),
    ];
    return Card(
      child: ExpansionTile(
        title: SelectableText(requirement['text']?.toString() ?? ''),
        subtitle: Text(
          '${_status(requirement['status']?.toString())} · '
          '${changes.length} change${changes.length == 1 ? '' : 's'}',
        ),
        trailing: widget.canEdit
            ? IconButton(
                tooltip: 'Edit requirement',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _busy ? null : () => _edit(requirement),
              )
            : null,
        children: [
          for (final change in changes)
            ListTile(
              title: Text(_change(change)),
              subtitle: Text(
                [
                  if (change['meeting'] case final meeting?) '$meeting',
                  if (change['meetingDate'] case final date?) '$date',
                  if (change['by'] case final by?) 'by $by',
                  if (change['quote'] case final quote?) '“$quote”',
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
  }

  static String _status(String? status) => switch (status) {
    'active' => 'Active',
    'dropped' => 'Dropped',
    null => 'Unknown',
    _ => status,
  };

  static String _change(Map<String, dynamic> change) {
    final type = change['type']?.toString() ?? 'change';
    final before = change['before'];
    final after = change['after'];
    if (before != null && after != null) return '$type: $before → $after';
    return [type, ?(after ?? before), ?change['note']].join(': ');
  }
}
