import 'package:dio/dio.dart';
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

    emit(IntegrationsLoaded(List.from(_current)));
  }

  Future<void> connectJira() async {
    emit(const IntegrationsLoading());

    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.jiraConnect,
        options: Options(followRedirects: false),
      );

      // ─── جديد: لو التوكن مش متبعت أو انتهى ───
      if (response.statusCode == 401) {
        emit(const IntegrationsError('Session expired, please log in again.'));
        emit(IntegrationsLoaded(List.from(_current)));
        return;
      }

      String? authUrl;

      if (response.statusCode == 302 || response.statusCode == 307) {
        authUrl = response.headers.value('location');
      } else if (response.statusCode == 200) {
        if (response.data is Map) {
          authUrl = response.data['url']?.toString();
        }
      }

      if (authUrl == null || authUrl.isEmpty) {
        emit(IntegrationsError(
            'Server did not return a Jira URL. Status: ${response.statusCode}'));
        emit(IntegrationsLoaded(List.from(_current)));
        return;
      }

      if (await canLaunchUrl(Uri.parse(authUrl))) {
        await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
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

  Future<void> connect(IntegrationType type) async {
    if (type == IntegrationType.jira) {
      await connectJira();
      return;
    }

    _updateStatus(type, IntegrationStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 800));
    _updateStatus(
      type,
      IntegrationStatus.connected,
      accountName: 'GitHub Account',
    );
  }

  Future<void> disconnect(IntegrationType type) async {
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