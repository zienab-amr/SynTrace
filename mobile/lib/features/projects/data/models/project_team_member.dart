import 'package:equatable/equatable.dart';

enum ProjectMemberRole {
  member,
  productOwner,
  projectManager;

  String get apiValue => switch (this) {
    ProjectMemberRole.member => 'Member',
    ProjectMemberRole.productOwner => 'ProductOwner',
    ProjectMemberRole.projectManager => 'ProjectManager',
  };

  String get label => switch (this) {
    ProjectMemberRole.member => 'Member',
    ProjectMemberRole.productOwner => 'Product Owner',
    ProjectMemberRole.projectManager => 'Project Manager',
  };

  static ProjectMemberRole fromJson(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'member':
        return ProjectMemberRole.member;

      case 'productowner':
        return ProjectMemberRole.productOwner;

      case 'projectmanager':
        return ProjectMemberRole.projectManager;

      default:
        throw const FormatException('Unknown project member role.');
    }
  }
}

class ProjectTeamMember extends Equatable {
  final String employeeId;
  final String name;
  final String email;
  final ProjectMemberRole role;

  const ProjectTeamMember({
    required this.employeeId,
    required this.name,
    required this.email,
    this.role = ProjectMemberRole.member,
  });

  factory ProjectTeamMember.fromJson(Map<String, dynamic> json) {
    final employeeId = json['employeeId']?.toString().trim() ?? '';

    final firstName = json['firstName']?.toString().trim() ?? '';

    final lastName = json['lastName']?.toString().trim() ?? '';

    final email = json['email']?.toString().trim() ?? '';

    final name = '$firstName $lastName'.trim();

    if (employeeId.isEmpty) {
      throw const FormatException('Missing project member ID.');
    }

    return ProjectTeamMember(
      employeeId: employeeId,
      name: name.isNotEmpty ? name : email,
      email: email,
      role: ProjectMemberRole.fromJson(json['role']),
    );
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  ProjectTeamMember copyWith({ProjectMemberRole? role}) {
    return ProjectTeamMember(
      employeeId: employeeId,
      name: name,
      email: email,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => [employeeId, name, email, role];
}
