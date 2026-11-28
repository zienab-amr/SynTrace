import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/settings/data/models/integration_model.dart';

abstract class JiraState extends BaseState {
  const JiraState();
}

class JiraInitial extends JiraState {
  const JiraInitial();
}

class JiraLoading extends JiraState {
  const JiraLoading();
}

class JiraLoaded extends JiraState {
  final List<IntegrationModel> integrations;

  const JiraLoaded(this.integrations);

  @override
  List<Object?> get props => [integrations];
}

class JiraError extends JiraState {
  final String message;

  const JiraError(this.message);

  @override
  List<Object?> get props => [message];
}

class JiraSiteSelectionRequired extends JiraState {
  final List<Map<String, dynamic>> sites;
  final String pendingId;

  const JiraSiteSelectionRequired({
    required this.sites,
    required this.pendingId,
  });

  @override
  List<Object?> get props => [sites, pendingId];
}
