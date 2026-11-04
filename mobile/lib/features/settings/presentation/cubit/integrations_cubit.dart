import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syntrace/features/settings/data/models/integration_model.dart';
import 'integrations_state.dart';

class IntegrationsCubit extends Cubit<IntegrationsState> {
  IntegrationsCubit() : super(const IntegrationsInitial());

  List<IntegrationModel> _current = [];
  List<IntegrationModel> get current => _current;

  Future<void> loadIntegrations() async {
    emit(const IntegrationsLoading());

    _current = const [
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

    await _checkJiraStatus();
    emit(IntegrationsLoaded(List.from(_current)));
  }

  Future<void> _checkJiraStatus() async {
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.jiraSyncStatus);

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final site = data['site']?.toString();
        _updateStatus(
          IntegrationType.jira,
          IntegrationStatus.connected,
          accountName: (site != null && site.isNotEmpty) ? site : 'Jira Workspace',
        );
      } else {
        _updateStatus(IntegrationType.jira, IntegrationStatus.disconnected);
      }
    } catch (e) {
      _updateStatus(IntegrationType.jira, IntegrationStatus.disconnected);
    }
  }

  Future<void> connectJira() async {
    emit(const IntegrationsLoading());

    try {
      final response = await ApiClient.instance.get(ApiEndpoints.jiraConnect);

      if (response.statusCode == 409) {
        _updateStatus(IntegrationType.jira, IntegrationStatus.connected);
        emit(const IntegrationsError('Jira is already connected.'));
        emit(IntegrationsLoaded(List.from(_current)));
        return;
      }

      if (response.statusCode != 200) {
        emit(IntegrationsError('Server did not return a Jira URL (status ${response.statusCode}).'));
        emit(IntegrationsLoaded(List.from(_current)));
        return;
      }

      String? authUrl;
      final data = response.data;

      if (data is String && data.trim().isNotEmpty) {
        authUrl = data.trim();
      } else if (data is Map) {
        authUrl = data['url']?.toString() ?? data['authorizeUrl']?.toString() ?? data['authUrl']?.toString();
      }

      if (authUrl == null || !authUrl.startsWith('http')) {
        emit(const IntegrationsError('Server did not return a valid Jira URL.'));
        emit(IntegrationsLoaded(List.from(_current)));
        return;
      }

      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        emit(IntegrationsLoaded(List.from(_current)));
      } else {
        emit(const IntegrationsError('Could not open browser.'));
        emit(IntegrationsLoaded(List.from(_current)));
      }
    } catch (e) {
      emit(IntegrationsError('Failed to connect to Jira: $e'));
      emit(IntegrationsLoaded(List.from(_current)));
    }
  }

  Future<void> handleJiraCallback(String status, String? pendingId) async {
    if (status == 'success') {
      await loadIntegrations();
    } else if (status == 'select-site' && pendingId != null) {
      await _fetchPendingSites(pendingId);
    }
  }

  Future<void> _fetchPendingSites(String pendingId) async {
    emit(const IntegrationsLoading());
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.jiraPendingSites,
        queryParameters: {'pendingId': pendingId},
      );

      if (response.statusCode == 200 && response.data is List) {
        final sites = List<Map<String, dynamic>>.from(response.data);
        emit(IntegrationsSiteSelectionRequired(sites: sites, pendingId: pendingId));
      } else {
        emit(const IntegrationsError('Failed to fetch Jira sites.'));
        emit(IntegrationsLoaded(List.from(_current)));
      }
    } catch (e) {
      emit(IntegrationsError('Error fetching sites: $e'));
      emit(IntegrationsLoaded(List.from(_current)));
    }
  }

  Future<void> completeJiraConnection(String pendingId, String cloudId) async {
    emit(const IntegrationsLoading());
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.jiraCompleteConnection,
        data: {
          'pendingId': pendingId,
          'cloudId': cloudId,
        },
      );

      if (response.statusCode == 200) {
        await loadIntegrations();
      } else {
        emit(const IntegrationsError('Failed to complete Jira connection.'));
        emit(IntegrationsLoaded(List.from(_current)));
      }
    } catch (e) {
      emit(IntegrationsError('Error completing connection: $e'));
      emit(IntegrationsLoaded(List.from(_current)));
    }
  }

  Future<void> disconnectJira() async {
    emit(const IntegrationsLoading());
    try {
      final response = await ApiClient.instance.delete(ApiEndpoints.jiraDisconnect);
      
      if (response.statusCode == 200) {
        _updateStatus(IntegrationType.jira, IntegrationStatus.disconnected);
        emit(IntegrationsLoaded(List.from(_current)));
      } else {
        emit(const IntegrationsError('Failed to disconnect Jira.'));
        emit(IntegrationsLoaded(List.from(_current)));
      }
    } catch (e) {
      emit(IntegrationsError('Error disconnecting Jira: $e'));
      emit(IntegrationsLoaded(List.from(_current)));
    }
  }

  Future<void> connect(IntegrationType type) async {
    if (type == IntegrationType.jira) {
      await connectJira();
      return;
    }
    _updateStatus(type, IntegrationStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 800));
    _updateStatus(type, IntegrationStatus.connected, accountName: 'GitHub Account');
  }

  Future<void> disconnect(IntegrationType type) async {
    if (type == IntegrationType.jira) {
      await disconnectJira();
      return;
    }
    _updateStatus(type, IntegrationStatus.disconnected);
  }

  void _updateStatus(
    IntegrationType type,
    IntegrationStatus status, {
    String? accountName,
  }) {
    _current = _current.map((i) {
      if (i.type == type) {
        return i.copyWith(status: status, accountName: accountName);
      }
      return i;
    }).toList();

    emit(IntegrationsLoaded(List.from(_current)));
  }
}