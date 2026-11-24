import 'package:flutter/material.dart';
import '../../../data/models/meeting_note_model.dart';

String meetingPointLabel(MeetingPointType type) {
  switch (type) {
    case MeetingPointType.note:
      return 'Note';
    case MeetingPointType.decision:
      return 'Decision';
    case MeetingPointType.action:
      return 'Action';
    case MeetingPointType.blocker:
      return 'Blocker';
  }
}

Color meetingPointColor(MeetingPointType type) {
  switch (type) {
    case MeetingPointType.note:
      return Colors.blue;
    case MeetingPointType.decision:
      return Colors.purple;
    case MeetingPointType.action:
      return Colors.green;
    case MeetingPointType.blocker:
      return Colors.red;
  }
}

IconData meetingPointIcon(MeetingPointType type) {
  switch (type) {
    case MeetingPointType.note:
      return Icons.sticky_note_2_outlined;
    case MeetingPointType.decision:
      return Icons.check_circle_outline;
    case MeetingPointType.action:
      return Icons.task_alt;
    case MeetingPointType.blocker:
      return Icons.block;
  }
}
