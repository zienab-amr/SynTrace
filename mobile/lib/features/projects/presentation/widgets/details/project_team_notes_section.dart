import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/features/meetings/presentation/cubit/meeting_notes_cubit.dart';
import 'package:syntrace/features/meetings/presentation/cubit/meeting_notes_state.dart';
import 'package:syntrace/features/meetings/presentation/screens/meeting_details_screen.dart';
import 'package:syntrace/features/meetings/presentation/widgets/list/meetings_list.dart';
import 'package:syntrace/features/meetings/presentation/widgets/shared/meeting_refresh_banner.dart';

class ProjectTeamNotesSection extends StatelessWidget {
  final String projectId;
  final bool publishedOnly;

  const ProjectTeamNotesSection({
    super.key,
    required this.projectId,
    this.publishedOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        if (user == null || projectId.isEmpty) {
          return const Center(child: Text('Project notes unavailable.'));
        }
        return BlocProvider(
          key: ValueKey(
            '${user.id}-${user.tenantId}-${user.role}-$projectId-$publishedOnly',
          ),
          create: (_) => MeetingNotesCubit()
            ..loadMeetings(projectId: projectId)
            ..loadClients(),
          child: _ProjectNotesView(
            projectId: projectId,
            publishedOnly: publishedOnly,
          ),
        );
      },
    );
  }
}

class _ProjectNotesView extends StatelessWidget {
  final String projectId;
  final bool publishedOnly;
  const _ProjectNotesView({
    required this.projectId,
    required this.publishedOnly,
  });

  Future<void> _open(BuildContext context, String id) async {
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
    if (cubit.isClosed) return;
    cubit.clearSelectedMeeting();
    await cubit.refreshMeetings();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MeetingNotesCubit, MeetingNotesState>(
      builder: (context, state) {
        final cubit = context.read<MeetingNotesCubit>();
        if (state.listStatus == MeetingRequestStatus.initial ||
            state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.listStatus == MeetingRequestStatus.failure) {
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.errorMessage ?? 'Unable to load project notes.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => cubit.loadMeetings(projectId: projectId),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        final notes = state.meetings
            .where(
              (note) =>
                  note.projectId == projectId &&
                  (!publishedOnly || note.isPublished),
            )
            .toList(growable: false);
        final busy = state.isRefreshing || state.isMutating;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    publishedOnly ? 'Published AI results' : 'Project Notes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh notes',
                  onPressed: busy ? null : () => cubit.refreshMeetings(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (state.isRefreshing) const LinearProgressIndicator(minHeight: 2),
            if (state.listRefreshError != null)
              MeetingRefreshBanner(
                message: state.listRefreshError!,
                onRetry: busy ? null : () => cubit.refreshMeetings(),
              ),
            if (publishedOnly)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Open a published meeting to view its extracted insights. PDF reports are not available here.',
                ),
              ),
            Expanded(
              child: notes.isEmpty
                  ? RefreshIndicator(
                      onRefresh: cubit.refreshMeetings,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 32),
                          Center(
                            child: Text(
                              publishedOnly
                                  ? 'No published AI results yet.'
                                  : 'No notes for this project yet.',
                            ),
                          ),
                        ],
                      ),
                    )
                  : MeetingsList(
                      meetings: notes,
                      clients: state.clients,
                      enabled: !busy,
                      onRefresh: cubit.refreshMeetings,
                      onOpen: (id) => _open(context, id),
                    ),
            ),
          ],
        );
      },
    );
  }
}
