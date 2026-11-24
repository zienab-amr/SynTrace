import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/knowledge_source_model.dart';
import '../cubit/meeting_notes_cubit.dart';
import '../cubit/meeting_notes_state.dart';
import '../widgets/details/meeting_details_error.dart';
import '../widgets/details/meeting_evidence_section.dart';
import '../widgets/details/meeting_header.dart';
import '../widgets/details/meeting_processing_section.dart';
import '../widgets/details/meeting_source_file_section.dart';
import '../widgets/details/meeting_transcript_section.dart';

class MeetingDetailsScreen extends StatefulWidget {
  final String meetingId;

  const MeetingDetailsScreen({super.key, required this.meetingId});

  @override
  State<MeetingDetailsScreen> createState() => _MeetingDetailsScreenState();
}

class _MeetingDetailsScreenState extends State<MeetingDetailsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<MeetingNotesCubit>().loadMeetingDetails(widget.meetingId);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshMeeting();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // Refresh Meeting
  // ═══════════════════════════════════════════

  Future<void> _refreshMeeting() async {
    final cubit = context.read<MeetingNotesCubit>();

    if (cubit.state.isRefreshingDetails ||
        cubit.state.isLoadingDetails ||
        cubit.state.isMutating) {
      return;
    }

    await cubit.loadMeetingDetails(widget.meetingId, silent: true);
  }

  // ═══════════════════════════════════════════
  // Retry Extraction
  // ═══════════════════════════════════════════

  Future<void> _retryExtraction(KnowledgeSourceDetails details) async {
    final cubit = context.read<MeetingNotesCubit>();

    final success = await cubit.retryExtraction(
      id: details.id,
      version: details.source.version,
    );

    if (!mounted) return;

    _showMessage(
      success
          ? 'Processing retry requested successfully.'
          : cubit.state.errorMessage ?? 'Failed to retry processing.',
    );
  }

  // ═══════════════════════════════════════════
  // Delete Meeting
  // ═══════════════════════════════════════════

  Future<void> _deleteMeeting(KnowledgeSourceDetails details) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('Delete Meeting'),
          content: Text(
            'Are you sure you want to delete '
            '"${details.title}"?\n\n'
            'This will withdraw the meeting source '
            'and its published results.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final cubit = context.read<MeetingNotesCubit>();

    if (!cubit.state.canUseSelectedMeeting ||
        cubit.state.selectedMeeting?.id != details.id) {
      _showMessage('Refresh the meeting before deleting it.');
      return;
    }
    final success = await cubit.deleteMeeting(details.id);

    if (!mounted) return;

    if (success) {
      _showMessage('Meeting deleted successfully.');
      Navigator.pop(context, true);
    } else {
      _showMessage(cubit.state.errorMessage ?? 'Failed to delete meeting.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ═══════════════════════════════════════════
  // Main UI
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<MeetingNotesCubit, MeetingNotesState>(
      builder: (context, state) {
        final selected = state.selectedMeeting;

        final details = selected?.id == widget.meetingId ? selected : null;

        final isBusy =
            state.isMutating ||
            state.isRefreshingDetails ||
            state.isLoadingDetails;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,

          appBar: AppBar(
            title: Text(
              details?.title ?? 'Meeting Details',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: theme.scaffoldBackgroundColor,

            actions: [
              IconButton(
                tooltip: 'Refresh meeting',
                onPressed: isBusy || state.isLoadingDetails
                    ? null
                    : _refreshMeeting,
                icon: const Icon(Icons.refresh_rounded),
              ),

              if (details != null)
                IconButton(
                  tooltip: 'Delete meeting',
                  onPressed: state.canUseSelectedMeeting
                      ? () => _deleteMeeting(details)
                      : null,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),

          body: _buildBody(state, details),
        );
      },
    );
  }

  Widget _buildBody(MeetingNotesState state, KnowledgeSourceDetails? details) {
    if (state.isDeleting && state.deletingId == widget.meetingId) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting meeting...'),
          ],
        ),
      );
    }

    if (details == null) {
      if (state.detailsStatus == MeetingRequestStatus.failure) {
        return MeetingDetailsError(state: state, onRetry: _refreshMeeting);
      }

      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (state.isLoadingDetails || state.isRefreshingDetails)
          const LinearProgressIndicator(minHeight: 2),
        if (state.hasDetailsRefreshError)
          _buildSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unable to update meeting'),
                Text(
                  '${state.detailsRefreshError!} Showing the last loaded information.',
                ),
                TextButton(
                  onPressed: _refreshMeeting,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshMeeting,

            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.all(20),

              children: [
                MeetingHeader(details: details, state: state),

                const SizedBox(height: 20),

                MeetingProcessingSection(
                  details: details,
                  state: state,
                  onRetry: () => _retryExtraction(details),
                ),

                const SizedBox(height: 24),

                MeetingEvidenceSection(details: details),

                if (details.sourceText?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 24),
                  MeetingTranscriptSection(details: details),
                ],

                if (details.hasSourceFile) ...[
                  const SizedBox(height: 24),
                  MeetingSourceFileSection(details: details),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSurface({required Widget child}) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),

      child: child,
    );
  }
}
