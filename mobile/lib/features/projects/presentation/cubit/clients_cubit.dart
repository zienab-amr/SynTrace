import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import '../../data/cache/clients_local_data_source.dart';
import '../../data/models/project_client_model.dart';
import '../../data/project_clients_repository.dart';
import 'clients_state.dart';

class ClientsCubit extends Cubit<ClientsState> {
  final repository = ProjectClientsRepository();
  final _local = ClientsLocalDataSource();
  CacheSessionGuard? _guard;
  StreamSubscription<dynamic>? _subscription;
  Timer? _expiry;
  bool _busy = false;
  bool _allowCacheUpdates = true;
  ClientsCubit() : super(const ClientsState()) {
    CurrentUserService.instance.userNotifier.addListener(_sessionChanged);
  }
  bool _valid(CacheSessionGuard g) =>
      !isClosed && identical(g, _guard) && g.isValid;
  void _sessionChanged() {
    if (_guard?.isValid == true) return;
    _guard = null;
    _expiry?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _busy = false;
    if (!isClosed) {
      emit(const ClientsState(error: 'Session changed. Reopen this page.'));
    }
  }

  void _publish(
    CacheSessionGuard g,
    List<ProjectClientModel> items,
    DateTime? expires, {
    required bool cached,
  }) {
    if (!_valid(g)) return;
    _expiry?.cancel();
    if (expires != null) {
      final remaining = expires.difference(DateTime.now().toUtc());
      if (remaining <= Duration.zero) {
        emit(const ClientsState(error: 'Saved clients have expired.'));
        return;
      }
      _expiry = Timer(remaining, () {
        if (_valid(g)) {
          emit(const ClientsState(error: 'Saved clients have expired.'));
        }
      });
    }
    emit(
      ClientsState(
        clients: items,
        cached: cached,
        loading: _busy,
        expiresAt: expires,
      ),
    );
  }

  Future<void> load() async {
    if (isClosed || _busy) return;
    final scope = CacheScope.fromCurrentUser();
    if (scope == null) return;
    try {
      _guard ??= CacheSessionGuard.capture(scope);
    } catch (_) {
      return;
    }
    final g = _guard!;
    if (!_valid(g)) return;
    _busy = true;
    _allowCacheUpdates = true;
    emit(
      ClientsState(
        clients: state.clients,
        loading: true,
        expiresAt: state.expiresAt,
      ),
    );
    try {
      final saved = await _local.read(scope);
      if (!_valid(g)) return;
      if (saved != null) _publish(g, saved.data, saved.expiresAt, cached: true);
      _subscription ??= _local.watch(scope).listen((entry) {
        if (!_valid(g) || !_allowCacheUpdates) return;
        if (entry == null) {
          _expiry?.cancel();
          emit(
            ClientsState(loading: _busy, error: 'Client data needs refresh.'),
          );
        } else {
          // A delayed cache notification for the same verified response
          // must not disable edits after a successful network refresh.
          if (!_busy &&
              !state.cached &&
              state.error == null &&
              state.expiresAt?.isAfter(DateTime.now().toUtc()) == true &&
              entry.expiresAt?.isAfter(DateTime.now().toUtc()) == true &&
              listEquals(state.clients, entry.data)) {
            return;
          }
          _publish(g, entry.data, entry.expiresAt, cached: true);
        }
      }, onError: (Object _) {});
      final items = await repository.getClients();
      if (!_valid(g)) return;
      _busy = false;
      _publish(
        g,
        items,
        DateTime.now().toUtc().add(const Duration(hours: 24)),
        cached: false,
      );
    } catch (e) {
      if (!_valid(g)) return;
      final temporary =
          e is DioException &&
          (const [502, 503, 504].contains(e.response?.statusCode) ||
              const [
                DioExceptionType.connectionError,
                DioExceptionType.connectionTimeout,
                DioExceptionType.receiveTimeout,
                DioExceptionType.sendTimeout,
              ].contains(e.type));
      if (!temporary) {
        _allowCacheUpdates = false;
        _expiry?.cancel();
      }
      emit(
        ClientsState(
          clients: temporary ? state.clients : null,
          expiresAt: temporary ? state.expiresAt : null,
          error: 'Unable to refresh clients.',
        ),
      );
    } finally {
      if (_valid(g)) _busy = false;
    }
  }

  @override
  Future<void> close() async {
    CurrentUserService.instance.userNotifier.removeListener(_sessionChanged);
    _guard = null;
    _expiry?.cancel();
    await _subscription?.cancel();
    await super.close();
  }
}
