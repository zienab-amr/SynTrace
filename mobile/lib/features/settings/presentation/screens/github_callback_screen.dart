import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_state.dart';

class GitHubCallbackScreen extends StatefulWidget {
  final String status;
  final String? completionId;

  const GitHubCallbackScreen({
    super.key,
    required this.status,
    this.completionId,
  });

  @override
  State<GitHubCallbackScreen> createState() => _GitHubCallbackScreenState();
}

class _GitHubCallbackScreenState extends State<GitHubCallbackScreen> {
  bool _dialogOpen = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IntegrationsCubit>().handleGitHubCallback(
            widget.status,
            widget.completionId,
          );
    });
  }

  void _goToSettings() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(AppRoutes.settings);
  }

  void _showInstallations(GitHubInstallationSelectionRequired state) {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final cubit = context.read<IntegrationsCubit>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select GitHub installation'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.installations.length,
              itemBuilder: (context, index) {
                final installation = state.installations[index];
                return ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(installation.accountLogin),
                  subtitle: Text(_subtitle(installation)),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _dialogOpen = false;
                    cubit.completeGitHubConnection(
                      state.completionId,
                      installation.installationId,
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _subtitle(GitHubInstallationOption installation) {
    final type = installation.accountType.isEmpty
        ? 'GitHub account'
        : installation.accountType;
    final count = installation.repositoryCount;
    return count == null ? type : '$type · $count repositories';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<IntegrationsCubit, IntegrationsState>(
      listener: (context, state) {
        if (state is GitHubInstallationSelectionRequired) {
          _showInstallations(state);
        } else if (state is GitHubApprovalPending) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          _goToSettings();
        } else if (state is IntegrationsLoaded) {
          _goToSettings();
        } else if (state is IntegrationsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          _goToSettings();
        }
      },
      child: const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
