import 'package:equatable/equatable.dart';

class MeetingProjectModel extends Equatable {
  final String id;
  final String name;
  final String clientId;

  const MeetingProjectModel({
    required this.id,
    required this.name,
    required this.clientId,
  });

  factory MeetingProjectModel.fromJson(Map<String, dynamic> json) {
    return MeetingProjectModel(
      id: json['projectId'] as String,
      name: json['projectName'] as String,
      clientId: json['clientId'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name, clientId];
}
