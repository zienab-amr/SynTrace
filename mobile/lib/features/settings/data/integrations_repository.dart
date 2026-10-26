import 'package:syntrace/features/settings/data/models/integration_model.dart';

class IntegrationsRepository 
{

  // ═══════════════════════════════════════════════════════
  Future<List<IntegrationModel>> getIntegrations() async 
  {
    await Future.delayed(const Duration(milliseconds: 500));

    return const [
      IntegrationModel(
        type: IntegrationType.jira,
        name: 'Jira',
        description: 'Sync issues, sprints, and backlogs',
        status: IntegrationStatus.disconnected,
      ),
      IntegrationModel(
        type: IntegrationType.github,
        name: 'GitHub',
        description: 'Connect commits, PRs, and branches',
        status: IntegrationStatus.disconnected,
      ),
    ];
  }

 // ═══════════════════════════════════════════════════════
  Future<bool> connectIntegration(IntegrationType type) async
  {
    await Future.delayed(const Duration(milliseconds: 800));
    return true;
  }

 // ═══════════════════════════════════════════════════════
  Future<bool> disconnectIntegration(IntegrationType type) async
  {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }
}