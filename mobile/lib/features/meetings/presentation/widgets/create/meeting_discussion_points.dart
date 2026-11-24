import 'package:flutter/material.dart';
import '../../../data/models/meeting_note_model.dart';
import 'meeting_point_style.dart';
import 'meeting_discussion_point_card.dart';

class MeetingDiscussionPoints extends StatelessWidget {
  final TextEditingController controller;
  final List<MeetingPoint> points;
  final MeetingPointType selectedType;
  final bool enabled;
  final ValueChanged<MeetingPointType> onTypeChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  const MeetingDiscussionPoints({
    super.key,
    required this.controller,
    required this.points,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Discussion Points',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in MeetingPointType.values)
              ChoiceChip(
                label: Text(meetingPointLabel(type)),
                selected: selectedType == type,
                avatar: Icon(
                  meetingPointIcon(type),
                  size: 16,
                  color: meetingPointColor(type),
                ),
                onSelected: enabled ? (_) => onTypeChanged(type) : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                decoration: const InputDecoration(
                  hintText: 'Add a point...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: enabled ? (_) => onAdd() : null,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < points.length; i++)
          MeetingDiscussionPointCard(
            point: points[i],
            onRemove: enabled ? () => onRemove(i) : null,
          ),
      ],
    );
  }
}
