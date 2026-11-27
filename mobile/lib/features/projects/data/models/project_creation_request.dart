import 'project_team_member.dart';

class ProjectCreationRequest {
  final String name;
  final String clientId;
  final String description;

  final List<ProjectTeamMember> members;

  final int? githubRepositoryId;
  final String? jiraProjectId;

  ProjectCreationRequest({
    required String name,
    required String clientId,
    required String description,
    required List<ProjectTeamMember> members,
    this.githubRepositoryId,
    this.jiraProjectId,
  }) : name = name.trim(),
       clientId = clientId.trim(),
       description = description.trim(),
       members = List.unmodifiable(members);

  bool get isValid {
    if (name.isEmpty ||
        name.length > 200 ||
        clientId.isEmpty ||
        clientId.length > 450 ||
        description.length > 4000) {
      return false;
    }

    if (githubRepositoryId != null && githubRepositoryId! <= 0) {
      return false;
    }

    if (jiraProjectId != null &&
        (jiraProjectId!.trim().isEmpty || jiraProjectId!.length > 450)) {
      return false;
    }

    final employeeIds = <String>{};

    for (final member in members) {
      if (member.employeeId.trim().isEmpty ||
          !employeeIds.add(member.employeeId)) {
        return false;
      }
    }

    return true;
  }
}
