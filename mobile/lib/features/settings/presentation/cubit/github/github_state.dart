import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';
import 'package:syntrace/features/settings/data/models/integration_model.dart';

abstract class GitHubState extends BaseState {
  const GitHubState();
}

class GitHubInitial extends GitHubState {
  const GitHubInitial();
}

class GitHubLoading extends GitHubState {
  const GitHubLoading();
}

class GitHubLoaded extends GitHubState {
  final List<IntegrationModel> integrations;

  const GitHubLoaded(this.integrations);

  @override
  List<Object?> get props => [integrations];
}

class GitHubError extends GitHubState {
  final String message;

  const GitHubError(this.message);

  @override
  List<Object?> get props => [message];
}

class GitHubApprovalPending extends GitHubState {
  final String message;

  const GitHubApprovalPending({
    this.message =
        'GitHub connection request sent. An administrator must approve the installation.',
  });

  @override
  List<Object?> get props => [message];
}

class GitHubInstallationSelectionRequired extends GitHubState {
  final String completionId;
  final String githubLogin;
  final List<GitHubInstallationOption> installations;

  const GitHubInstallationSelectionRequired({
    required this.completionId,
    required this.githubLogin,
    required this.installations,
  });

  @override
  List<Object?> get props => [completionId, githubLogin, installations];
}
