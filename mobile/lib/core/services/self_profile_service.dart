import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/services/current_user_service.dart';

class SelfProfileDetails {
  final UserModel user;
  final String firstName;
  final String lastName;

  const SelfProfileDetails({
    required this.user,
    required this.firstName,
    required this.lastName,
  });
}

/// Reads and updates only the authenticated employee's own profile.
class SelfProfileService {
  final _session = CurrentUserService.instance;

  CacheSessionGuard _capture() {
    final scope = CacheScope.fromCurrentUser();
    if (scope == null) throw StateError('Sign in to continue.');
    return CacheSessionGuard.capture(scope);
  }

  Options _options(CacheSessionGuard guard) => Options(
    extra: {'auth_generation': guard.generation, 'allow_retry': false},
  );

  Future<SelfProfileDetails> refresh() async {
    final guard = _capture();
    final response = await ApiClient.instance.get(
      ApiEndpoints.myProfile,
      options: _options(guard),
    );
    return _accept(response, guard);
  }

  Future<SelfProfileDetails> update({
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    final first = firstName.trim();
    final last = lastName.trim();
    final phone = phoneNumber.trim();
    if (first.isEmpty ||
        last.isEmpty ||
        first.length > 100 ||
        last.length > 100 ||
        phone.length > 40) {
      throw ArgumentError('Check your profile details.');
    }
    final guard = _capture();
    final response = await ApiClient.instance.put(
      ApiEndpoints.myProfile,
      data: {
        'firstName': first,
        'lastName': last,
        'phoneNumber': phone.isEmpty ? null : phone,
      },
      options: _options(guard),
    );
    return _accept(response, guard);
  }

  Future<SelfProfileDetails> _accept(
    Response response,
    CacheSessionGuard guard,
  ) async {
    guard.ensureValid();
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
    final raw = response.data;
    final user = _session.user;
    if (user == null ||
        raw is! Map ||
        raw['id'] != user.id ||
        raw['companyId'] != user.tenantId) {
      throw const FormatException('Invalid profile identity.');
    }
    final first = raw['firstName'];
    final last = raw['lastName'];
    final email = raw['email'];
    final phone = raw['phoneNumber'];
    final roles = raw['roles'];
    if (first is! String ||
        last is! String ||
        (email != null && email is! String) ||
        (phone != null && phone is! String) ||
        roles is! List ||
        roles.any((r) => r is! Map || r['name'] is! String)) {
      throw const FormatException('Invalid profile response.');
    }
    final names = UserRole.readNames(roles.map((r) => (r as Map)['name']));
    // Never change locally authorized roles independently of the JWT.
    if (!listEquals(names, user.roleNames)) {
      throw StateError('Your roles have changed. Sign in again.');
    }
    final updated = UserModel(
      id: user.id,
      name: '$first $last'.trim(),
      email: (email as String?) ?? user.email,
      role: user.role,
      roleNames: user.roleNames,
      tenantId: user.tenantId,
      companyName: user.companyName,
      avatarUrl: user.avatarUrl,
      phoneNumber: phone as String?,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
    guard.ensureValid();
    await _session.setUser(updated);
    guard.ensureValid();
    return SelfProfileDetails(user: updated, firstName: first, lastName: last);
  }
}
