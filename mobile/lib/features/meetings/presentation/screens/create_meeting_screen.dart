import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/knowledge_source_model.dart';
import '../../data/models/meeting_note_model.dart';
import '../cubit/meeting_notes_cubit.dart';
import '../cubit/meeting_notes_state.dart';
import '../widgets/create/meeting_mode_selector.dart';
import '../widgets/create/meeting_date_selector.dart';
import '../widgets/create/meeting_client_selector.dart';
import '../widgets/create/meeting_transcript_field.dart';
import '../widgets/create/meeting_processing_info.dart';
import '../widgets/create/meeting_submit_button.dart';
import '../widgets/create/meeting_discussion_points.dart';
import '../widgets/create/meeting_point_style.dart';

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
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _participantsController;

  final _pointController = TextEditingController();

  List<MeetingPoint> _keyPoints = [];

  MeetingPointType _selectedType = MeetingPointType.note;

  KnowledgeMeetingMode _meetingMode = KnowledgeMeetingMode.online;

  String? _selectedClientId;

  DateTime _meetingDate = DateTime.now();

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

    _meetingDate = widget.existingDraft?.date ?? DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final cubit = context.read<MeetingNotesCubit>();

      cubit.resetCreateStatus();
      cubit.loadClients();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _participantsController.dispose();
    _pointController.dispose();

    super.dispose();
  }

  // ═══════════════════════════════════════════
  // Discussion Points
  // ═══════════════════════════════════════════

  void _addPoint() {
    if (context.read<MeetingNotesCubit>().state.isMutating) return;
    final text = _pointController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _keyPoints.add(MeetingPoint(text: text, type: _selectedType));

      _pointController.clear();
      _selectedType = MeetingPointType.note;
    });
  }

  // ═══════════════════════════════════════════
  // Prepare Source Text
  // ═══════════════════════════════════════════

  String _buildSourceText() {
    final buffer = StringBuffer();

    final participants = _participantsController.text.trim();

    if (participants.isNotEmpty) {
      buffer.writeln('Participants:');
      buffer.writeln(participants);
      buffer.writeln();
    }

    if (_keyPoints.isNotEmpty) {
      buffer.writeln('Key Discussion Points:');

      for (final point in _keyPoints) {
        buffer.writeln('- ${meetingPointLabel(point.type)}: ${point.text}');
      }

      buffer.writeln();
    }

    final transcript = _contentController.text.trim();

    if (transcript.isNotEmpty) {
      buffer.writeln('Meeting Transcript:');
      buffer.writeln(transcript);
    }

    return buffer.toString().trim();
  }

  // ═══════════════════════════════════════════
  // Submit Meeting
  // ═══════════════════════════════════════════

  Future<void> _saveMeeting() async {
    final cubit = context.read<MeetingNotesCubit>();

    if (cubit.state.isMutating) return;

    if (!_formKey.currentState!.validate()) return;

    if (!cubit.state.clients.any((client) => client.id == _selectedClientId)) {
      _showMessage('Please select a client.');
      return;
    }

    if (_pointController.text.trim().isNotEmpty) {
      _showMessage('Please add or clear the unfinished discussion point.');
      return;
    }

    if (_contentController.text.trim().isEmpty && _keyPoints.isEmpty) {
      _showMessage('Please enter meeting notes or discussion points.');
      return;
    }

    final sourceText = _buildSourceText();

    if (sourceText.length > 256000) {
      _showMessage('Meeting content is too long.');
      return;
    }

    final request = CreateKnowledgeSourceRequest(
      clientId: _selectedClientId!,
      projectId: null,
      kind: KnowledgeSourceKind.meetingNotes,
      title: _titleController.text.trim(),
      text: sourceText,
      meetingMode: _meetingMode,
      meetingAt: _meetingDate,
    );

    final result = await cubit.createMeeting(request);

    if (!mounted) return;

    if (result != null) {
      Navigator.pop(context, true);
    } else {
      _showMessage(cubit.state.errorMessage ?? 'Failed to create meeting.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ═══════════════════════════════════════════
  // Discard Confirmation
  // ═══════════════════════════════════════════

  Future<void> _handleBack() async {
    if (context.read<MeetingNotesCubit>().state.isCreating) {
      return;
    }

    final hasContent =
        _titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty ||
        _participantsController.text.trim().isNotEmpty ||
        _pointController.text.trim().isNotEmpty ||
        _keyPoints.isNotEmpty;

    if (!hasContent) {
      Navigator.pop(context);
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard meeting?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) {
      Navigator.pop(context);
    }
  }

  // ═══════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<MeetingNotesCubit, MeetingNotesState>(
      builder: (context, state) {
        final isSaving = state.isCreating;

        return PopScope(
          canPop: !isSaving,
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: isSaving ? null : _handleBack,
              ),
              title: const Text('New Meeting Note'),
              backgroundColor: theme.scaffoldBackgroundColor,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MeetingClientSelector(
                      clients: state.clients,
                      selectedClientId: _selectedClientId,
                      isLoading: state.isLoadingClients,
                      errorMessage:
                          state.clientsStatus == MeetingRequestStatus.failure
                          ? state.errorMessage ?? 'Failed to load clients.'
                          : null,
                      enabled: !isSaving,
                      onChanged: (value) =>
                          setState(() => _selectedClientId = value),
                      onRetry: () =>
                          context.read<MeetingNotesCubit>().loadClients(),
                    ),

                    const SizedBox(height: 16),

                    MeetingModeSelector(
                      value: _meetingMode,
                      enabled: !isSaving,
                      onChanged: (value) =>
                          setState(() => _meetingMode = value),
                    ),

                    const SizedBox(height: 16),

                    MeetingDateSelector(
                      value: _meetingDate,
                      enabled: !isSaving,
                      onChanged: (value) =>
                          setState(() => _meetingDate = value),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _titleController,
                      enabled: !isSaving,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Meeting Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Meeting title is required';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _participantsController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Participants',
                        hintText: 'Comma separated names',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    MeetingDiscussionPoints(
                      controller: _pointController,
                      points: _keyPoints,
                      selectedType: _selectedType,
                      enabled: !isSaving,
                      onTypeChanged: (value) =>
                          setState(() => _selectedType = value),
                      onAdd: _addPoint,
                      onRemove: (index) =>
                          setState(() => _keyPoints.removeAt(index)),
                    ),
                    const SizedBox(height: 24),
                    MeetingTranscriptField(
                      controller: _contentController,
                      enabled: !isSaving,
                    ),

                    const SizedBox(height: 16),

                    const MeetingProcessingInfo(),

                    const SizedBox(height: 24),

                    MeetingSubmitButton(
                      isLoading: isSaving,
                      enabled:
                          !state.isMutating &&
                          !state.isLoadingClients &&
                          state.clientsStatus == MeetingRequestStatus.success &&
                          state.clients.any(
                            (client) => client.id == _selectedClientId,
                          ),
                      onPressed: _saveMeeting,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
