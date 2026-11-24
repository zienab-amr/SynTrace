import 'package:flutter/material.dart';

import '../../../data/models/knowledge_source_model.dart';

class MeetingModeSelector extends StatelessWidget {
  final KnowledgeMeetingMode value;
  final bool enabled;
  final ValueChanged<KnowledgeMeetingMode> onChanged;

  const MeetingModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<KnowledgeMeetingMode>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Meeting Mode',
        prefixIcon: Icon(Icons.groups_outlined),
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: KnowledgeMeetingMode.online,
          child: Text('Online'),
        ),
        DropdownMenuItem(
          value: KnowledgeMeetingMode.inPerson,
          child: Text('In Person'),
        ),
      ],
      onChanged: enabled
          ? (value) {
              if (value != null) onChanged(value);
            }
          : null,
    );
  }
}
