import 'package:dio/dio.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/sync/services/connectivity_service.dart';
import 'models/project_client_model.dart';
import 'cache/clients_local_data_source.dart';

class ProjectClientsRepository {
  final ApiClient _apiClient;
  final _local = ClientsLocalDataSource();
  static Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  ProjectClientsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  CacheSessionGuard _guard({bool mutation = false}) {
    final scope = CacheScope.fromCurrentUser();
    if (scope == null ||
        (mutation && CurrentUserService.instance.user?.isAdmin != true)) {
      throw StateError('Operation not permitted.');
    }
    return CacheSessionGuard.capture(scope);
  }

  Options _options(CacheSessionGuard guard) => Options(
    extra: {'auth_generation': guard.generation, 'allow_retry': false},
  );

  Future<List<ProjectClientModel>> getClients({CancelToken? cancelToken}) {
    final guard = _guard();
    return _serial(() => _refresh(guard, cancelToken));
  }

  Future<void> syncClients(CacheScope scope, {CancelToken? cancelToken}) {
    final guard = CacheSessionGuard.capture(scope);
    return _serial(() async {
      await _refresh(guard, cancelToken);
    });
  }

  Future<List<ProjectClientModel>> _refresh(
    CacheSessionGuard guard,
    CancelToken? cancelToken,
  ) async {
    guard.ensureValid();
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    try {
      final response = await _apiClient.get(
        '/Client',
        options: _options(guard),
        cancelToken: cancelToken,
      );
      guard.ensureValid();
      _ensureSuccess(response);
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Expected a list of clients.');
      }
      final clients = data.map(_parse).toList();
      final ids = <String>{};
      if (clients.any((client) => !ids.add(client.id))) {
        throw const FormatException('Duplicate client ID.');
      }
      clients.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      await _local.save(guard, clients);
      guard.ensureValid();
      return List.unmodifiable(clients);
    } on DioException catch (error) {
      if (guard.isValid &&
          const [401, 403].contains(error.response?.statusCode)) {
        await _local.invalidate(guard.scope);
      }
      rethrow;
    }
  }

  Future<ProjectClientModel> getClientById(
    String clientId, {
    CancelToken? cancelToken,
  }) async {
    final guard = _guard();
    final response = await _apiClient.get(
      _path(clientId),
      options: _options(guard),
      cancelToken: cancelToken,
    );
    guard.ensureValid();
    _ensureSuccess(response);
    return _parse(response.data, expectedId: clientId.trim());
  }

  Future<ProjectClientModel> createClient({
    required String name,
    String? email,
    String? phoneNumber,
    ClientStatus status = ClientStatus.active,
    CancelToken? cancelToken,
  }) => _write(
    name: name,
    email: email,
    phoneNumber: phoneNumber,
    status: status,
    cancelToken: cancelToken,
  );

  Future<ProjectClientModel> updateClient({
    required String clientId,
    required String name,
    required ClientStatus status,
    String? email,
    String? phoneNumber,
    CancelToken? cancelToken,
  }) => _write(
    clientId: clientId,
    name: name,
    email: email,
    phoneNumber: phoneNumber,
    status: status,
    cancelToken: cancelToken,
  );

  Future<ProjectClientModel> _write({
    String? clientId,
    required String name,
    required ClientStatus status,
    String? email,
    String? phoneNumber,
    CancelToken? cancelToken,
  }) async {
    final guard = _guard(mutation: true);
    final body = _body(name, email, phoneNumber, status);
    final path = clientId == null ? '/Client' : _path(clientId);
    if (!await ConnectivityService().hasNetworkConnection()) {
      throw StateError('Connection required.');
    }
    guard.ensureValid();
    return _serial(() async {
      guard.ensureValid();
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      await _local.invalidate(guard.scope);
      guard.ensureValid();
      final response = clientId == null
          ? await _apiClient.post(
              path,
              data: body,
              options: _options(guard),
              cancelToken: cancelToken,
            )
          : await _apiClient.put(
              path,
              data: body,
              options: _options(guard),
              cancelToken: cancelToken,
            );
      guard.ensureValid();
      _ensureSuccess(response);
      final client = _parse(response.data, expectedId: clientId?.trim());
      return client;
    });
  }

  String _path(String id) {
    final value = id.trim();
    if (value.isEmpty || value.length > 450 || value == '.' || value == '..') {
      throw ArgumentError('Invalid client ID.');
    }
    return '/Client/${Uri.encodeComponent(value)}';
  }

  Map<String, dynamic> _body(
    String name,
    String? email,
    String? phone,
    ClientStatus status,
  ) {
    final normalizedName = name.trim();
    final normalizedEmail = _optional(email);
    final normalizedPhone = _optional(phone);
    if (normalizedName.isEmpty ||
        normalizedName.length > 200 ||
        (normalizedEmail != null &&
            (normalizedEmail.length > 254 ||
                !RegExp(
                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                ).hasMatch(normalizedEmail))) ||
        (normalizedPhone?.length ?? 0) > 50) {
      throw ArgumentError('Invalid client information.');
    }
    return {
      'clientName': normalizedName,
      'email': normalizedEmail,
      'phoneNumber': normalizedPhone,
      'status': status.index,
    };
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  ProjectClientModel _parse(Object? data, {String? expectedId}) {
    if (data is! Map) throw const FormatException('Invalid client response.');
    final client = ProjectClientModel.fromJson(Map<String, dynamic>.from(data));
    if (expectedId != null && client.id != expectedId) {
      throw const FormatException('Client ID mismatch.');
    }
    return client;
  }

  void _ensureSuccess(Response response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }
}
