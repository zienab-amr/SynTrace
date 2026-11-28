import 'package:equatable/equatable.dart';

import 'package:syntrace/features/employees/data/models/employee_model.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';

import '../../data/models/project_api_model.dart';

enum SetupStatus { initial, loading, success, failure }

class SetupOptions<T> extends Equatable {
  final SetupStatus status;
  final List<T> items;
  final String? error;

  const SetupOptions({
    this.status = SetupStatus.initial,
    this.items = const [],
    this.error,
  });

  bool get isLoading => status == SetupStatus.loading;

  bool get hasError => status == SetupStatus.failure;

  @override
  List<Object?> get props => [status, items, error];
}

class ProjectSetupState extends Equatable {
  final SetupOptions<EmployeeModel> employees;
  final SetupOptions<GitHubRepositoryOption> github;
  final SetupOptions<JiraProjectOption> jira;

  const ProjectSetupState({
    this.employees = const SetupOptions(),
    this.github = const SetupOptions(),
    this.jira = const SetupOptions(),
  });

  ProjectSetupState copyWith({
    SetupOptions<EmployeeModel>? employees,
    SetupOptions<GitHubRepositoryOption>? github,
    SetupOptions<JiraProjectOption>? jira,
  }) {
    return ProjectSetupState(
      employees: employees ?? this.employees,
      github: github ?? this.github,
      jira: jira ?? this.jira,
    );
  }

  @override
  List<Object?> get props => [employees, github, jira];
}
