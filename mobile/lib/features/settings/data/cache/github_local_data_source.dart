import 'package:syntrace/core/cache/cache_entry.dart';
import 'package:syntrace/core/cache/cache_policy.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_service.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';

import '../models/github_model.dart';

class GitHubLocalDataSource {
  final _cache = CacheService.instance;

  static const _companyType = 'github_company';
  static const _employeeType = 'github_employee';
  static const _projectType = 'github_project';

  static const _policy = CachePolicy(
    refreshAfter: Duration(minutes: 5),
    maxOfflineAge: Duration(hours: 24),
  );

  Future<CacheEntry<GitHubCompanyStatus>?> readCompany(CacheScope scope) {
    return _read(
      scope: scope,
      type: _companyType,
      key: 'status',
      decode: GitHubCompanyStatus.fromJson,
    );
  }

  Future<void> saveCompany({
    required CacheSessionGuard guard,
    required GitHubCompanyStatus status,
  }) {
    return _save(
      guard: guard,
      type: _companyType,
      key: 'status',
      data: status,
      encode: (value) => value.toJson(),
    );
  }

  Future<CacheEntry<GitHubEmployeeStatus>?> readEmployee(CacheScope scope) {
    return _read(
      scope: scope,
      type: _employeeType,
      key: 'status',
      decode: GitHubEmployeeStatus.fromJson,
    );
  }

  Future<void> saveEmployee({
    required CacheSessionGuard guard,
    required GitHubEmployeeStatus status,
  }) {
    return _save(
      guard: guard,
      type: _employeeType,
      key: 'status',
      data: status,
      encode: (value) => value.toJson(),
    );
  }

  Future<CacheEntry<GitHubProjectStatus>?> readProject({
    required CacheScope scope,
    required String projectId,
  }) {
    return _read(
      scope: scope,
      type: _projectType,
      key: projectId,
      decode: GitHubProjectStatus.fromJson,
    );
  }

  Future<void> saveProject({
    required CacheSessionGuard guard,
    required GitHubProjectStatus status,
  }) {
    return _save(
      guard: guard,
      type: _projectType,
      key: status.projectId,
      data: status,
      encode: (value) => value.toJson(),
    );
  }

  Future<CacheEntry<T>?> _read<T>({
    required CacheScope scope,
    required String type,
    required String key,
    required T Function(Map<String, dynamic>) decode,
  }) async {
    if (!_cache.isInitialized) return null;

    return _cache.repository.read<T>(
      scope: scope,
      resourceType: type,
      resourceKey: key,
      policy: _policy,
      decode: (json) {
        if (json is! Map) {
          throw const FormatException('Invalid saved integration data.');
        }

        return decode(Map<String, dynamic>.from(json));
      },
    );
  }

  Future<void> _save<T>({
    required CacheSessionGuard guard,
    required String type,
    required String key,
    required T data,
    required Map<String, dynamic> Function(T) encode,
  }) async {
    if (!_cache.isInitialized) return;

    guard.ensureValid();

    await _cache.repository.save<T>(
      scope: guard.scope,
      resourceType: type,
      resourceKey: key,
      data: data,
      policy: _policy,
      guard: guard,
      encode: encode,
    );
  }

  Future<void> invalidateCompany(CacheScope scope) {
    return _invalidate(scope, _companyType, 'status');
  }

  Future<void> invalidateEmployee(CacheScope scope) {
    return _invalidate(scope, _employeeType, 'status');
  }

  Future<void> invalidateProject({
    required CacheScope scope,
    required String projectId,
  }) {
    return _invalidate(scope, _projectType, projectId);
  }

  Future<void> _invalidate(CacheScope scope, String type, String key) async {
    if (!_cache.isInitialized) return;

    await _cache.repository.invalidate(
      scope: scope,
      resourceType: type,
      resourceKey: key,
    );
  }
}
