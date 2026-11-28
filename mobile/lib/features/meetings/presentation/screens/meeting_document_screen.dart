import 'package:flutter/material.dart';

import '../../data/repositories/meeting_contract_repository.dart';
import '../../data/repositories/meeting_notes_repository.dart';

class MeetingDocumentScreen extends StatefulWidget {
  const MeetingDocumentScreen({
    super.key,
    required this.repository,
    required this.meetingId,
    required this.canEdit,
    required this.canRewrite,
  });

  final MeetingContractRepository repository;
  final String meetingId;
  final bool canEdit;
  final bool canRewrite;

  @override
  State<MeetingDocumentScreen> createState() => _MeetingDocumentScreenState();
}

class _MeetingDocumentScreenState extends State<MeetingDocumentScreen> {
  final _text = TextEditingController();
  final _instruction = TextEditingController();
  String? _savedText;
  String? _proposal;
  TextSelection? _rewritePart;
  TextSelection? _proposalPart;
  List<String> _warnings = [];
  String? _error;
  bool _busy = false;
  bool _editable = false;
  bool _confirmingDiscard = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    _instruction.dispose();
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
    final document = await widget.repository.document(widget.meetingId);
    if (!mounted) return;
    setState(() {
      _savedText = document['text'] as String;
      _text.text = _savedText!;
      _editable = widget.canEdit && document['status'] == 'pending_review';
    });
  });

  void _selectRewritePart() {
    final selection = _text.selection;
    if (!selection.isValid ||
        selection.isCollapsed ||
        selection.end > _text.text.length) {
      setState(() => _error = 'Select some meeting notes first.');
      return;
    }
    final selected = selection.textInside(_text.text);
    final first = selected.length - selected.trimLeft().length;
    final length = selected.trim().length;
    if (length == 0 || length > 8000) {
      setState(() => _error = 'Select between 1 and 8,000 characters.');
      return;
    }
    setState(() {
      _error = null;
      _rewritePart = TextSelection(
        baseOffset: selection.start + first,
        extentOffset: selection.start + first + length,
      );
      _proposal = null;
    });
  }

  Future<void> _rewrite() => _run(() async {
    final selection = _rewritePart;
    final result = await widget.repository.rewrite(
      widget.meetingId,
      _instruction.text.trim(),
      part: selection?.textInside(_text.text),
    );
    if (!mounted) return;
    setState(() {
      _proposal = result['proposal'] as String;
      _proposalPart = selection;
      _warnings = (result['warnings'] as List? ?? const [])
          .whereType<String>()
          .toList();
    });
  });

  Future<void> _save() => _run(() async {
    final result = await widget.repository.saveDocument(
      widget.meetingId,
      _text.text,
    );
    if (mounted) Navigator.pop(context, result);
  });

  Future<void> _confirmDiscard() async {
    if (_busy || _confirmingDiscard) return;
    _confirmingDiscard = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved edits?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard edits'),
          ),
        ],
      ),
    );
    _confirmingDiscard = false;
    if (mounted && discard == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final proposal = _proposal;
    final unchanged = _text.text == _savedText;
    final part = _proposalPart;
    final replacement = !unchanged || proposal == null
        ? null
        : part == null
        ? proposal
        : _text.text.replaceRange(part.start, part.end, proposal);
    return PopScope<Map<String, dynamic>>(
      canPop: !_busy && (_savedText == null || unchanged),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Meeting document')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error case final error?)
              Semantics(liveRegion: true, child: Text(error)),
            if (_savedText == null && !_busy)
              TextButton(onPressed: _load, child: const Text('Retry')),
            if (_savedText != null)
              if (_editable)
                TextField(
                  controller: _text,
                  enabled: !_busy,
                  minLines: 8,
                  maxLines: 18,
                  maxLength: 40000,
                  decoration: const InputDecoration(labelText: 'Meeting notes'),
                  onChanged: (_) => setState(() {}),
                )
              else
                SelectableText(_text.text),
            if (_editable && widget.canRewrite) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy || !unchanged ? null : _selectRewritePart,
                    child: const Text('Rewrite selected text'),
                  ),
                  if (_rewritePart != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _rewritePart = null;
                              _proposal = null;
                            }),
                      child: const Text('Use whole document instead'),
                    ),
                ],
              ),
              if (unchanged && _rewritePart != null)
                SelectableText(_rewritePart!.textInside(_text.text)),
              TextField(
                controller: _instruction,
                enabled: !_busy && unchanged,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'What should the AI change?',
                ),
                onChanged: (_) => setState(() {}),
              ),
              OutlinedButton(
                onPressed:
                    _busy || !unchanged || _instruction.text.trim().isEmpty
                    ? null
                    : _rewrite,
                child: const Text('Suggest a rewrite'),
              ),
              if (!unchanged)
                const Text(
                  'Save or undo your edits before asking for a rewrite.',
                ),
              if (proposal != null) ...[
                Text(
                  'Suggested rewrite',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SelectableText(proposal),
                for (final warning in _warnings) Text(warning),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed:
                          _busy ||
                              !unchanged ||
                              replacement == null ||
                              replacement.length > 40000
                          ? null
                          : () => setState(() {
                              _text.text = replacement;
                              _rewritePart = null;
                              _proposalPart = null;
                              _proposal = null;
                            }),
                      child: const Text('Use suggestion'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _proposal = null),
                      child: const Text('Dismiss suggestion'),
                    ),
                  ],
                ),
              ],
            ],
            if (_editable)
              FilledButton(
                onPressed:
                    _busy ||
                        unchanged ||
                        _text.text.trim().isEmpty ||
                        _text.text.length > 40000
                    ? null
                    : _save,
                child: const Text('Save meeting document'),
              ),
          ],
        ),
      ),
    );
  }
}
