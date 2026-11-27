import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/sync/services/connectivity_service.dart';

import '../../../data/repositories/jira_repository.dart';
import '../../../data/models/integration_model.dart';

import 'jira_state.dart';
import '../integration_support.dart';

class JiraCubit extends Cubit<JiraState> {
  final JiraRepository repository;

  final _connectivity = ConnectivityService();
  final _session = CurrentUserService.instance;

  List<IntegrationModel> _current = [];

  CacheSessionGuard? _guard;
  bool? _adminAtCapture;

  StreamSubscription<bool>? _connectionSubscription;

  Timer? _refreshTimer;

  bool _loading = false;
  bool _mutating = false;
  bool _awaitingSelection = false;

  JiraCubit({JiraRepository? repository})
    : repository = repository ?? JiraRepository(),
      super(const JiraInitial()) {
    _session.userNotifier.addListener(_onSessionChanged);

    _connectionSubscription = _connectivity.connectionChanges.listen((
      connected,
    ) {
      if (isClosed || _guard?.isValid != true || _adminAtCapture != isAdmin) {
        return;
      }

      if (_mutating || _awaitingSelection) return;

      if (connected) {
        unawaited(loadIntegrations());
      } else {
        _markStatusesUnverified();
      }
    });

    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!isClosed &&
          !_mutating &&
          !_awaitingSelection &&
          _guard?.isValid == true) {
        unawaited(loadIntegrations());
      }
    });
  }

  // ============================================================
  // SESSION
  // ============================================================

  List<IntegrationModel> get current => List.unmodifiable(_current);

  bool get isBusy => _loading || _mutating || _awaitingSelection;

  bool get isAdmin => _session.user?.role == UserRole.admin;

  bool _canPublish(CacheSessionGuard guard) {
    return !isClosed &&
        identical(_guard, guard) &&
        guard.isValid &&
        _adminAtCapture == isAdmin;
  }

  CacheSessionGuard? _ensureSession() {
    if (isClosed) return null;

    final existing = _guard;

    if (existing != null && existing.isValid && _adminAtCapture == isAdmin) {
      return existing;
    }

    final scope = CacheScope.fromCurrentUser();

    if (scope == null) return null;

    try {
      final guard = CacheSessionGuard.capture(scope);

      _guard = guard;
      _adminAtCapture = isAdmin;

      _initializeIntegrations();

      return guard;
    } catch (_) {
      return null;
    }
  }

  void _onSessionChanged() {
    if (_guard?.isValid == true && _adminAtCapture == isAdmin) return;
    final wasActive = _guard != null;
    _guard = null;
    _adminAtCapture = null;

    _current = [];
    _loading = false;
    _mutating = false;
    _awaitingSelection = false;

    if (!isClosed) {
      emit(const JiraInitial());
      if (wasActive && _session.user != null) unawaited(loadIntegrations());
    }
  }

  void _initializeIntegrations() {
    if (_current.isNotEmpty) return;
    _current = const [
      IntegrationModel(
        type: IntegrationType.jira,
        name: 'Jira',
        description: 'Sync issues, sprints, and backlogs',
      ),
    ];
  }

  Future<void> loadIntegrations({bool publishIntermediate = true}) async {
    if (isClosed || _loading || _mutating || _awaitingSelection) {
      return;
    }

    final guard = _ensureSession();

    if (guard == null) {
      _current = [];

      emit(const JiraError('Your session is unavailable.'));

      return;
    }

    _loading = true;

    try {
      if (!publishIntermediate || state is JiraInitial) {
        emit(const JiraLoading());
      }

      _initializeIntegrations();

      if (!_canPublish(guard)) return;

      _updateStatus(
        IntegrationType.jira,
        IntegrationStatus.unknown,
        clearAccountName: true,
        clearLastSyncedAt: true,
        isFromCache: false,
      );

      if (publishIntermediate) _emitLoaded();

      final connected = await _connectivity.hasNetworkConnection();

      if (!_canPublish(guard)) return;

      if (!connected) {
        _markStatusesUnverified(publish: publishIntermediate);
        return;
      }

      await _checkJiraStatus(guard);
    } catch (_) {
      if (!_canPublish(guard)) return;

      _markStatusesUnverified(publish: publishIntermediate);
    } finally {
      if (_canPublish(guard)) {
        _loading = false;
        _emitLoaded();
      }
    }
  }

  Future<void> refresh() => loadIntegrations();

  void _markStatusesUnverified({bool publish = true}) {
    if (isClosed || _guard?.isValid != true || _adminAtCapture != isAdmin) {
      return;
    }
    _setJiraUnknown();
    if (publish) _emitLoaded();
  }

  void _setJiraUnknown() {
    _updateStatus(
      IntegrationType.jira,
      IntegrationStatus.unknown,
      clearAccountName: true,
      clearLastSyncedAt: true,
      isFromCache: false,
    );
  }

  bool _isNotConnected(Response? response) {
    if (response?.statusCode != 404) return false;
    final data = response?.data;
    return data is Map && data['message'] == 'Connect Jira first.';
  }

  Future<void> _checkJiraStatus(CacheSessionGuard guard) async {
    final admin = isAdmin;
    try {
      final response = admin
          ? await repository.checkJiraStatus()
          : await repository.getEmployeeIdentity();
      if (!_canPublish(guard)) return;
      if (admin && _isNotConnected(response)) {
        _updateStatus(
          IntegrationType.jira,
          IntegrationStatus.disconnected,
          clearAccountName: true,
          clearLastSyncedAt: true,
          isFromCache: false,
        );
        return;
      }
      ensureIntegrationSuccess(response);
      if (response.data is! Map) {
        throw const FormatException('Invalid Jira status.');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (!admin) {
        if (data['employeeId'] != guard.scope.userId ||
            !data.containsKey('jira') ||
            data['jiraIdentityAmbiguous'] != false) {
          _setJiraUnknown();
          return;
        }
        final identity = data['jira'];
        if (identity != null &&
            (identity is! Map ||
                identity['accountId'] is! String ||
                (identity['accountId'] as String).trim().isEmpty)) {
          _setJiraUnknown();
          return;
        }
        _updateStatus(
          IntegrationType.jira,
          identity == null
              ? IntegrationStatus.disconnected
              : IntegrationStatus.connected,
          clearAccountName: true,
          isFromCache: false,
          lastSyncedAt: DateTime.now().toUtc(),
        );
        return;
      }
      final site = data['site']?.toString().trim();
      if (site == null || site.isEmpty) {
        throw const FormatException('Missing Jira site.');
      }
      _updateStatus(
        IntegrationType.jira,
        IntegrationStatus.connected,
        accountName: site,
        isFromCache: false,
        lastSyncedAt: DateTime.now().toUtc(),
      );
    } on DioException catch (error) {
      if (!_canPublish(guard)) return;
      if (admin && _isNotConnected(error.response)) {
        _updateStatus(
          IntegrationType.jira,
          IntegrationStatus.disconnected,
          clearAccountName: true,
          clearLastSyncedAt: true,
          isFromCache: false,
        );
      } else {
        _setJiraUnknown();
      }
    } catch (_) {
      if (_canPublish(guard)) _setJiraUnknown();
    }
  }

  Future<CacheSessionGuard?> _beginOperation({
    IntegrationType? type,
    bool requireVerifiedStatus = false,
    bool allowSelection = false,
  }) async {
    if (isClosed ||
        _loading ||
        _mutating ||
        (_awaitingSelection && !allowSelection)) {
      return null;
    }

    final guard = _ensureSession();

    if (guard == null) {
      _emitError('Your session is unavailable.');
      return null;
    }

    if (requireVerifiedStatus && type != null) {
      final matches = _current.where((item) => item.type == type);

      if (matches.isEmpty || !matches.first.canModify) {
        _emitError('Refresh the integration status before continuing.');

        return null;
      }
    }

    _mutating = true;

    try {
      final connected = await _connectivity.hasNetworkConnection();

      if (!_canPublish(guard)) return null;

      if (!connected) {
        _mutating = false;

        _emitError('An internet connection is required.');

        return null;
      }

      return guard;
    } catch (_) {
      if (_canPublish(guard)) {
        _mutating = false;

        _emitError('Unable to verify the network connection.');
      }

      return null;
    }
  }

  void _endOperation(CacheSessionGuard guard) {
    if (_canPublish(guard)) {
      _mutating = false;
    }
  }

  Future<void> connectJira() async {
    await _openConnectUrl(
      type: IntegrationType.jira,
      provider: 'Jira',
      request: () => repository.connectJira(employee: !isAdmin),
    );
  }

  Future<void> handleJiraCallback(String status, String? pendingId) async {
    final guard = _ensureSession();

    if (guard == null) {
      _emitError('Your session is unavailable.');
      return;
    }

    _awaitingSelection = false;

    if (status == 'success') {
      await loadIntegrations(publishIntermediate: false);
      return;
    }

    if (isAdmin &&
        status == 'select-site' &&
        pendingId != null &&
        pendingId.isNotEmpty) {
      await _fetchPendingSites(pendingId);
      return;
    }

    _emitError('Jira authorization was cancelled or denied.');
  }

  Future<void> _fetchPendingSites(String pendingId) async {
    final guard = await _beginOperation();

    if (guard == null) return;

    emit(const JiraLoading());

    try {
      final response = await repository.fetchJiraPendingSites(pendingId);

      if (!_canPublish(guard)) return;

      ensureIntegrationSuccess(response);

      final data = response.data;

      final dynamic rawSites;

      if (data is List) {
        rawSites = data;
      } else if (data is Map) {
        rawSites = data['data'] ?? data['items'] ?? data['sites'];
      } else {
        rawSites = null;
      }

      if (rawSites is! List) {
        throw const FormatException('Invalid Jira sites response.');
      }

      final sites = rawSites
          .whereType<Map>()
          .map((site) => Map<String, dynamic>.from(site))
          .toList();

      if (sites.isEmpty) {
        _emitError('No Jira sites found for this account.');

        return;
      }

      _awaitingSelection = true;

      emit(JiraSiteSelectionRequired(sites: sites, pendingId: pendingId));
    } catch (error) {
      if (!_canPublish(guard)) return;

      _emitError(
        'Failed to fetch Jira sites: '
        '${friendlyIntegrationError(error)}',
      );
    } finally {
      _endOperation(guard);
    }
  }

  Future<void> completeJiraConnection(String pendingId, String cloudId) async {
    if (!isAdmin || pendingId.trim().isEmpty || cloudId.trim().isEmpty) {
      _emitError('Jira connection information is missing.');

      return;
    }

    final guard = await _beginOperation(allowSelection: true);

    if (guard == null) return;

    _awaitingSelection = false;

    emit(const JiraLoading());

    bool completed = false;

    try {
      final response = await repository.completeJiraConnection(
        pendingId,
        cloudId,
      );

      if (!_canPublish(guard)) return;

      ensureIntegrationSuccess(response);

      completed = true;
    } catch (error) {
      if (!_canPublish(guard)) return;

      _emitError(
        'Failed to complete Jira connection: '
        '${friendlyIntegrationError(error)}',
      );
    } finally {
      _endOperation(guard);
    }

    if (completed && _canPublish(guard)) {
      await loadIntegrations(publishIntermediate: false);
    }
  }

  Future<void> _openConnectUrl({
    required IntegrationType type,
    required String provider,
    required Future<Response> Function() request,
  }) async {
    final guard = await _beginOperation(
      type: type,
      requireVerifiedStatus: true,
    );

    if (guard == null) return;

    _updateStatus(type, IntegrationStatus.connecting);

    _emitLoaded();

    try {
      final response = await request();

      if (!_canPublish(guard)) return;

      ensureIntegrationSuccess(response);

      final uri = readIntegrationUrl(response.data);

      if (uri == null) {
        throw const FormatException('Invalid authorization URL.');
      }

      final opened = await launchUrl(uri, webOnlyWindowName: '_self');

      if (!_canPublish(guard)) return;

      if (!opened) {
        throw const FormatException('Could not open authorization URL.');
      }

      _emitLoaded();
    } catch (error) {
      if (!_canPublish(guard)) return;

      _setJiraUnknown();

      if (!_canPublish(guard)) return;

      _emitError(
        'Failed to start $provider connection: '
        '${friendlyIntegrationError(error)}',
      );
    } finally {
      _endOperation(guard);
    }
  }

  Future<void> disconnectJira() async {
    if (!isAdmin) {
      _emitError('Only company administrators can disconnect Jira.');
      return;
    }
    await _disconnect(
      type: IntegrationType.jira,
      provider: 'Jira',
      request: repository.disconnectJira,
    );
  }

  Future<void> _disconnect({
    required IntegrationType type,
    required String provider,
    required Future<Response> Function() request,
  }) async {
    final guard = await _beginOperation(
      type: type,
      requireVerifiedStatus: true,
    );

    if (guard == null) return;

    emit(const JiraLoading());

    bool completed = false;

    try {
      _setJiraUnknown();

      final response = await request();

      if (!_canPublish(guard)) return;

      ensureIntegrationSuccess(response);

      completed = true;
    } catch (error) {
      if (!_canPublish(guard)) return;

      _emitError(
        'The $provider disconnection could not be '
        'confirmed. ${friendlyIntegrationError(error)}',
      );
    } finally {
      _endOperation(guard);
    }

    if (!_canPublish(guard)) return;

    if (completed) {
      await loadIntegrations();
    } else {
      _emitLoaded();
    }
  }

  void _updateStatus(
    IntegrationType type,
    IntegrationStatus status, {
    String? accountName,
    bool? suspended,
    bool? isFromCache,
    DateTime? lastSyncedAt,
    bool clearAccountName = false,
    bool clearLastSyncedAt = false,
  }) {
    if (isClosed) return;

    _current = _current.map((item) {
      if (item.type != type) return item;

      return item.copyWith(
        status: status,
        accountName: accountName,
        suspended: suspended,
        isFromCache: isFromCache,
        lastSyncedAt: lastSyncedAt,
        clearAccountName: clearAccountName,
        clearLastSyncedAt: clearLastSyncedAt,
      );
    }).toList();
  }

  void _emitLoaded() {
    if (isClosed || _guard?.isValid != true || _adminAtCapture != isAdmin) {
      return;
    }

    emit(JiraLoaded(List<IntegrationModel>.unmodifiable(_current)));
  }

  void _emitError(String message) {
    if (isClosed) return;

    emit(JiraError(message));

    if (_guard?.isValid == true) {
      _emitLoaded();
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  Future<void> close() async {
    _session.userNotifier.removeListener(_onSessionChanged);

    _guard = null;

    _refreshTimer?.cancel();

    await _connectionSubscription?.cancel();

    await super.close();
  }
}
