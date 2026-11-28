import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/features/projects/data/models/project_api_model.dart';
import 'package:syntrace/features/projects/data/projects_repository.dart';

import '../../data/repositories/meeting_contract_repository.dart';
import '../../data/repositories/meeting_notes_repository.dart';
import '../widgets/details/meeting_analysis_details.dart';
import 'meeting_document_screen.dart';

class MeetingContractScreen extends StatefulWidget {
  const MeetingContractScreen({
    super.key,
    this.initialMeetingId,
    this.repository,
  });
  final String? initialMeetingId;
  final MeetingContractRepository? repository;

  @override
  State<MeetingContractScreen> createState() => _MeetingContractScreenState();
}

class _MeetingContractScreenState extends State<MeetingContractScreen> {
  late final _api = widget.repository ?? MeetingContractRepository();
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _text = TextEditingController();
  final _id = TextEditingController();
  final _glossary = TextEditingController();
  Uint8List? _pdfBytes;
  String? _pdfName;
  static const _maxPdfBytes = 10500000;
  final _approve = <String>{};
  final _remove = <String>{};
  final _links = <String, Set<String>>{};
  Set<String>? _permissions;
  List<ProjectApiModel> _projects = [];
  Map<String, dynamic>? _meeting;
  String? _project;
  String? _error;
  String _type = 'online';
  DateTime _date = DateTime.now();
  Timer? _poll;
  bool _busy = false;
  String _section = 'Overview';
  final _recent = <String, String>{};

  bool get _canCreate =>
      _permissions?.containsAll({'Meetings.Create', 'Meetings.ReadPending'}) ??
      false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _title.dispose();
    _text.dispose();
    _id.dispose();
    _glossary.dispose();
    super.dispose();
  }

  Future<void> _load() => _perform(() async {
    final permissions = await _api.permissions();
    final projects =
        permissions.containsAll({'Meetings.Create', 'Meetings.ReadPending'})
        ? await ProjectsRepository().getProjects()
        : <ProjectApiModel>[];
    if (!mounted) return;
    setState(() {
      _permissions = permissions;
      _projects = projects;
    });
    final initial = widget.initialMeetingId;
    if (initial != null && _meeting == null) {
      _show(await _api.get(initial), reset: true);
    }
  });

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    _poll?.cancel();
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
      if (mounted) {
        setState(() => _busy = false);
        final current = _meeting;
        if (_error == null && current?['status'] == 'processing') {
          final id = current!['sourceId'] as String;
          _poll = Timer(
            const Duration(seconds: 3),
            () => _open(id, reset: false),
          );
        }
      }
    }
  }

  void _show(Map<String, dynamic> meeting, {bool reset = false}) {
    if (!mounted) return;
    final id = meeting['sourceId'] as String;
    setState(() {
      if (_meeting?['sourceId'] != id) _section = 'Overview';
      _meeting = meeting;
      _recent[id] = meeting['title']?.toString() ?? id;
      if (reset) {
        _id.text = id;
        _approve.clear();
        _remove.clear();
        _links.clear();
      }
    });
  }

  void _open(String id, {bool reset = true}) {
    if (id.isEmpty) return;
    unawaited(_perform(() async => _show(await _api.get(id), reset: reset)));
  }

  Future<void> _pickPdf() => _perform(() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withReadStream: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    if (file.size <= 0 || file.size > _maxPdfBytes) {
      setState(() => _error = 'Choose a PDF smaller than 10.5 MB.');
      return;
    }
    final stream = file.readStream;
    if (stream == null) throw const FormatException('Could not read the PDF.');
    final data = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (data.length + chunk.length > _maxPdfBytes) {
        throw const FormatException('Choose a PDF no larger than 10.5 MB.');
      }
      data.add(chunk);
    }
    final bytes = data.takeBytes();
    if (bytes.isEmpty) throw const FormatException('The PDF is empty.');
    if (!mounted) return;
    setState(() {
      _pdfBytes = bytes;
      _pdfName = file.name;
    });
  });

  Future<void> _openDocument(String id, String status) async {
    final canEdit =
        status == 'pending_review' &&
        (_permissions?.containsAll({'Meetings.Edit', 'Meetings.ReadPending'}) ??
            false);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingDocumentScreen(
          repository: _api,
          meetingId: id,
          canEdit: canEdit,
          canRewrite:
              canEdit && (_permissions?.contains('Meetings.UseAgent') ?? false),
        ),
      ),
    );
    if (mounted && result != null) _show(result, reset: true);
  }

  Future<void> _downloadPdf(String id) => _perform(() async {
    final bytes = await _api.requirementsPdf(id);
    if (!mounted) return;
    await FilePicker.platform.saveFile(
      fileName: 'requirements-$id.pdf',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
  });

  void _create() {
    final project = _project;
    if (!(_form.currentState?.validate() ?? false) || project == null) return;
    final bytes = _type == 'pdf' ? _pdfBytes : null;
    if (_type == 'pdf' && bytes == null) {
      setState(() => _error = 'Choose a PDF to continue.');
      return;
    }
    unawaited(
      _perform(() async {
        _show(
          await _api.create(
            projectId: project,
            sourceType: _type,
            title: _title.text.trim(),
            date: _date,
            text: bytes == null ? _text.text.trim() : null,
            pdfBase64: bytes == null ? null : base64Encode(bytes),
            glossary: _glossary.text
                .split(',')
                .map((term) => term.trim())
                .where((term) => term.isNotEmpty)
                .toSet()
                .toList(),
          ),
          reset: true,
        );
      }),
    );
  }

  void _review(String id) => unawaited(
    _perform(() async {
      _show(
        await _api.review(
          id,
          approve: _approve.toList(),
          delete: _remove.toList(),
          links: {
            for (final entry in _links.entries)
              if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
          },
        ),
        reset: true,
      );
    }),
  );

  @override
  Widget build(BuildContext context) {
    final meeting = _meeting;
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting AI')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error case final error?)
            Semantics(liveRegion: true, child: Text(error)),
          if (!_busy &&
              (_permissions == null ||
                  (_error != null &&
                      meeting == null &&
                      widget.initialMeetingId != null)))
            TextButton(onPressed: _load, child: const Text('Retry')),
          if (_permissions != null) ...[
            if (_canCreate)
              ExpansionTile(
                key: const PageStorageKey('meeting-create'),
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('Analyze a meeting'),
                subtitle: const Text('Transcript, notes or PDF'),
                children: [_createForm(context)],
              ),
            if (_permissions!.contains('Meetings.UseAgent') ||
                _permissions!.contains('Meetings.ReadApproved'))
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Meeting assistant'),
                subtitle: const Text(
                  'Ask about requirements and open questions',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.chat),
              ),
            const SizedBox(height: 24),
            ExpansionTile(
              title: const Text('Find a meeting'),
              leading: const Icon(Icons.search),
              children: [
                const ListTile(
                  subtitle: Text(
                    'Open a meeting by its ID. Meetings opened here are listed for this session.',
                  ),
                ),
                if (_recent.isNotEmpty) ...[
                  const ListTile(title: Text('Opened this session')),
                  for (final entry in _recent.entries.toList().reversed)
                    ListTile(
                      title: Text(entry.value),
                      onTap: _busy ? null : () => _open(entry.key),
                    ),
                ],
                TextField(
                  controller: _id,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Meeting ID'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _open(_id.text.trim()),
                  child: const Text('Open meeting'),
                ),
              ],
            ),
          ],
          if (meeting != null) _result(meeting),
        ],
      ),
    );
  }

  Widget _createForm(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Project'),
          items: [
            for (final project in _projects)
              DropdownMenuItem(value: project.id, child: Text(project.name)),
          ],
          onChanged: _busy ? null : (value) => _project = value,
          validator: (value) => value == null ? 'Select a project' : null,
        ),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Meeting type'),
          items: const [
            DropdownMenuItem(value: 'online', child: Text('Online')),
            DropdownMenuItem(value: 'offline', child: Text('Offline')),
            DropdownMenuItem(value: 'note', child: Text('Notes')),
            DropdownMenuItem(value: 'pdf', child: Text('PDF')),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value != null) setState(() => _type = value);
                },
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (date != null && mounted) setState(() => _date = date);
                },
          child: Text(
            'Meeting date: ${MaterialLocalizations.of(context).formatCompactDate(_date)}',
          ),
        ),
        TextFormField(
          controller: _title,
          enabled: !_busy,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (value) =>
              value?.trim().isNotEmpty == true ? null : 'Enter a title',
        ),
        if (_type == 'pdf')
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickPdf,
            icon: const Icon(Icons.attach_file),
            label: Text(_pdfName ?? 'Choose PDF'),
          )
        else
          TextFormField(
            controller: _text,
            enabled: !_busy,
            minLines: 4,
            maxLines: 10,
            maxLength: 400000,
            decoration: const InputDecoration(labelText: 'Transcript or notes'),
            validator: (value) => value?.trim().isNotEmpty == true
                ? null
                : 'Enter the meeting text',
          ),
        TextFormField(
          controller: _glossary,
          enabled: !_busy,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'Glossary (optional)',
            helperText: 'Separate terms with commas',
          ),
          validator: (value) =>
              (value ?? '')
                      .split(',')
                      .where((term) => term.trim().isNotEmpty)
                      .length >
                  200
              ? 'Enter no more than 200 terms'
              : null,
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: const Text('Analyze meeting'),
        ),
      ],
    ),
  );

  Widget _result(Map<String, dynamic> meeting) {
    final id = meeting['sourceId'] as String;
    final status = meeting['status'] as String;
    final canReview =
        status == 'pending_review' &&
        (_permissions?.containsAll({
              'Meetings.Approve',
              'Meetings.ReadPending',
            }) ??
            false);
    final items = meetingObjects(meeting['items']);
    final emptyReview =
        meeting['items'] is List && (meeting['items'] as List).isEmpty;
    final draftItems = items.where(
      (item) => meetingObjects(item['drafts']).isNotEmpty,
    );
    final historyItems = items.where(
      (item) =>
          meetingObjects(item['relatedEarlier']).isNotEmpty ||
          meetingObjects(item['answeredBy']).isNotEmpty,
    );
    final hasChanges =
        _approve.isNotEmpty ||
        _remove.isNotEmpty ||
        _links.values.any((keys) => keys.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          meeting['title']?.toString() ?? 'Meeting',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Semantics(
          liveRegion: true,
          child: Text(switch (status) {
            'processing' => 'Processing',
            'pending_review' => 'Pending review',
            'approved' => 'Approved',
            'failed' => 'Failed',
            _ => status,
          }),
        ),
        SelectableText('Meeting ID: $id'),
        for (final field in ['error', 'analysisError'])
          if (meeting[field] case final text?) SelectableText(text.toString()),
        if (meeting['linkedSourceId'] case final String originalId)
          TextButton.icon(
            icon: const Icon(Icons.link),
            label: const Text('Open original meeting'),
            onPressed: _busy ? null : () => _open(originalId),
          ),
        if (status == 'approved' && _canCreate)
          const ListTile(
            leading: Icon(Icons.note_alt_outlined),
            title: Text('Linked corrections'),
            subtitle: Text(
              'Creating a correction linked to this approved meeting requires server support.',
            ),
          ),
        if (status == 'failed')
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Analysis failed'),
            subtitle: Text(
              'You can submit the source as a new analysis. Retrying the original meeting requires server support.',
            ),
          ),
        if (status == 'pending_review' || status == 'approved')
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _openDocument(id, status),
                child: const Text('Meeting document'),
              ),
              if (status == 'approved' &&
                  (_permissions?.containsAll({
                        'Meetings.ReadApproved',
                        'Meetings.ExportPdf',
                      }) ??
                      false))
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _downloadPdf(id),
                  icon: const Icon(Icons.download),
                  label: const Text('Requirements PDF'),
                ),
            ],
          ),
        if (status == 'pending_review' || status == 'approved') ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final section in [
                'Overview',
                'Review items',
                'Project history',
                'Jira drafts',
              ])
                ChoiceChip(
                  label: Text(switch (section) {
                    'Review items' => 'Review items (${items.length})',
                    'Jira drafts' =>
                      'Jira drafts (${draftItems.fold<int>(0, (n, i) => n + meetingObjects(i['drafts']).length)})',
                    _ => section,
                  }),
                  selected: _section == section,
                  onSelected: (_) => setState(() => _section = section),
                ),
            ],
          ),
          if (_section == 'Overview') ...[
            if (meeting['summary'] case final String summary)
              SelectableText(summary),
            MeetingAnalysisOverview(meeting: meeting),
            if (meeting['notes'] case final String notes)
              ExpansionTile(
                title: const Text('Full meeting notes'),
                children: [SelectableText(notes)],
              ),
          ],
          if (_section == 'Review items') ...[
            if (emptyReview)
              const Text('No items were extracted from this meeting.'),
            ..._items(items, canReview),
          ],
          if (_section == 'Project history') ...[
            if (historyItems.isEmpty)
              const Text(
                'No earlier meetings or answers are linked to these items.',
              ),
            if (_permissions!.contains('Meetings.ReadApproved'))
              TextButton.icon(
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Ask about project requirements'),
                onPressed: () => context.push(AppRoutes.chat),
              ),
            for (final item in historyItems) ...[
              Text(
                item['text'].toString(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              MeetingItemHistory(item: item),
            ],
          ],
          if (_section == 'Jira drafts') ...[
            if (draftItems.isEmpty)
              const Text('This meeting has no Jira drafts.'),
            for (final item in draftItems) ...[
              Text(
                item['text'].toString(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              MeetingItemDrafts(item: item),
            ],
            if (draftItems.any(
              (i) =>
                  meetingObjects(i['drafts']).any((d) => d['jiraKey'] == null),
            ))
              const Text(
                'Creating Jira issues from drafts requires server support.',
              ),
          ],
        ],
        if (canReview &&
            (_section == 'Review items' || hasChanges || emptyReview))
          FilledButton(
            onPressed: _busy || (!hasChanges && !emptyReview)
                ? null
                : () => _review(id),
            child: Text(
              emptyReview ? 'Approve meeting without items' : 'Submit review',
            ),
          ),
        if (_error != null)
          TextButton(
            onPressed: _busy ? null : () => _open(id, reset: false),
            child: const Text('Refresh meeting'),
          ),
      ],
    );
  }

  bool _isProposal(Map<String, dynamic> item) =>
      (item['text'] as String? ?? '').startsWith('Proposed: ');

  List<Widget> _items(List<Map<String, dynamic>> items, bool canReview) {
    final proposals = items.where(_isProposal);
    final other = items.where((item) => !_isProposal(item));
    return [
      if (proposals.isNotEmpty) ...[
        Text(
          'Proposals to review',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final item in proposals) _item(item, canReview),
      ],
      if (other.isNotEmpty) ...[
        Text(
          'Extracted insights',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final item in other) _item(item, canReview),
      ],
    ];
  }

  Widget _item(Map<String, dynamic> item, bool canReview) {
    final id = item['id'] as String;
    final pending = canReview && item['status'] == 'pending';
    final lines = (item['evidenceLines'] as List? ?? const []).join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item['type']} · ${item['status']}'),
            SelectableText(item['text'].toString()),
            if (item['evidence'] case final evidence?)
              SelectableText(evidence.toString()),
            if (lines.isNotEmpty) Text('Evidence lines: $lines'),
            if (item['owner'] case final owner?) Text('Owner: $owner'),
            if (item['due'] case final due?) Text('Due: $due'),
            for (final key in (item['jiraLinks'] as List? ?? const []))
              Text('Jira: $key'),
            MeetingAnalysisItemDetails(item: item),
            if (pending)
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Approve'),
                    selected: _approve.contains(id),
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _approve.add(id);
                              _remove.remove(id);
                            } else {
                              _approve.remove(id);
                            }
                          }),
                  ),
                  FilterChip(
                    label: const Text('Remove'),
                    selected: _remove.contains(id),
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _remove.add(id);
                              _approve.remove(id);
                              _links.remove(id);
                            } else {
                              _remove.remove(id);
                            }
                          }),
                  ),
                  for (final suggestion
                      in (item['suggestedLinks'] as List? ?? const []))
                    if (suggestion is Map && suggestion['key'] is String)
                      _link(id, suggestion['key'] as String),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _link(String id, String key) => FilterChip(
    label: Text('Link $key'),
    selected: _links[id]?.contains(key) ?? false,
    onSelected: _busy || _remove.contains(id)
        ? null
        : (selected) => setState(() {
            if (selected) {
              (_links[id] ??= {}).add(key);
            } else {
              _links[id]?.remove(key);
            }
          }),
  );
}
