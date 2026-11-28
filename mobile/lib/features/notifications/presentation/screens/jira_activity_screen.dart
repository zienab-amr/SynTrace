import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

import '../cubit/jira_events_cubit.dart';
import '../cubit/jira_events_state.dart';
import '../widgets/activity_event_tile.dart';
import '../widgets/activity_feedback.dart';

class JiraActivityScreen extends StatelessWidget {
  const JiraActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Activity',
      subtitle: 'Your workspace updates',
      scrollable: false,
      maxContentWidth: 720,
      child: BlocBuilder<JiraEventsCubit, JiraEventsState>(
        builder: (context, state) {
          final cubit = context.read<JiraEventsCubit>();

          if (state is JiraEventsInitial || state is JiraEventsLoading) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (state is JiraEventsUnavailable) {
            return const ActivityFeedback(
              title: 'Activity unavailable',
              message: 'Workspace updates are not available yet.',
            );
          }

          if (state is JiraEventsError) {
            return ActivityFeedback(
              title: 'Unable to load activity',
              message: state.message,
              onRetry: cubit.loadEvents,
            );
          }

          if (state is JiraEventsLoaded) {
            if (state.events.isEmpty) {
              return ActivityFeedback(
                title: 'All quiet for now',
                message: 'New workspace activity will appear here.',
                onRetry: cubit.loadEvents,
              );
            }

            return RefreshIndicator(
              onRefresh: cubit.loadEvents,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: state.events.length,
                separatorBuilder: (context, index) {
                  return Divider(
                    height: 1,
                    thickness: 0.7,
                    color: context.appColors.border,
                  );
                },
                itemBuilder: (context, index) {
                  return ActivityEventTile(event: state.events[index]);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
