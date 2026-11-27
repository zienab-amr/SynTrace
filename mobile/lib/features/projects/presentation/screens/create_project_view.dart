part of 'create_project_screen.dart';

class _CreateProjectView extends StatefulWidget {
  const _CreateProjectView();

  @override
  State<_CreateProjectView> createState() => _CreateProjectViewState();
}

class _CreateProjectViewState extends State<_CreateProjectView> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _scrollController = ScrollController();

  int _currentStep = 0;

  String? _selectedClientId;

  List<ProjectTeamMember> _selectedMembers = [];

  GitHubRepositoryOption? _selectedRepository;
  JiraProjectOption? _selectedJiraProject;

  bool _isClientDialogOpen = false;

  static const _lastStep = 3;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  bool get _isLocked {
    final state = context.read<CreateProjectCubit>().state;

    return state.isSubmitting ||
        state.creationUncertain ||
        state.hasCreatedProject ||
        _isClientDialogOpen;
  }

  Future<void> _createClient() async {
    final cubit = context.read<CreateProjectCubit>();
    final user = CurrentUserService.instance.user;

    if (_isLocked || cubit.state.isLoading || user?.role != UserRole.admin) {
      return;
    }

    _isClientDialogOpen = true;

    try {
      final client = await CreateClientDialog.show(context);

      if (!mounted || cubit.isClosed) return;

      final current = CurrentUserService.instance.user;

      if (current?.id != user?.id ||
          current?.tenantId != user?.tenantId ||
          current?.role != UserRole.admin) {
        return;
      }

      if (client == null) {
        await cubit.loadClients();

        return;
      }

      cubit.addCreatedClient(client);

      final exists = cubit.state.clients.any((item) => item.id == client.id);

      if (!exists) return;

      setState(() {
        _selectedClientId = client.id;
      });

      _showMessage('Client created successfully.');
    } finally {
      _isClientDialogOpen = false;
    }
  }

  void _next() {
    if (_isLocked) return;

    FocusScope.of(context).unfocus();

    switch (_currentStep) {
      case 0:
        if (!(_formKey.currentState?.validate() ?? false)) {
          return;
        }

        if (!_validateDetails()) return;

        _goToStep(1);
        break;

      case 1:
        if (!_validateTeam()) return;

        _goToStep(2);
        break;

      case 2:
        if (!_validateIntegrations()) return;

        _goToStep(3);
        break;

      case 3:
        _submit();
        break;
    }
  }

  void _goToStep(int step) {
    if (_isLocked || step < 0 || step > _lastStep) {
      return;
    }

    FocusScope.of(context).unfocus();

    final setup = context.read<ProjectSetupCubit>();

    setState(() {
      _currentStep = step;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    if (step == 1 && setup.state.employees.status == SetupStatus.initial) {
      setup.loadEmployees();
    }

    if (step == 2) {
      if (setup.state.github.status == SetupStatus.initial) {
        setup.loadGitHubRepositories();
      }

      if (setup.state.jira.status == SetupStatus.initial) {
        setup.loadJiraProjects();
      }
    }
  }

  void _submit() {
    if (_isLocked) return;

    if (!_validateDetails()) {
      _goToStep(0);
      return;
    }

    if (!_validateTeam()) {
      _goToStep(1);
      return;
    }

    if (!_validateIntegrations()) {
      _goToStep(2);
      return;
    }

    FocusScope.of(context).unfocus();

    context.read<CreateProjectCubit>().createProject(
      name: _nameController.text,
      clientId: _selectedClientId!,
      description: _descriptionController.text,
      members: _selectedMembers,
      githubRepositoryId: _selectedRepository?.repositoryId,
      jiraProjectId: _selectedJiraProject?.id,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _returnToProjects({bool refresh = false}) {
    if (!mounted) return;

    if (context.canPop()) {
      context.pop(refresh);
    } else {
      context.go(AppRoutes.projects);
    }
  }

  void _openProject(ProjectApiModel project) {
    if (!mounted) return;

    context.go('${AppRoutes.projects}/${Uri.encodeComponent(project.id)}');
  }

  String _clientName(CreateProjectState state) {
    for (final client in state.clients) {
      if (client.id == _selectedClientId) {
        return client.name;
      }
    }

    return 'Client unavailable';
  }

  void _updateView(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateProjectCubit, CreateProjectState>(
      builder: (context, state) {
        final locked =
            state.isSubmitting ||
            state.creationUncertain ||
            state.hasCreatedProject;

        return PopScope(
          canPop: !state.isSubmitting && (locked || _currentStep == 0),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || locked) return;

            if (_currentStep > 0) {
              _goToStep(_currentStep - 1);
            }
          },
          child: AppPageScaffold(
            title: 'Create project',
            subtitle: 'Set up your engineering workspace',
            showBackButton: !locked,
            onBack: () {
              if (_currentStep > 0) {
                _goToStep(_currentStep - 1);
              } else {
                _returnToProjects();
              }
            },
            scrollable: false,
            maxContentWidth: 720,
            child: _buildContent(state),
          ),
        );
      },
    );
  }
}
