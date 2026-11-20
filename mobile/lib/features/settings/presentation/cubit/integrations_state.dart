import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/settings/data/models/integration_model.dart';

abstract class IntegrationsState extends BaseState {
  const IntegrationsState();
}

class IntegrationsInitial extends IntegrationsState {
  const IntegrationsInitial();
}

class IntegrationsLoading extends IntegrationsState {
  const IntegrationsLoading();
}

class IntegrationsLoaded extends IntegrationsState {
  final List<IntegrationModel> integrations;
  const IntegrationsLoaded(this.integrations);

  @override
  List<Object?> get props => [integrations];
}

class IntegrationsError extends IntegrationsState {
  final String message;
  const IntegrationsError(this.message);

  @override
  List<Object?> get props => [message];
}

class IntegrationsSiteSelectionRequired extends IntegrationsState {
  final List<Map<String, dynamic>> sites;
  final String pendingId;

  const IntegrationsSiteSelectionRequired({
    required this.sites,
    required this.pendingId,
  });

  @override
  List<Object?> get props => [sites, pendingId];
}