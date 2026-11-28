import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';
import 'package:signalr_netcore/ihub_protocol.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';

import 'signalr_config.dart';
import 'signalr_connection_state.dart';

class SignalRClient {
  SignalRClient({required String url}) {
    _connection = HubConnectionBuilder()
        .withUrl(
          url,
          options: HttpConnectionOptions(
            accessTokenFactory: _getAccessToken,
            headers: MessageHeaders()
              ..setHeaderValue('ngrok-skip-browser-warning', 'true'),
          ),
        )
        .withAutomaticReconnect(retryDelays: SignalRConfig.reconnectDelays)
        .build();

    _registerCallbacks();
    CurrentUserService.instance.userNotifier.addListener(_onSessionChanged);
  }

  late final HubConnection _connection;

  final _stateController = StreamController<SignalRConnectionState>.broadcast();

  SignalRConnectionState _state = SignalRConnectionState.disconnected;

  Future<void>? _startOperation;
  Future<void>? _stopOperation;
  Future<void>? _disposeOperation;

  CacheSessionGuard? _guard;
  bool _disposed = false;
  bool _stopping = false;
  bool _disposing = false;

  SignalRConnectionState get state => _state;

  Stream<SignalRConnectionState> get states => _stateController.stream;

  bool get isConnected =>
      !_disposed &&
      !_disposing &&
      !_stopping &&
      _guard?.isValid == true &&
      _connection.state == HubConnectionState.Connected;

  void _onSessionChanged() {
    if (_guard == null || _guard!.isValid || _disposed || _disposing) return;
    unawaited(_disconnectInvalidSession());
  }

  Future<void> _disconnectInvalidSession() async {
    try {
      await disconnect();
    } catch (_) {
      // Invalid sessions cannot reconnect or provide another user's token.
    }
  }

  Future<String> _getAccessToken() async {
    final guard = _guard;
    if (guard == null || _disposing || _disposed || _stopping) {
      throw StateError('Authentication is required.');
    }
    guard.ensureValid();
    final token = await SecureStorageService.instance.getToken();
    guard.ensureValid();
    if (_disposing || _disposed || _stopping) {
      throw StateError('SignalR connection is closing.');
    }

    if (token == null || token.trim().isEmpty) {
      throw StateError('Authentication is required.');
    }

    return token;
  }

  void _registerCallbacks() {
    _connection.onclose(({error}) {
      _emit(
        error == null || _stopping
            ? SignalRConnectionState.disconnected
            : SignalRConnectionState.failed,
      );
    });

    _connection.onreconnecting(({error}) {
      if (!_stopping && !_disposing && _guard?.isValid == true) {
        _emit(SignalRConnectionState.reconnecting);
      }
    });

    _connection.onreconnected(({connectionId}) {
      if (!_stopping && !_disposing && _guard?.isValid == true) {
        _emit(SignalRConnectionState.connected);
      }
    });
  }

  Future<void> connect() async {
    if (_disposed || _disposing || _stopping) return;

    // A client instance is bound to its first authenticated session.
    // Do not recapture after logout, even if the same user logs in again.
    if (_guard == null) {
      final scope = CacheScope.fromCurrentUser();
      if (scope == null) throw StateError('Authentication is required.');
      _guard = CacheSessionGuard.capture(scope);
    }
    _guard!.ensureValid();

    final existing = _startOperation;

    if (existing != null) {
      await existing;
      return;
    }

    if (_connection.state != HubConnectionState.Disconnected) {
      return;
    }

    final operation = _start();
    _startOperation = operation;

    try {
      await operation;
    } finally {
      _startOperation = null;
    }
  }

  Future<void> _start() async {
    _emit(SignalRConnectionState.connecting);

    try {
      await _connection.start();

      if (!_stopping && !_disposing && !_disposed && _guard?.isValid == true) {
        _emit(SignalRConnectionState.connected);
      }
    } catch (_) {
      if (!_stopping && !_disposing && _guard?.isValid == true) {
        _emit(SignalRConnectionState.failed);
      }

      rethrow;
    }
  }

  void on(String event, void Function(List<Object?>? arguments) handler) {
    if (_disposed || _disposing) return;

    _connection.on(event, handler);
  }

  void off(String event) {
    if (_disposed || _disposing) return;

    _connection.off(event);
  }

  Future<Object?> invoke(
    String method, {
    List<Object> arguments = const [],
  }) async {
    if (_disposed || _disposing || _stopping || !isConnected) {
      throw StateError('SignalR is not connected.');
    }

    final guard = _guard!;
    guard.ensureValid();
    final result = await _connection.invoke(method, args: arguments);
    guard.ensureValid();
    return result;
  }

  Future<void> disconnect() async {
    if (_disposed) return;

    final existing = _stopOperation;

    if (existing != null) {
      await existing;
      return;
    }

    final operation = _stop();
    _stopOperation = operation;

    try {
      await operation;
    } finally {
      _stopOperation = null;
    }
  }

  Future<void> _stop() async {
    _stopping = true;

    _emit(SignalRConnectionState.disconnecting);

    try {
      final pendingStart = _startOperation;

      if (pendingStart != null) {
        try {
          await pendingStart;
        } catch (_) {
          // Continue cleanup after a failed connection.
        }
      }

      await _connection.stop();

      _emit(SignalRConnectionState.disconnected);
    } catch (_) {
      _emit(SignalRConnectionState.failed);
      rethrow;
    } finally {
      _stopping = false;
    }
  }

  void _emit(SignalRConnectionState next) {
    if (_disposed || _stateController.isClosed || _state == next) {
      return;
    }

    _state = next;
    _stateController.add(next);
  }

  Future<void> dispose() {
    return _disposeOperation ??= _dispose();
  }

  Future<void> _dispose() async {
    if (_disposed) return;

    _disposing = true;
    CurrentUserService.instance.userNotifier.removeListener(_onSessionChanged);

    try {
      await disconnect();
    } finally {
      _disposed = true;
      await _stateController.close();
    }
  }
}
