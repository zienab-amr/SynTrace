import 'package:flutter/material.dart';
import '../../../data/models/knowledge_source_model.dart';
import '../../../data/models/meeting_client_model.dart';
import 'meeting_card.dart';

class MeetingsList extends StatelessWidget {
  final List<KnowledgeSourceSummary> meetings;
  final List<MeetingClientModel> clients;
  final bool enabled;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onOpen;
  const MeetingsList({
    super.key,
    required this.meetings,
    required this.clients,
    required this.enabled,
    required this.onRefresh,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,

      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 90),
        itemCount: meetings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final meeting = meetings[index];
          String? clientName;
          for (final client in clients) {
            if (client.id == meeting.clientId) {
              clientName = client.name;
              break;
            }
          }
          return MeetingCard(
            key: ValueKey(meeting.id),
            meeting: meeting,
            clientName: clientName,
            onTap: enabled ? () => onOpen(meeting.id) : null,
          );
        },
      ),
    );
  }
}
