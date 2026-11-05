import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syntrace/features/meetings/data/models/meeting_note_model.dart';

class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  static const _keyMeetings = 'cached_meetings';

  Future<void> saveMeetings(List<MeetingNote> meetings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = meetings
        .map(
          (m) => {
            'id': m.id,
            'title': m.title,
            'date': m.date.toIso8601String(),
            'participants': m.participants,
            'content': m.content,
            'isDraft': m.isDraft,
            'projectId': m.projectId,
            'projectName': m.projectName,
            'keyPoints': m.keyPoints.map((p) => p.toJson()).toList(),
          },
        )
        .toList();
    await prefs.setString(_keyMeetings, jsonEncode(jsonList));
  }

  Future<List<MeetingNote>?> loadMeetings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyMeetings);
    if (jsonString == null) return null;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map(
            (json) => MeetingNote(
              id: json['id'],
              title: json['title'],
              date: DateTime.parse(json['date']),
              participants: List<String>.from(json['participants']),
              content: json['content'],
              isDraft: json['isDraft'] ?? false,
              projectId: json['projectId'],
              projectName: json['projectName'],
              keyPoints:
                  (json['keyPoints'] as List<dynamic>?)
                      ?.map((p) => MeetingPoint.fromJson(p))
                      .toList() ??
                  [],
            ),
          )
          .toList();
    } catch (e) {
      return null;
    }
  }
}
