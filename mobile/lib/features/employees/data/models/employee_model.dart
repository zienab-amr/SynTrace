import 'package:equatable/equatable.dart';

class EmployeeModel extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String role;
  final List<String> roleNames;
  final Map<String, String> rolesById;
  final String? companyId;

  const EmployeeModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    required this.role,
    this.roleNames = const [],
    this.rolesById = const {},
    this.companyId,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return (f + l).toUpperCase();
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final raw = json['roles'];
    final names = raw is List
        ? raw
              .whereType<Map>()
              .map((r) => r['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toSet()
              .toList()
        : <String>[];
    final ids = <String, String>{};
    if (raw is List) {
      for (final r in raw.whereType<Map>()) {
        final id = r['id']?.toString() ?? '';
        final name = r['name']?.toString() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) ids[id] = name;
      }
    }
    return EmployeeModel(
      id: (json['id'] ?? json['employeeId'] ?? '').toString(),
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      role: names.isEmpty ? 'No role assigned' : names.join(', '),
      roleNames: List.unmodifiable(names),
      rolesById: Map.unmodifiable(ids),
      companyId: json['companyId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phoneNumber': phoneNumber,
    'companyId': companyId,
    'roles': roleNames
        .map(
          (name) => {
            'name': name,
            'id': rolesById.entries
                .where((e) => e.value == name)
                .map((e) => e.key)
                .firstOrNull,
          },
        )
        .toList(),
  };

  @override
  List<Object?> get props => [
    id,
    firstName,
    lastName,
    email,
    phoneNumber,
    role,
    companyId,
    roleNames,
    rolesById,
  ];
}
