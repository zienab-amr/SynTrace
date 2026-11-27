import 'package:equatable/equatable.dart';

enum ClientStatus {
  active,
  archived,
  blocked;

  static ClientStatus fromJson(Object? value) {
    for (final status in values) {
      if (value == status.index ||
          (value is String && value.toLowerCase() == status.name)) {
        return status;
      }
    }
    throw const FormatException('Invalid client status.');
  }
}

class ProjectClientModel extends Equatable {
  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final ClientStatus status;

  const ProjectClientModel({
    required this.id,
    required this.name,
    this.email,
    this.phoneNumber,
    this.status = ClientStatus.active,
  });

  factory ProjectClientModel.fromJson(Map<String, dynamic> json) {
    final id = json['clientId'];
    final name = json['clientName'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      throw const FormatException('Invalid client data.');
    }
    return ProjectClientModel(
      id: id,
      name: name,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      status: ClientStatus.fromJson(json['status']),
    );
  }

  Map<String, dynamic> toJson() => {
    'clientId': id,
    'clientName': name,
    'email': email,
    'phoneNumber': phoneNumber,
    'status': status.index,
  };

  @override
  List<Object?> get props => [id, name, email, phoneNumber, status];
}
