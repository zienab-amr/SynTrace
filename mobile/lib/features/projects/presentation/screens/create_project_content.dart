part of 'create_project_screen.dart';

extension _CreateProjectContent on _CreateProjectViewState {
  Widget _buildContent(CreateProjectState state) {
    if (state.isSubmitting) {
      return _ProjectSubmittingView(
        projectCreated: state.hasCreatedProject,
        completedMembers: state.completedMembers.length,
        totalMembers: _selectedMembers.length,
      );
    }

    if (state.hasCreatedProject) {
      return SingleChildScrollView(
        child: ProjectCreationResult(
          projectName: _nameController.text.trim(),
          completedMembers: state.completedMembers.length,
          totalMembers: _selectedMembers.length,
          githubRequested: _selectedRepository != null,
          githubMapped: state.githubMapped,
          jiraRequested: _selectedJiraProject != null,
          jiraMapped: state.jiraMapped,
          message: state.errorMessage,
          onOpenProject: () {
            _openProject(state.createdProject!);
          },
        ),
      );
    }

    if (state.creationUncertain) {
      return SingleChildScrollView(
        child: CreateProjectFeedback(
          icon: Icons.warning_amber_rounded,
          title: 'Creation not confirmed',
          message:
              'The server may have created your project. '
              'Check the projects list before trying again.',
          actionLabel: 'Check projects',
          onAction: () {
            _returnToProjects(refresh: true);
          },
        ),
      );
    }

    if (state.isLoading || state.status == CreateProjectStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.clients.isEmpty && state.errorMessage != null) {
      return SingleChildScrollView(
        child: CreateProjectFeedback(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load clients',
          message: state.errorMessage!,
          actionLabel: 'Try again',
          onAction: context.read<CreateProjectCubit>().loadClients,
        ),
      );
    }

    return Column(
      children: [
        ProjectWizardProgress(currentStep: _currentStep),

        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStep(state),

                if (state.errorMessage != null) ...[
                  const SizedBox(height: 20),
                  CreateProjectErrorBanner(message: state.errorMessage!),
                ],
              ],
            ),
          ),
        ),

        _buildBottomActions(state),
      ],
    );
  }

  Widget _buildStep(CreateProjectState state) {
    switch (_currentStep) {
      case 0:
        return ProjectDetailsForm(
          formKey: _formKey,
          nameController: _nameController,
          descriptionController: _descriptionController,
          clients: state.clients,
          selectedClientId: _selectedClientId,
          onCreateClient: _createClient,
          onClientChanged: (value) {
            _updateView(() {
              _selectedClientId = value;
            });
          },
        );

      case 1:
        return _buildTeamStep();

      case 2:
        return ProjectIntegrationsStep(
          selectedRepository: _selectedRepository,
          selectedJiraProject: _selectedJiraProject,
          onGitHubChanged: (repository) {
            _updateView(() {
              _selectedRepository = repository;
            });
          },
          onJiraChanged: (project) {
            _updateView(() {
              _selectedJiraProject = project;
            });
          },
        );

      case 3:
        return ProjectReviewStep(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          clientName: _clientName(state),
          members: _selectedMembers,
          githubRepository: _selectedRepository?.fullName,
          jiraProject: _selectedJiraProject == null
              ? null
              : '${_selectedJiraProject!.key} Â· '
                    '${_selectedJiraProject!.name}',
          onEdit: _goToStep,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTeamStep() {
    return BlocBuilder<ProjectSetupCubit, ProjectSetupState>(
      builder: (context, state) {
        final options = state.employees;

        if (options.isLoading || options.status == SetupStatus.initial) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (options.hasError) {
          return Column(
            children: [
              CreateProjectFeedback(
                icon: Icons.groups_outlined,
                title: 'Unable to load employees',
                message: options.error ?? 'Please try again.',
                actionLabel: 'Try again',
                onAction: context.read<ProjectSetupCubit>().loadEmployees,
              ),
              if (_selectedMembers.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _updateView(() {
                      _selectedMembers = [];
                    });
                  },
                  child: const Text('Clear selected members'),
                ),
            ],
          );
        }

        return ProjectTeamStep(
          employees: options.items,
          selectedMembers: _selectedMembers,
          onChanged: (members) {
            _updateView(() {
              _selectedMembers = List.unmodifiable(members);
            });
          },
        );
      },
    );
  }

  Widget _buildBottomActions(CreateProjectState state) {
    final isLastStep = _currentStep == _CreateProjectViewState._lastStep;

    final hasValidClient = state.clients.any(
      (client) => client.id == _selectedClientId,
    );

    final enabled =
        !state.isSubmitting && (_currentStep != 0 || hasValidClient);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: AppButton(
                  label: 'Back',
                  icon: Icons.arrow_back_rounded,
                  variant: AppButtonVariant.outline,
                  onPressed: () {
                    _goToStep(_currentStep - 1);
                  },
                ),
              ),

              const SizedBox(width: 12),
            ],

            Expanded(
              flex: 2,
              child: AppButton(
                label: isLastStep ? 'Create project' : 'Continue',
                icon: isLastStep ? Icons.add_rounded : null,
                trailingIcon: isLastStep ? null : Icons.arrow_forward_rounded,
                onPressed: enabled ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
