import 'package:equatable/equatable.dart';

class MeetingClientModel extends Equatable {
  final String id;
  final String name;

  const MeetingClientModel({required this.id, required this.name});

  factory MeetingClientModel.fromJson(Map<String, dynamic> json) {
    return MeetingClientModel(
      id: json['clientId'] as String,
      name: json['clientName'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name];
}
