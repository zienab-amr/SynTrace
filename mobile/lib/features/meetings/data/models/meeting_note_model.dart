import 'package:equatable/equatable.dart';

enum MeetingPointType { note, decision, action, blocker }

class MeetingPoint extends Equatable {
  final String text;
  final MeetingPointType type;

  const MeetingPoint({required this.text, this.type = MeetingPointType.note});

  Map<String, dynamic> toJson() => {'text': text, 'type': type.name};

  factory MeetingPoint.fromJson(Map<String, dynamic> json) {
    return MeetingPoint(
      text: json['text'] as String? ?? '',
      type: MeetingPointType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MeetingPointType.note,
      ),
    );
  }

  @override
  List<Object?> get props => [text, type];
}

class MeetingNote extends Equatable {
  final String id;
  final String title;
  final DateTime date;
  final List<String> participants;
  final String content;
  final bool isDraft;
  final String? projectId;
  final String? projectName;
  final List<MeetingPoint> keyPoints;

  const MeetingNote({
    required this.id,
    required this.title,
    required this.date,
    required this.participants,
    required this.content,
    this.isDraft = false,
    this.projectId,
    this.projectName,
    this.keyPoints = const [],
  });

  MeetingNote copyWith({
    String? id,
    String? title,
    DateTime? date,
    List<String>? participants,
    String? content,
    bool? isDraft,
    String? projectId,
    String? projectName,
    List<MeetingPoint>? keyPoints,
  }) {
    return MeetingNote(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      participants: participants ?? this.participants,
      content: content ?? this.content,
      isDraft: isDraft ?? this.isDraft,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      keyPoints: keyPoints ?? this.keyPoints,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    date,
    participants,
    content,
    isDraft,
    projectId,
    projectName,
    keyPoints,
  ];
}
