import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/sync/services/connectivity_service.dart';

import '../../../data/repositories/github_repository.dart';
import '../../../data/models/github_model.dart';
import '../../../data/models/integration_model.dart';
import '../../../data/services/github_status_sync_service.dart';

import 'github_state.dart';
import '../integration_support.dart';

class GitHubCubit extends Cubit<GitHubState> {
  final GitHubRepository repository;

  final _githubSync = GitHubStatusSyncService.instance;
  final _connectivity = ConnectivityService();
  final _session = CurrentUserService.instance;

  List<IntegrationModel> _current = [];

  CacheSessionGuard? _guard;
  bool? _adminAtCapture;

  StreamSubscription<bool>? _connectionSubscription;

  Timer? _githubExpiryTimer;
  Timer? _refreshTimer;

  bool _loading = false;
  bool _mutating = false;
  bool _awaitingSelection = false;

  GitHubCubit({GitHubRepository? repository})
    : repository = repository ?? GitHubRepository(),
      super(const GitHubInitial()) {
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

    _githubExpiryTimer?.cancel();

    _current = [];
    _loading = false;
    _mutating = false;
    _awaitingSelection = false;

    if (!isClosed) {
      emit(const GitHubInitial());
      if (wasActive && _session.user != null) unawaited(loadIntegrations());
    }
  }

  void _initializeIntegrations() {
    if (_current.isNotEmpty) return;
    _current = const [
      IntegrationModel(
        type: IntegrationType.github,
        name: 'GitHub',
        description: 'Connect commits, pull requests, and branches',
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

      emit(const GitHubError('Your session is unavailable.'));

      return;
    }

    _loading = true;

    try {
      if (!publishIntermediate || state is GitHubInitial) {
        emit(const GitHubLoading());
      }

      _initializeIntegrations();

      await _restoreGitHubCache(guard);

      if (!_canPublish(guard)) return;

      if (publishIntermediate) _emitLoaded();

      final connected = await _connectivity.hasNetworkConnection();

      if (!_canPublish(guard)) return;

      if (!connected) {
        _markStatusesUnverified(publish: publishIntermediate);
        return;
      }

      await _checkGitHubStatus(guard);
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

    _current = _current.map((item) {
      final syncedAt = item.lastSyncedAt;

      final validSnapshot =
          syncedAt != null &&
          DateTime.now().toUtc().isBefore(
            syncedAt.add(const Duration(hours: 24)),
          );

      if (item.type == IntegrationType.github &&
          validSnapshot &&
          item.status != IntegrationStatus.unknown &&
          item.status != IntegrationStatus.connecting) {
        return item.copyWith(isFromCache: true);
      }

      return item.copyWith(
        status: IntegrationStatus.unknown,
        clearAccountName: true,
        clearLastSyncedAt: true,
        suspended: false,
        isFromCache: false,
      );
    }).toList();

    if (publish) _emitLoaded();
  }

  Future<void> _restoreGitHubCache(CacheSessionGuard guard) async {
    try {
      if (isAdmin) {
        final entry = await _githubSync.local.readCompany(guard.scope);

        if (!_canPublish(guard)) return;

        if (entry == null || entry.isExpired) {
          _setGitHubUnknown();
          return;
        }

        _applyCompanyStatus(
          entry.data,
          isFromCache: true,
          syncedAt: entry.syncedAt,
        );

        _scheduleGitHubExpiry(guard, entry.expiresAt);
      } else {
        final entry = await _githubSync.local.readEmployee(guard.scope);

        if (!_canPublish(guard)) return;

        if (entry == null || entry.isExpired) {
          _setGitHubUnknown();
          return;
        }

        _applyEmployeeStatus(
          entry.data,
          isFromCache: true,
          syncedAt: entry.syncedAt,
        );

        _scheduleGitHubExpiry(guard, entry.expiresAt);
      }
    } catch (_) {
      if (_canPublish(guard)) {
        _setGitHubUnknown();
      }
    }
  }

  Future<void> _invalidateGitHubCache(CacheSessionGuard guard) async {
    guard.ensureValid();

    if (isAdmin) {
      await _githubSync.local.invalidateCompany(guard.scope);
    } else {
      await _githubSync.local.invalidateEmployee(guard.scope);
    }

    guard.ensureValid();
  }

  void _scheduleGitHubExpiry(CacheSessionGuard guard, DateTime? expiresAt) {
    _githubExpiryTimer?.cancel();

    if (expiresAt == null) return;

    final remaining = expiresAt.difference(DateTime.now().toUtc());

    _githubExpiryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        if (!_canPublish(guard)) return;

        _setGitHubUnknown();

        if (!_mutating && !_awaitingSelection) {
          _emitLoaded();
        }
      },
    );
  }

  // ============================================================
  // GITHUB STATUS
  // ============================================================

  Future<void> _checkGitHubStatus(CacheSessionGuard guard) async {
    try {
      if (isAdmin) {
        final status = await _githubSync.refreshCompany(
          scope: guard.scope,
          repository: repository,
        );

        if (!_canPublish(guard)) return;

        _applyCompanyStatus(status, syncedAt: DateTime.now().toUtc());
      } else {
        final status = await _githubSync.refreshEmployee(
          scope: guard.scope,
          repository: repository,
        );

        if (!_canPublish(guard)) return;

        _applyEmployeeStatus(status, syncedAt: DateTime.now().toUtc());
      }

      _scheduleGitHubExpiry(
        guard,
        DateTime.now().toUtc().add(const Duration(hours: 24)),
      );
    } catch (error) {
      if (!_canPublish(guard)) return;

      if (isTemporaryIntegrationFailure(error)) {
        await _restoreGitHubCache(guard);
      } else {
        _setGitHubUnknown();
      }
    }
  }

  void _applyCompanyStatus(
    GitHubCompanyStatus status, {
    bool isFromCache = false,
    required DateTime syncedAt,
  }) {
    _updateStatus(
      IntegrationType.github,
      status.connected
          ? IntegrationStatus.connected
          : IntegrationStatus.disconnected,
      accountName: status.accountLogin,
      suspended: status.suspended,
      isFromCache: isFromCache,
      lastSyncedAt: syncedAt,
      clearAccountName: !status.connected || status.accountLogin == null,
    );
  }

  void _applyEmployeeStatus(
    GitHubEmployeeStatus status, {
    bool isFromCache = false,
    required DateTime syncedAt,
  }) {
    _updateStatus(
      IntegrationType.github,
      status.connected
          ? IntegrationStatus.connected
          : IntegrationStatus.disconnected,
      accountName: status.githubLogin,
      suspended: false,
      isFromCache: isFromCache,
      lastSyncedAt: syncedAt,
      clearAccountName: !status.connected || status.githubLogin == null,
    );
  }

  void _setGitHubUnknown() {
    _githubExpiryTimer?.cancel();

    _updateStatus(
      IntegrationType.github,
      IntegrationStatus.unknown,
      clearAccountName: true,
      clearLastSyncedAt: true,
      suspended: false,
      isFromCache: false,
    );
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

  Future<void> connectGitHub({bool authorizeExisting = false}) async {
    await _openConnectUrl(
      type: IntegrationType.github,
      provider: 'GitHub',
      request: () {
        return isAdmin
            ? repository.startGitHubCompanyConnection(
                authorizeExisting: authorizeExisting,
              )
            : repository.startGitHubEmployeeConnection();
      },
    );
  }

  Future<void> handleGitHubCallback(String status, String? completionId) async {
    final guard = _ensureSession();

    if (guard == null) {
      _emitError('Your session is unavailable.');
      return;
    }

    _awaitingSelection = false;

    switch (status) {
      case 'awaiting-approval':
        _awaitingSelection = true;

        emit(const GitHubApprovalPending());

        return;

      case 'confirm':
        if (completionId == null || completionId.trim().isEmpty) {
          _emitError('GitHub completion information is missing.');

          return;
        }

        await _fetchGitHubPending(completionId);

        return;

      case 'success':
        try {
          await _invalidateGitHubCache(guard);
        } catch (_) {
          if (_canPublish(guard)) {
            _setGitHubUnknown();
          }
        }

        if (_canPublish(guard)) {
          await loadIntegrations(publishIntermediate: false);
        }

        return;

      case 'no-eligible-installations':
        _emitError('No eligible GitHub installations were found.');

        return;

      default:
        _emitError('GitHub authorization was cancelled or denied.');
    }
  }

  Future<void> _fetchGitHubPending(String completionId) async {
    final guard = await _beginOperation();

    if (guard == null) return;

    emit(const GitHubLoading());

    bool shouldComplete = false;
    int? selectedInstallationId;

    try {
      final response = await repository.getGitHubPendingConnection(
        completionId,
      );

      if (!_canPublish(guard)) return;

      ensureIntegrationSuccess(response);

      if (response.data is! Map) {
        throw const FormatException('Invalid GitHub installation response.');
      }

      final pending = GitHubPendingConnection.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      if (pending.kind == 'employee') {
        shouldComplete = true;
      } else if (pending.installations.isEmpty) {
        _emitError('No eligible GitHub installations were found.');
      } else if (pending.installations.length == 1) {
        shouldComplete = true;

        selectedInstallationId = pending.installations.first.installationId;
      } else {
        _awaitingSelection = true;

        emit(
          GitHubInstallationSelectionRequired(
            completionId: completionId,
            githubLogin: pending.githubLogin,
            installations: pending.installations,
          ),
        );
      }
    } catch (error) {
      if (!_canPublish(guard)) return;

      _emitError(
        'Failed to load GitHub installation options: '
        '${friendlyIntegrationError(error)}',
      );
    } finally {
      _endOperation(guard);
    }

    if (shouldComplete && _canPublish(guard)) {
      await completeGitHubConnection(completionId, selectedInstallationId);
    }
  }

  Future<void> completeGitHubConnection(
    String completionId,
    int? installationId,
  ) async {
    if (completionId.trim().isEmpty) {
      _emitError('GitHub completion information is missing.');

      return;
    }

    final guard = await _beginOperation(allowSelection: true);

    if (guard == null) return;

    _awaitingSelection = false;

    emit(const GitHubLoading());

    bool completed = false;

    try {
      await _invalidateGitHubCache(guard);

      if (!_canPublish(guard)) return;

      _setGitHubUnknown();

      final response = await repository.completeGitHubConnection(
        completionId,
        installationId,
      );

      if (!_canPublish(guard)) return;

      ensureIntegrationSuccess(response);

      completed = true;
    } catch (error) {
      if (!_canPublish(guard)) return;

      _setGitHubUnknown();

      _emitError(
        'Failed to complete GitHub connection: '
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

      await _restoreGitHubCache(guard);

      if (!_canPublish(guard)) return;

      _emitError(
        'Failed to start $provider connection: '
        '${friendlyIntegrationError(error)}',
      );
    } finally {
      _endOperation(guard);
    }
  }

  Future<void> disconnectGitHub() async {
    await _disconnect(
      type: IntegrationType.github,
      provider: 'GitHub',
      request: () {
        return isAdmin
            ? repository.disconnectGitHubCompany()
            : repository.disconnectGitHubEmployee();
      },
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

    emit(const GitHubLoading());

    bool completed = false;

    try {
      await _invalidateGitHubCache(guard);

      if (!_canPublish(guard)) return;

      _setGitHubUnknown();

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

    emit(GitHubLoaded(List<IntegrationModel>.unmodifiable(_current)));
  }

  void _emitError(String message) {
    if (isClosed) return;

    emit(GitHubError(message));

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

    _githubExpiryTimer?.cancel();
    _refreshTimer?.cancel();

    await _connectionSubscription?.cancel();

    await super.close();
  }
}
