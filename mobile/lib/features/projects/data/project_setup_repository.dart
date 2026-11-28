import 'package:dio/dio.dart';

import 'package:syntrace/features/employees/data/models/employee_model.dart';
import 'package:syntrace/features/employees/data/employees_repository.dart';
import 'package:syntrace/features/settings/data/repositories/github_repository.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';

import 'models/project_api_model.dart';
import 'projects_repository.dart';

class ProjectSetupRepository {
  final EmployeesRepository _employeesRepository;
  final ProjectsRepository _projectsRepository;
  final GitHubRepository _integrationsRepository;

  ProjectSetupRepository({
    EmployeesRepository? employeesRepository,
    ProjectsRepository? projectsRepository,
    GitHubRepository? integrationsRepository,
  }) : _employeesRepository = employeesRepository ?? EmployeesRepository(),
       _projectsRepository = projectsRepository ?? ProjectsRepository(),
       _integrationsRepository = integrationsRepository ?? GitHubRepository();

  Future<List<EmployeeModel>> getEmployees() async {
    final result = await _employeesRepository.getAllEmployees();

    if (!result.success || result.data == null) {
      throw StateError('Unable to load employees.');
    }

    final employees = result.data!
        .where((employee) => employee.id.isNotEmpty)
        .toList();

    employees.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );

    return List.unmodifiable(employees);
  }

  Future<List<JiraProjectOption>> getJiraProjects() {
    return _projectsRepository.getJiraProjectOptions();
  }

  Future<List<GitHubRepositoryOption>> getGitHubRepositories() async {
    final response = await _integrationsRepository.getGitHubRepositories();

    _ensureSuccess(response);

    final data = response.data;

    if (data is! List) {
      throw const FormatException('Invalid GitHub repositories response.');
    }

    final repositories = data.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid GitHub repository.');
      }

      return GitHubRepositoryOption.fromJson(Map<String, dynamic>.from(item));
    }).toList();

    repositories.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );

    return List.unmodifiable(repositories);
  }

  void _ensureSuccess(Response response) {
    final status = response.statusCode ?? 0;

    if (status < 200 || status >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }
}
