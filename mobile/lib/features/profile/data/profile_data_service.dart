import 'package:syntrace/core/models/project_model.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';

class ProfileDataBundle {
  final UserModel user;
  final List<ProjectModel> projects;
  final List<String> tasks;
  final List<String> commits;

  ProfileDataBundle({
    required this.user,
    required this.projects,
    required this.tasks,
    required this.commits,
  });
}

class ProfileDataService {
  static Future<ProfileDataBundle?> getProfileData(String employeeId) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final user = MockUsers.getUserById(employeeId);
    if (user == null) return null;

    final userProjects = MockProjects.projects
        .where(
          (p) =>
              p.memberIds.contains(user.id) || p.memberIds.contains(user.name),
        )
        .toList();

    final userTasks = [
      'Implement auth flow',
      'Fix login bug',
      'Review API integration',
    ];
    final userCommits = [
      'feat: add new router',
      'fix: null pointer exception',
      'chore: update dependencies',
    ];

    return ProfileDataBundle(
      user: user,
      projects: userProjects,
      tasks: userTasks,
      commits: userCommits,
    );
  }
}
