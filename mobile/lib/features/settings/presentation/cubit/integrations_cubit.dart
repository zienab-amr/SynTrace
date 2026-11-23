import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/features/settings/data/integrations_repository.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';
import 'package:syntrace/features/settings/data/models/integration_model.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_state.dart';
import 'package:url_launcher/url_launcher.dart';

class IntegrationsCubit extends Cubit<IntegrationsState> {
  final IntegrationsRepository repository;
  List<IntegrationModel> _current = [];

  IntegrationsCubit({IntegrationsRepository? repository})
      : repository = repository ?? IntegrationsRepository(),
        super(const IntegrationsInitial());

  List<IntegrationModel> get current => List.unmodifiable(_current);

  bool get isAdmin => CurrentUserService.instance.user?.role == UserRole.admin;

  Future<void> loadIntegrations() async {
    emit(const IntegrationsLoading());
    _current = const [
      IntegrationModel(
        type: IntegrationType.jira,
        name: 'Jira',
        description: 'Sync issues, sprints, and backlogs',
      ),
      IntegrationModel(
        type: IntegrationType.github,
        name: 'GitHub',
        description: 'Connect commits, pull requests, and branches',
      ),
    ];

    await _checkJiraStatus();
    await _checkGitHubStatus();
    _emitLoaded();
  }

  Future<void> _checkJiraStatus() async {
    try {
      final response = await repository.checkJiraStatus();
      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final account = data['site']?.toString();
        _updateStatus(
          IntegrationType.jira,
          IntegrationStatus.connected,
          accountName: account == null || account.isEmpty ? 'Jira Workspace' : account,
        );
      }
    } catch (_) {}
  }

  Future<void> _checkGitHubStatus() async {
    try {
      final response = isAdmin
          ? await repository.getGitHubCompanyStatus()
          : await repository.getGitHubEmployeeStatus();
      if (response.statusCode != 200 || response.data is! Map) return;
      final data = Map<String, dynamic>.from(response.data as Map);

      if (isAdmin) {
        final status = GitHubCompanyStatus.fromJson(data);
        _updateStatus(
          IntegrationType.github,
          status.connected
              ? IntegrationStatus.connected
              : IntegrationStatus.disconnected,
          accountName: status.accountLogin,
          suspended: status.suspended,
        );
      } else {
        final status = GitHubEmployeeStatus.fromJson(data);
        _updateStatus(
          IntegrationType.github,
          status.connected
              ? IntegrationStatus.connected
              : IntegrationStatus.disconnected,
          accountName: status.githubLogin,
        );
      }
    } catch (_) {}
  }

  Future<void> connect(IntegrationType type) async {
    if (type == IntegrationType.jira) {
      await connectJira();
    } else {
      await connectGitHub();
    }
  }

  Future<void> connectJira() async {
    await _openConnectUrl(
      () => repository.connectJira(employee: !isAdmin),
      'Jira',
    );
  }

  Future<void> handleJiraCallback(String status, String? pendingId) async {
    if (status == 'success') {
      await loadIntegrations();
    } else if (status == 'select-site' && pendingId != null) {
      await _fetchPendingSites(pendingId);
    } else {
      _emitError('Jira authorization was cancelled or denied.');
    }
  }

  Future<void> _fetchPendingSites(String pendingId) async {
    emit(const IntegrationsLoading());
    try {
      final response = await repository.fetchJiraPendingSites(pendingId);
      if (response.statusCode != 200 || response.data == null) {
        _emitError('Failed to fetch Jira sites.');
        return;
      }

      final data = response.data;
      final List<dynamic> rawSites;
      if (data is List) {
        rawSites = data;
      } else if (data is Map) {
        rawSites = (data['data'] ?? data['items'] ?? data['sites'] ?? []) as List<dynamic>;
      } else {
        rawSites = const [];
      }

      final sites = rawSites
          .whereType<Map>()
          .map((site) => Map<String, dynamic>.from(site))
          .toList();
      if (sites.isEmpty) {
        _emitError('No Jira sites found for this account.');
        return;
      }

      emit(
        IntegrationsSiteSelectionRequired(
          sites: sites,
          pendingId: pendingId,
        ),
      );
    } catch (error) {
      _emitError('Failed to fetch Jira sites: $error');
    }
  }

  Future<void> completeJiraConnection(String pendingId, String cloudId) async {
    emit(const IntegrationsLoading());
    try {
      final response = await repository.completeJiraConnection(pendingId, cloudId);
      if (response.statusCode == 200 || response.statusCode == 204) {
        await loadIntegrations();
      } else {
        _emitError('Failed to complete Jira connection.');
      }
    } catch (error) {
      _emitError('Failed to complete Jira connection: $error');
    }
  }

  Future<void> connectGitHub({bool authorizeExisting = false}) async {
    _setConnecting(IntegrationType.github);
    try {
      final response = isAdmin
          ? await repository.startGitHubCompanyConnection(
              authorizeExisting: authorizeExisting,
            )
          : await repository.startGitHubEmployeeConnection();
      final url = _readUrl(response.data);
      if (url == null) throw const FormatException('Missing authorization URL');
      final opened = await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
      if (!opened) throw const FormatException('Could not open authorization URL');
      _emitLoaded();
    } catch (error) {
      _emitError('Failed to start GitHub connection: $error');
    }
  }

  Future<void> handleGitHubCallback(String status, String? completionId) async {
    switch (status) {
      case 'awaiting-approval':
        emit(const GitHubApprovalPending());
        return;
      case 'confirm':
        if (completionId == null || completionId.isEmpty) {
          _emitError('GitHub completion information is missing.');
          return;
        }
        await _fetchGitHubPending(completionId);
        return;
      case 'success':
        await loadIntegrations();
        return;
      case 'no-eligible-installations':
        _emitError('No eligible GitHub installations were found.');
        return;
      default:
        _emitError('GitHub authorization was cancelled or denied.');
    }
  }

  Future<void> _fetchGitHubPending(String completionId) async {
    emit(const IntegrationsLoading());
    try {
      final response = await repository.getGitHubPendingConnection(completionId);
      if (response.statusCode != 200 || response.data is! Map) {
        _emitError('Failed to load GitHub installation options.');
        return;
      }
      final pending = GitHubPendingConnection.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (pending.installations.isEmpty) {
        _emitError('No eligible GitHub installations were found.');
        return;
      }
      if (pending.installations.length == 1) {
        await completeGitHubConnection(
          completionId,
          pending.installations.first.installationId,
        );
        return;
      }
      emit(
        GitHubInstallationSelectionRequired(
          completionId: completionId,
          githubLogin: pending.githubLogin,
          installations: pending.installations,
        ),
      );
    } catch (error) {
      _emitError('Failed to load GitHub installation options: $error');
    }
  }

  Future<void> completeGitHubConnection(String completionId, int? installationId) async {
    emit(const IntegrationsLoading());
    try {
      final response = await repository.completeGitHubConnection(
        completionId,
        installationId,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await loadIntegrations();
      } else {
        _emitError('Failed to complete GitHub connection.');
      }
    } catch (error) {
      _emitError('Failed to complete GitHub connection: $error');
    }
  }

  Future<void> disconnect(IntegrationType type) async {
    if (type == IntegrationType.jira) {
      await disconnectJira();
      return;
    }
    await disconnectGitHub();
  }

  Future<void> disconnectJira() async {
    await _disconnect(
      repository.disconnectJira,
      IntegrationType.jira,
      'Jira',
    );
  }

  Future<void> disconnectGitHub() async {
    await _disconnect(
      isAdmin
          ? repository.disconnectGitHubCompany
          : repository.disconnectGitHubEmployee,
      IntegrationType.github,
      'GitHub',
    );
  }

  Future<void> _openConnectUrl(
    Future<Response> Function() request,
    String provider,
  ) async {
    try {
      final response = await request();
      final url = _readUrl(response.data);
      if (url == null) throw const FormatException('Missing authorization URL');
      final opened = await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
      if (!opened) throw const FormatException('Could not open authorization URL');
      _emitLoaded();
    } catch (error) {
      _emitError('Failed to start $provider connection: $error');
    }
  }

  Future<void> _disconnect(
    Future<Response> Function() request,
    IntegrationType type,
    String provider,
  ) async {
    emit(const IntegrationsLoading());
    try {
      final response = await request();
      if (response.statusCode == 200 || response.statusCode == 204) {
        _updateStatus(type, IntegrationStatus.disconnected);
        _emitLoaded();
      } else {
        _emitError('Failed to disconnect $provider.');
      }
    } catch (error) {
      _emitError('Failed to disconnect $provider: $error');
    }
  }

  String? _readUrl(dynamic data) {
    if (data is String && data.startsWith('http')) return data;
    if (data is Map) {
      final value = data['url'] ?? data['authorizeUrl'] ?? data['authUrl'];
      if (value is String && value.startsWith('http')) return value;
    }
    return null;
  }

  void _setConnecting(IntegrationType type) {
    _updateStatus(type, IntegrationStatus.connecting);
  }

  void _updateStatus(
    IntegrationType type,
    IntegrationStatus status, {
    String? accountName,
    bool? suspended,
  }) {
    _current = _current.map((item) {
      if (item.type != type) return item;
      return item.copyWith(
        status: status,
        accountName: accountName,
        suspended: suspended,
      );
    }).toList();
  }

  void _emitLoaded() {
    emit(IntegrationsLoaded(List.from(_current)));
  }

  void _emitError(String message) {
    emit(IntegrationsError(message));
    _emitLoaded();
  }
}
