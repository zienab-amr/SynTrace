import 'package:equatable/equatable.dart';

class MeetingModel extends Equatable {
  final String id;
  final String title;
  final String? transcript;
  final String? summary;
  final DateTime scheduledAt;
  final int durationMinutes;
  final List<String> participantIds;
  final List<String> keyDecisions;
  final String? projectId;
  final MeetingStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MeetingModel({
    required this.id,
    required this.title,
    this.transcript,
    this.summary,
    required this.scheduledAt,
    this.durationMinutes = 0,
    this.participantIds = const [],
    this.keyDecisions = const [],
    this.projectId,
    this.status = MeetingStatus.scheduled,
    this.createdAt,
    this.updatedAt,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      transcript: json['transcript'] as String?,
      summary: json['summary'] as String?,
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      participantIds: json['participantIds'] != null
          ? List<String>.from(json['participantIds'] as List)
          : const [],
      keyDecisions: json['keyDecisions'] != null
          ? List<String>.from(json['keyDecisions'] as List)
          : const [],
      projectId: json['projectId'] as String?,
      status: MeetingStatus.fromString(json['status'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'transcript': transcript,
      'summary': summary,
      'scheduledAt': scheduledAt.toIso8601String(),
      'durationMinutes': durationMinutes,
      'participantIds': participantIds,
      'keyDecisions': keyDecisions,
      'projectId': projectId,
      'status': status.value,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  MeetingModel copyWith({
    String? id,
    String? title,
    String? transcript,
    String? summary,
    DateTime? scheduledAt,
    int? durationMinutes,
    List<String>? participantIds,
    List<String>? keyDecisions,
    String? projectId,
    MeetingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MeetingModel(
      id: id ?? this.id,
      title: title ?? this.title,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      participantIds: participantIds ?? this.participantIds,
      keyDecisions: keyDecisions ?? this.keyDecisions,
      projectId: projectId ?? this.projectId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isUpcoming => scheduledAt.isAfter(DateTime.now());
  bool get hasTranscript => transcript != null && transcript!.isNotEmpty;
  bool get hasDecisions => keyDecisions.isNotEmpty;

  @override
  List<Object?> get props => [
        id, title, transcript, summary, scheduledAt, durationMinutes,
        participantIds, keyDecisions, projectId, status, createdAt, updatedAt,
      ];
}

enum MeetingStatus {
  scheduled('scheduled'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const MeetingStatus(this.value);

  static MeetingStatus fromString(String? value) {
    if (value == null) return MeetingStatus.scheduled;
    return MeetingStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == value.toLowerCase(),
      orElse: () => MeetingStatus.scheduled,
    );
  }
}