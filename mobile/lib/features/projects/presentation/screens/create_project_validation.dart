part of 'create_project_screen.dart';

extension _CreateProjectValidation on _CreateProjectViewState {
  bool _validateDetails() {
    final state = context.read<CreateProjectCubit>().state;

    final validClient = state.clients.any(
      (client) => client.id == _selectedClientId,
    );

    if (_nameController.text.trim().isEmpty) {
      _showMessage('Enter a project name.');

      return false;
    }

    if (_nameController.text.trim().length > 200) {
      _showMessage('Project name must not exceed 200 characters.');
      return false;
    }

    if (_descriptionController.text.trim().length > 4000) {
      _showMessage('Description must not exceed 4000 characters.');
      return false;
    }

    if (!validClient) {
      _showMessage('Select a valid client.');

      return false;
    }

    return true;
  }

  bool _validateTeam() {
    if (_selectedMembers.isEmpty) return true;

    final options = context.read<ProjectSetupCubit>().state.employees;

    if (options.status != SetupStatus.success) {
      _showMessage('Reload employees before continuing.');

      return false;
    }

    final availableIds = options.items.map((employee) => employee.id).toSet();

    final valid = _selectedMembers.every(
      (member) => availableIds.contains(member.employeeId),
    );

    if (!valid) {
      _showMessage('Some selected employees are unavailable.');
    }

    return valid;
  }

  bool _validateIntegrations() {
    final setup = context.read<ProjectSetupCubit>().state;

    final repository = _selectedRepository;
    final jiraProject = _selectedJiraProject;

    if (repository != null) {
      final valid =
          setup.github.status == SetupStatus.success &&
          setup.github.items.any(
            (item) => item.repositoryId == repository.repositoryId,
          );

      if (!valid) {
        _showMessage(
          'Select an available GitHub repository '
          'or remove the current selection.',
        );

        return false;
      }
    }

    if (jiraProject != null) {
      final valid =
          setup.jira.status == SetupStatus.success &&
          setup.jira.items.any((item) => item.id == jiraProject.id);

      if (!valid) {
        _showMessage(
          'Select an available Jira project '
          'or remove the current selection.',
        );

        return false;
      }
    }

    return true;
  }
}
