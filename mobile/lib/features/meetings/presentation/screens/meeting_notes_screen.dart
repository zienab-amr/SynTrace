import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

import '../cubit/meeting_notes_cubit.dart';
import '../cubit/meeting_notes_state.dart';
import '../widgets/list/meetings_toolbar.dart';
import '../widgets/list/meetings_list.dart';
import '../widgets/shared/meeting_refresh_banner.dart';
import '../widgets/shared/meeting_empty_view.dart';
import '../widgets/shared/meeting_error_view.dart';

import 'create_meeting_screen.dart';
import 'meeting_details_screen.dart';

class MeetingNotesScreen extends StatefulWidget {
  const MeetingNotesScreen({super.key});

  @override
  State<MeetingNotesScreen> createState() => _MeetingNotesScreenState();
}

class _MeetingNotesScreenState extends State<MeetingNotesScreen> {
  @override
  void initState() {
    super.initState();

    final cubit = context.read<MeetingNotesCubit>();

    cubit.loadMeetings();
    cubit.loadClients();
  }

  // ═══════════════════════════════════════════
  // Create Meeting
  // ═══════════════════════════════════════════

  Future<void> _openCreateMeeting() async {
    final cubit = context.read<MeetingNotesCubit>();

    if (cubit.state.isMutating) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const CreateMeetingScreen(),
        ),
      ),
    );

    if (!mounted) return;

    await cubit.refreshMeetings();
  }

  // ═══════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      body: AppPageScaffold(
        title: 'Meeting Notes',
        subtitle: 'Manage your meeting notes and transcripts',

        child: BlocBuilder<MeetingNotesCubit, MeetingNotesState>(
          builder: (context, state) {
            if (state.isLoading ||
                state.listStatus == MeetingRequestStatus.initial) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (state.listStatus == MeetingRequestStatus.failure &&
                state.meetings.isEmpty) {
              return MeetingErrorView(
                message:
                    state.listRefreshError ??
                    state.errorMessage ??
                    'Please check your connection.',
                onRetry: () => context.read<MeetingNotesCubit>().loadMeetings(),
              );
            }

            return Column(
              children: [
                MeetingsToolbar(
                  meetingCount: state.meetings.length,
                  processingCount: state.meetings
                      .where((m) => m.isProcessing)
                      .length,
                  hasRefreshError: state.hasListRefreshError,
                  onRefresh: state.isRefreshing || state.isMutating
                      ? null
                      : _refresh,
                ),

                if (state.isRefreshing)
                  const LinearProgressIndicator(minHeight: 2),

                if (state.hasListRefreshError)
                  MeetingRefreshBanner(
                    message: state.listRefreshError!,
                    onRetry: state.isRefreshing || state.isMutating
                        ? null
                        : _refresh,
                  ),

                const SizedBox(height: 12),

                Expanded(
                  child: state.meetings.isEmpty
                      ? MeetingEmptyView(
                          onRefresh: _refresh,
                          onCreate: state.isMutating
                              ? null
                              : _openCreateMeeting,
                        )
                      : MeetingsList(
                          meetings: state.meetings,
                          clients: state.clients,
                          enabled: !state.isMutating && !state.isRefreshing,
                          onRefresh: _refresh,
                          onOpen: _openDetails,
                        ),
                ),
              ],
            );
          },
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateMeeting,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Note',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    final cubit = context.read<MeetingNotesCubit>();
    if (!cubit.state.isMutating) await cubit.refreshMeetings();
  }

  Future<void> _openDetails(String id) async {
    final cubit = context.read<MeetingNotesCubit>();
    if (cubit.state.isMutating || cubit.state.isRefreshing) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: MeetingDetailsScreen(meetingId: id),
        ),
      ),
    );
    if (!mounted || cubit.isClosed) return;
    cubit.clearSelectedMeeting();
    await cubit.refreshMeetings();
  }
}
