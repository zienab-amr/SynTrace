import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';
import '../../data/models/meeting_note_model.dart';
import '../cubit/meeting_notes_cubit.dart';

class CreateMeetingScreen extends StatefulWidget {
  final MeetingNote? existingDraft;
  final String? initialProjectId;

  const CreateMeetingScreen({
    super.key,
    this.existingDraft,
    this.initialProjectId,
  });

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _participantsController;
  final _pointController = TextEditingController();

  List<MeetingPoint> _keyPoints = [];
  MeetingPointType _selectedType = MeetingPointType.note;
  String? _selectedProjectId;
  bool _isSaving = false;

  bool get isEditing =>
      widget.existingDraft != null && !widget.existingDraft!.isDraft;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingDraft?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existingDraft?.content ?? '',
    );
    _participantsController = TextEditingController(
      text: widget.existingDraft?.participants.join(', ') ?? '',
    );
    _keyPoints = List.from(widget.existingDraft?.keyPoints ?? []);
    _selectedProjectId =
        widget.existingDraft?.projectId ?? widget.initialProjectId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _participantsController.dispose();
    _pointController.dispose();
    super.dispose();
  }

  void _addPoint() {
    final text = _pointController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _keyPoints.add(MeetingPoint(text: text, type: _selectedType));
      _pointController.clear();
      _selectedType = MeetingPointType.note;
    });
  }

  void _handleBack() {
    final isNewNote = widget.existingDraft == null;
    final isEditingDraft =
        widget.existingDraft != null && widget.existingDraft!.isDraft;

    if (isNewNote || isEditingDraft) {
      if (_titleController.text.trim().isNotEmpty ||
          _contentController.text.trim().isNotEmpty ||
          _keyPoints.isNotEmpty) {
        final project = MockProjects.projects.firstWhere(
          (p) => p.id == _selectedProjectId,
          orElse: () => MockProjects.projects.first,
        );

        final draft = MeetingNote(
          id: widget.existingDraft?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim().isEmpty
              ? 'Untitled Draft'
              : _titleController.text.trim(),
          date: DateTime.now(),
          participants: _participantsController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          content: _contentController.text.trim(),
          isDraft: true,
          projectId: _selectedProjectId,
          projectName: _selectedProjectId != null ? project.name : null,
          keyPoints: _keyPoints,
        );
        context.read<MeetingNotesCubit>().saveDraft(draft);
      }
    }

    Navigator.pop(context);
  }

  void _saveMeeting() {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final project = MockProjects.projects.firstWhere(
      (p) => p.id == _selectedProjectId,
      orElse: () => MockProjects.projects.first,
    );

    final newNote = MeetingNote(
      id: widget.existingDraft?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      date: DateTime.now(),
      participants: _participantsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      content: _contentController.text.trim(),
      isDraft: false,
      projectId: _selectedProjectId,
      projectName: _selectedProjectId != null ? project.name : null,
      keyPoints: _keyPoints,
    );

    if (widget.existingDraft != null) {
      context.read<MeetingNotesCubit>().deleteMeeting(widget.existingDraft!.id);
    }

    context.read<MeetingNotesCubit>().addMeeting(newNote);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String appBarTitle = 'New Meeting Note';
    if (widget.existingDraft != null) {
      appBarTitle = widget.existingDraft!.isDraft
          ? 'Edit Draft'
          : 'Edit Meeting Note';
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
        title: Text(appBarTitle),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedProjectId,
                    isExpanded: true,
                    dropdownColor: theme.colorScheme.surface,
                    decoration: InputDecoration(
                      labelText: 'Assign to Project',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No Project (Unassigned)'),
                      ),
                      ...MockProjects.projects.map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedProjectId = val),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      context.push(AppRoutes.createProject);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Meeting Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _participantsController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Participants (comma separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Key Discussion Points',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: MeetingPointType.values.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(_getTypeLabel(type)),
                  selected: isSelected,
                  selectedColor: _getTypeColor(type).withOpacity(0.3),
                  onSelected: (_) => setState(() => _selectedType = type),
                  avatar: Icon(
                    _getTypeIcon(type),
                    size: 16,
                    color: _getTypeColor(type),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pointController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: const InputDecoration(
                      hintText: 'Add a point...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addPoint(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._keyPoints.asMap().entries.map((entry) {
              final index = entry.key;
              final point = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(
                      color: _getTypeColor(point.type),
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getTypeIcon(point.type),
                      size: 18,
                      color: _getTypeColor(point.type),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        point.text,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          setState(() => _keyPoints.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            Text(
              'Full Transcript',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 6,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Meeting notes',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMeeting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEditing ? 'Update Note' : 'Save Note',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(MeetingPointType type) {
    switch (type) {
      case MeetingPointType.note:
        return 'Note';
      case MeetingPointType.decision:
        return 'Decision';
      case MeetingPointType.action:
        return 'Action';
      case MeetingPointType.blocker:
        return 'Blocker';
    }
  }

  Color _getTypeColor(MeetingPointType type) {
    switch (type) {
      case MeetingPointType.note:
        return Colors.blue;
      case MeetingPointType.decision:
        return Colors.purple;
      case MeetingPointType.action:
        return Colors.green;
      case MeetingPointType.blocker:
        return Colors.red;
    }
  }

  IconData _getTypeIcon(MeetingPointType type) {
    switch (type) {
      case MeetingPointType.note:
        return Icons.sticky_note_2_outlined;
      case MeetingPointType.decision:
        return Icons.check_circle_outline;
      case MeetingPointType.action:
        return Icons.task_alt;
      case MeetingPointType.blocker:
        return Icons.block;
    }
  }
}