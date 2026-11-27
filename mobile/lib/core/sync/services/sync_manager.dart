import 'dart:async';
import 'dart:convert';
import 'package:syntrace/core/cache/cache_session.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/core/network/services/token_refresh_service.dart';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/sync/cubit/sync_cubit.dart';
import 'package:syntrace/core/sync/models/sync_status.dart';
import 'package:syntrace/core/sync/models/sync_trigger.dart';
import 'package:syntrace/core/sync/services/connectivity_service.dart';
import 'package:syntrace/core/sync/services/sync_registry.dart';

class SyncManager with WidgetsBindingObserver {
  final ConnectivityService connectivity;
  final SyncRegistry registry;
  final SyncCubit cubit;

  SyncManager({
    required this.connectivity,
    required this.registry,
    required this.cubit,
  });

  StreamSubscription<bool>? _connectionSubscription;
  Timer? _timer;
  CancelToken? _cancelToken;

  CacheScope? _activeScope;

  final Map<String, DateTime> _lastTaskSync = {};

  bool _started = false;
  bool _running = false;
  bool _pending = false;
  bool _foreground = true;
  bool _sessionBlocked = false;

  int _generation = 0;
  int _failures = 0;

  bool get isRunning => _running;

  void start() {
    if (_started) return;

    _started = true;

    WidgetsBinding.instance.addObserver(this);

    _connectionSubscription = connectivity.connectionChanges.listen(
      _onConnectionChanged,
    );

    onSessionChanged();
  }

  void onSessionChanged() {
    if (!_started) return;

    final scope = CacheScope.fromCurrentUser();

    if (_activeScope == scope) return;

    _generation++;
    _cancelCurrentSync();

    _activeScope = scope;
    _lastTaskSync.clear();

    _failures = 0;
    _pending = false;
    _sessionBlocked = false;

    cubit.reset();

    if (scope != null && _foreground) {
      unawaited(requestSync(SyncTrigger.sessionChanged));
    }
  }

  void _onConnectionChanged(bool connected) {
    if (!_started || !_foreground) return;
    if (_activeScope == null || _sessionBlocked) return;

    if (!connected) {
      _generation++;
      _cancelCurrentSync();
      _pending = false;

      cubit.updateStatus(SyncStatus.offline);

      _scheduleNext();
      return;
    }

    _failures = 0;

    unawaited(requestSync(SyncTrigger.networkRestored));
  }

  Future<void> requestSync(SyncTrigger trigger) async {
    if (!_started || !_foreground || _sessionBlocked) {
      return;
    }

    final scope = _activeScope;

    if (scope == null || !scope.isCurrentSession) {
      return;
    }

    if (_running) {
      _pending = true;
      return;
    }

    _timer?.cancel();

    _running = true;

    final generation = _generation;
    final cancelToken = CancelToken();

    _cancelToken = cancelToken;

    try {
      final connected = await connectivity.hasNetworkConnection();

      if (!_isActive(generation, scope)) return;

      if (!connected) {
        cubit.updateStatus(SyncStatus.offline);
        return;
      }

      await CurrentUserService.instance.enforceDeadline();
      if (!_isActive(generation, scope)) return;
      final token = await SecureStorageService.instance.getToken();
      if (!_isActive(generation, scope) || token == null) return;
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map;
      final exp = claims['exp'];
      if (exp is! num ||
          DateTime.now().toUtc().millisecondsSinceEpoch + 60000 >= exp * 1000) {
        final outcome = await TokenRefreshService.instance.refresh(
          failedAccessToken: token,
          generation: CacheSession.instance.generation,
        );
        if (!_isActive(generation, scope)) return;
        if (outcome != RefreshOutcome.refreshed) {
          _failures++;
          cubit.updateStatus(SyncStatus.serverUnavailable);
          return;
        }
      }
      final force = trigger != SyncTrigger.periodicRefresh;

      final now = DateTime.now().toUtc();

      final tasks = registry.tasks.where((task) {
        if (force) return true;

        final lastSync = _lastTaskSync[task.id];

        if (lastSync == null) return true;

        return !now.isBefore(lastSync.add(task.refreshInterval));
      }).toList();

      if (tasks.isEmpty) return;

      cubit.startSync(tasks.length);

      var hasFailures = false;

      for (final task in tasks) {
        if (!_isActive(generation, scope) || cancelToken.isCancelled) {
          return;
        }

        try {
          await task.execute(scope, cancelToken);

          if (!_isActive(generation, scope)) return;

          _lastTaskSync[task.id] = DateTime.now().toUtc();

          cubit.taskCompleted();
        } on DioException catch (error) {
          if (!_isActive(generation, scope) || CancelToken.isCancel(error)) {
            return;
          }

          final statusCode = error.response?.statusCode;

          if (statusCode == 401) {
            _failures++;

            cubit.updateStatus(SyncStatus.serverUnavailable);

            return;
          }

          if (_isServerUnavailable(error)) {
            _failures++;

            cubit.updateStatus(SyncStatus.serverUnavailable);

            return;
          }

          hasFailures = true;
          cubit.taskFailed();
        } catch (_) {
          if (!_isActive(generation, scope)) return;

          hasFailures = true;
          cubit.taskFailed();
        }
      }

      if (!_isActive(generation, scope)) return;

      if (hasFailures) {
        _failures++;
      } else {
        _failures = 0;
      }

      cubit.finishSync();
    } catch (_) {
      if (!_isActive(generation, scope)) return;

      _failures++;

      cubit.updateStatus(SyncStatus.failed);
    } finally {
      _running = false;

      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }

      if (_started && _foreground && !_sessionBlocked) {
        if (_pending) {
          _pending = false;

          unawaited(requestSync(SyncTrigger.manualRefresh));
        } else {
          _scheduleNext();
        }
      }
    }
  }

  bool _isActive(int generation, CacheScope scope) {
    return _started &&
        _foreground &&
        generation == _generation &&
        _activeScope == scope &&
        scope.isCurrentSession;
  }

  bool _isServerUnavailable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;

      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;

        return status == 502 || status == 503 || status == 504;

      default:
        return false;
    }
  }

  Duration _nextDelay() {
    if (_failures == 0) {
      return const Duration(minutes: 1);
    }

    final exponent = _failures.clamp(1, 5).toInt();

    final seconds = (5 * (1 << exponent)).clamp(10, 120).toInt();

    return Duration(seconds: seconds);
  }

  void _scheduleNext() {
    _timer?.cancel();

    if (!_started || !_foreground || _sessionBlocked || _activeScope == null) {
      return;
    }

    _timer = Timer(_nextDelay(), () {
      unawaited(requestSync(SyncTrigger.periodicRefresh));
    });
  }

  void resumeAfterAuthentication() {
    if (!_started) return;

    _sessionBlocked = false;
    _failures = 0;

    unawaited(requestSync(SyncTrigger.sessionChanged));
  }

  void _cancelCurrentSync() {
    _timer?.cancel();

    final token = _cancelToken;

    if (token != null && !token.isCancelled) {
      token.cancel('Sync interrupted');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;

      unawaited(requestSync(SyncTrigger.appResumed));

      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      _generation++;
      _pending = false;

      _cancelCurrentSync();
    }
  }

  Future<void> dispose() async {
    _started = false;
    _generation++;
    _pending = false;

    _cancelCurrentSync();

    WidgetsBinding.instance.removeObserver(this);

    await _connectionSubscription?.cancel();

    _connectionSubscription = null;
    _activeScope = null;

    _lastTaskSync.clear();
  }
}
