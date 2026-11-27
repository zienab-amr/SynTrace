import 'dart:async';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import 'package:syntrace/core/realtime/signalr_client.dart';
import 'package:syntrace/core/realtime/signalr_config.dart';
import 'package:syntrace/core/realtime/signalr_connection_state.dart';

import 'project_status_model.dart';

class ProjectStatusService {
  ProjectStatusService({required this.projectId, SignalRClient? client})
    : _client = client ?? SignalRClient(url: SignalRConfig.projectStatusUrl) {
    CurrentUserService.instance.userNotifier.addListener(_onSessionChanged);
    _client.on(_statusEvent, _handleStatusEvent);

    _connectionSubscription = _client.states.listen(_handleConnectionState);
  }

  static const String _statusEvent = 'ProjectStatusChanged';
  static const String _watchMethod = 'WatchProject';
  static const String _unwatchMethod = 'UnwatchProject';

  static const List<Duration> _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  final String projectId;
  final SignalRClient _client;
  // The project ID belongs to the session that created this service.
  final CacheSessionGuard? _guard = _captureSession();

  static CacheSessionGuard? _captureSession() {
    final scope = CacheScope.fromCurrentUser();
    if (scope == null) return null;
    try {
      return CacheSessionGuard.capture(scope);
    } catch (_) {
      return null;
    }
  }

  bool get _sessionValid => _guard?.isValid == true;

  void _onSessionChanged() {
    if (_disposed || _sessionValid || !_active) return;
    unawaited(stop());
  }

  final _statusController = StreamController<ProjectStatusModel>.broadcast();

  StreamSubscription<SignalRConnectionState>? _connectionSubscription;

  Future<void> _operations = Future<void>.value();
  Future<void>? _disposeOperation;

  Timer? _retryTimer;

  bool _active = false;
  bool _disposed = false;
  bool _subscribed = false;

  int _retryAttempt = 0;
  int _connectionGeneration = 0;
  int _activationGeneration = 0;

  Stream<ProjectStatusModel> get updates => _statusController.stream;

  Stream<SignalRConnectionState> get connectionStates => _client.states;

  bool get isConnected => _sessionValid && _active && _client.isConnected;

  bool get isSubscribed => _subscribed && isConnected;

  bool _isCurrent(int generation) =>
      !_disposed &&
      _sessionValid &&
      _active &&
      generation == _activationGeneration;

  // Start

  Future<void> start() {
    if (_disposed ||
        !_sessionValid ||
        projectId.trim().isEmpty ||
        projectId.length > 450) {
      return Future<void>.value();
    }

    if (!_active) {
      _active = true;
      _activationGeneration++;
    }

    _cancelRetry();
    _retryAttempt = 0;

    final generation = _activationGeneration;

    return _enqueue(() => _connectAndSubscribe(generation));
  }

  Future<void> _connectAndSubscribe(int generation) async {
    if (!_isCurrent(generation)) return;

    try {
      if (!_client.isConnected) {
        await _client.connect();
      }

      if (!_isCurrent(generation)) return;

      await _subscribe(generation);
    } catch (_) {
      _subscribed = false;
    }

    if (!_isCurrent(generation)) return;

    if (isSubscribed) {
      _resetRetry();
    } else {
      _scheduleRetry();
    }
  }

  // Subscription

  Future<void> _subscribe(int activationGeneration) async {
    if (!_isCurrent(activationGeneration) ||
        !_client.isConnected ||
        _subscribed) {
      return;
    }

    final connectionGeneration = _connectionGeneration;

    try {
      await _client.invoke(_watchMethod, arguments: [projectId]);

      if (_isCurrent(activationGeneration) &&
          connectionGeneration == _connectionGeneration &&
          _client.isConnected) {
        _subscribed = true;
        _resetRetry();
      }
    } catch (_) {
      _subscribed = false;
    }
  }

  // Connection Lifecycle

  void _handleConnectionState(SignalRConnectionState state) {
    if (_disposed) return;

    if (state != SignalRConnectionState.connected) {
      _connectionGeneration++;
      _subscribed = false;
    }

    if (!_active || !_sessionValid) return;

    switch (state) {
      case SignalRConnectionState.connected:
        _cancelRetry();

        final generation = _activationGeneration;

        unawaited(
          _enqueue(() async {
            if (!_isCurrent(generation)) return;

            await _subscribe(generation);

            if (_isCurrent(generation) && !isSubscribed) {
              _scheduleRetry();
            }
          }),
        );

      case SignalRConnectionState.connecting:
      case SignalRConnectionState.reconnecting:
      case SignalRConnectionState.disconnecting:
        _cancelRetry();

      case SignalRConnectionState.disconnected:
      case SignalRConnectionState.failed:
        _scheduleRetry();
    }
  }

  // Retry Policy

  void _scheduleRetry() {
    if (_disposed ||
        !_sessionValid ||
        !_active ||
        isSubscribed ||
        (_retryTimer?.isActive ?? false) ||
        _retryAttempt >= _retryDelays.length) {
      return;
    }

    if (_client.state == SignalRConnectionState.reconnecting ||
        _client.state == SignalRConnectionState.connecting ||
        _client.state == SignalRConnectionState.disconnecting) {
      return;
    }

    final generation = _activationGeneration;
    final delay = _retryDelays[_retryAttempt];

    _retryAttempt++;

    _retryTimer = Timer(delay, () {
      _retryTimer = null;

      if (!_isCurrent(generation)) return;

      unawaited(_enqueue(() => _connectAndSubscribe(generation)));
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _resetRetry() {
    _cancelRetry();
    _retryAttempt = 0;
  }

  // Event Handling

  void _handleStatusEvent(List<Object?>? arguments) {
    if (_disposed ||
        !_sessionValid ||
        !_active ||
        arguments == null ||
        arguments.isEmpty ||
        _statusController.isClosed) {
      return;
    }

    final payload = arguments.first;

    if (payload is! Map) return;

    try {
      final status = ProjectStatusModel.fromJson(
        Map<String, dynamic>.from(payload),
      );

      if (status.projectId != projectId) return;

      _statusController.add(status);
    } catch (_) {
      // Ignore malformed notifications.
      // REST remains the authoritative source.
    }
  }

  // Stop

  Future<void> stop() {
    if (_disposed) return Future<void>.value();

    _active = false;
    _activationGeneration++;

    _resetRetry();

    return _enqueue(_stopConnection);
  }

  Future<void> _stopConnection() async {
    try {
      if (_client.isConnected) {
        try {
          await _client.invoke(_unwatchMethod, arguments: [projectId]);
        } catch (_) {
          // Disconnect removes server subscriptions.
        }
      }
    } finally {
      _subscribed = false;
      _connectionGeneration++;

      try {
        await _client.disconnect();
      } catch (_) {
        // Continue resource cleanup.
      }
    }
  }

  // Serialized Operations

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operations.then((_) => operation());

    _operations = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return next;
  }

  // Dispose

  Future<void> dispose() {
    return _disposeOperation ??= _dispose();
  }

  Future<void> _dispose() async {
    _disposed = true;
    CurrentUserService.instance.userNotifier.removeListener(_onSessionChanged);
    _active = false;
    _activationGeneration++;

    _resetRetry();

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    _client.off(_statusEvent);

    try {
      await _enqueue(_stopConnection);
    } finally {
      try {
        await _client.dispose();
      } finally {
        await _statusController.close();
      }
    }
  }
}
