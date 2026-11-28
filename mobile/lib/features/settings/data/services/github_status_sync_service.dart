import 'package:dio/dio.dart';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';

import '../cache/github_local_data_source.dart';
import '../repositories/github_repository.dart';
import '../models/github_model.dart';

class GitHubStatusSyncService {
  GitHubStatusSyncService._();

  static final instance = GitHubStatusSyncService._();

  final local = GitHubLocalDataSource();

  Future<GitHubCompanyStatus> refreshCompany({
    required CacheScope scope,
    required GitHubRepository repository,
  }) async {
    final guard = CacheSessionGuard.capture(scope);

    try {
      guard.ensureValid();

      final response = await repository.getGitHubCompanyStatus();

      guard.ensureValid();

      final data = _readResponse(response);

      final status = GitHubCompanyStatus.fromJson(data);

      try {
        await local.saveCompany(guard: guard, status: status);
      } catch (_) {
        // A cache failure must not hide valid server data.
      }

      guard.ensureValid();

      return status;
    } on DioException catch (error) {
      if (guard.isValid && _isAccessDenied(error)) {
        await local.invalidateCompany(scope);
      }

      rethrow;
    }
  }

  Future<GitHubEmployeeStatus> refreshEmployee({
    required CacheScope scope,
    required GitHubRepository repository,
  }) async {
    final guard = CacheSessionGuard.capture(scope);

    try {
      guard.ensureValid();

      final response = await repository.getGitHubEmployeeStatus();

      guard.ensureValid();

      final data = _readResponse(response);

      final status = GitHubEmployeeStatus.fromJson(data);

      try {
        await local.saveEmployee(guard: guard, status: status);
      } catch (_) {
        // A cache failure must not hide valid server data.
      }

      guard.ensureValid();

      return status;
    } on DioException catch (error) {
      if (guard.isValid && _isAccessDenied(error)) {
        await local.invalidateEmployee(scope);
      }

      rethrow;
    }
  }

  Map<String, dynamic> _readResponse(Response response) {
    final code = response.statusCode;

    if (code == null || code < 200 || code >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    if (response.data is! Map) {
      throw const FormatException('Invalid GitHub status response.');
    }

    final data = Map<String, dynamic>.from(response.data as Map);

    if (data['connected'] is! bool) {
      throw const FormatException('Missing GitHub connection status.');
    }

    return data;
  }

  bool _isAccessDenied(DioException error) {
    final code = error.response?.statusCode;

    return code == 401 || code == 403;
  }
}
