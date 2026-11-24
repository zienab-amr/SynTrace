import 'package:flutter/material.dart';
import '../../../data/models/meeting_note_model.dart';
import 'meeting_point_style.dart';

class MeetingDiscussionPointCard extends StatelessWidget {
  final MeetingPoint point;
  final VoidCallback? onRemove;
  const MeetingDiscussionPointCard({
    super.key,
    required this.point,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = meetingPointColor(point.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(meetingPointIcon(point.type), color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(point.text)),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove point',
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}
