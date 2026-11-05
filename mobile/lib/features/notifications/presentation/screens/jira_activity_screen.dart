import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/notifications/data/models/jira_event_model.dart';
import 'package:syntrace/features/notifications/presentation/cubit/jira_events_cubit.dart';
import 'package:syntrace/features/notifications/presentation/cubit/jira_events_state.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class JiraActivityScreen extends StatefulWidget {
  const JiraActivityScreen({super.key});

  @override
  State<JiraActivityScreen> createState() => _JiraActivityScreenState();
}

class _JiraActivityScreenState extends State<JiraActivityScreen> {
  @override
  void initState() {
    super.initState();
    context.read<JiraEventsCubit>().loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Activity Feed',
      subtitle: 'Real-time Jira events and updates',
      child: BlocBuilder<JiraEventsCubit, JiraEventsState>(
        builder: (context, state) {
          if (state is JiraEventsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is JiraEventsLoaded) {
            if (state.events.isEmpty) {
              return const Center(child: Text('No recent activity'));
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: state.events.length,
              itemBuilder: (context, index) {
                final event = state.events[index];
                final isLast = index == state.events.length - 1;
                return _TimelineItem(event: event, isLast: isLast);
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final JiraEventModel event;
  final bool isLast;

  const _TimelineItem({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('MMM dd, hh:mm a').format(event.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: event.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: event.color, width: 2),
                  ),
                  child: Icon(event.icon, color: event.color, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.dividerColor.withOpacity(0.5),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event.actorName,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: '${event.action} ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: '${event.title} ',
                          style: TextStyle(
                            color: event.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: '- ${event.description}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
