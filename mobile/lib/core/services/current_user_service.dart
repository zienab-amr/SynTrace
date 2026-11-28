import 'dart:async';
import 'package:flutter/widgets.dart';
import 'dart:convert';
import 'package:syntrace/features/auth/data/models/auth_models.dart';
import 'package:flutter/foundation.dart';

import 'package:syntrace/core/cache/cache_operation_lock.dart';
import 'package:syntrace/core/cache/cache_encryption_service.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_service.dart';
import 'package:syntrace/core/cache/cache_session.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/core/sync/services/sync_runtime.dart';

class CurrentUserService with WidgetsBindingObserver {
  CurrentUserService._();
  Timer? _expiryTimer;
  bool _observing = false;

  Future<void> enforceDeadline() async {
    final generation = _session.generation;
    if (_session.isBlocked) return;
    DateTime? deadline;
    try {
      deadline = await CacheOperationLock.instance.run(() async {
        if (_session.generation != generation || _session.isBlocked) {
          return null;
        }
        return _storage.offlineDeadline();
      });
    } catch (_) {
      // Unreadable credentials cannot extend the offline grace period.
    }
    if (_session.generation != generation || _session.isBlocked) return;
    if (deadline == null || !DateTime.now().toUtc().isBefore(deadline)) {
      try {
        await clearUser(expectedGeneration: generation);
      } catch (_) {
        // clearUser invalidates the in-memory session before disk cleanup.
        debugPrint('Local session cleanup failed.');
      }
    }
  }

  void _watchDeadline() {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(enforceDeadline());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(enforceDeadline());
  }

  static final CurrentUserService instance = CurrentUserService._();

  final ValueNotifier<UserModel?> _userNotifier = ValueNotifier<UserModel?>(
    null,
  );

  ValueNotifier<UserModel?> get userNotifier => _userNotifier;

  UserModel? get user => _userNotifier.value;

  final _storage = SecureStorageService.instance;
  final _session = CacheSession.instance;

  Future<void> setUser(UserModel user) async {
    if (_session.isBlocked ||
        _userNotifier.value?.id != user.id ||
        _userNotifier.value?.tenantId != user.tenantId) {
      throw StateError('Session changed.');
    }
    await _persistUser(user);
  }

  Future<void> establishSession(
    UserModel user,
    AuthResponse response, {
    required int expectedGeneration,
    bool onboarding = false,
  }) async {
    if (_session.generation != expectedGeneration) {
      throw StateError('Session changed.');
    }
    final clearing = clearUser();
    final generation = _session.generation;
    await clearing;
    await CacheOperationLock.instance.run(() async {
      if (_session.generation != generation) {
        throw StateError('Session changed.');
      }
      await _storage.saveTokenPair(
        response.accessToken,
        response.refreshToken,
        verifiedAt: DateTime.now().toUtc(),
        refreshExpiresAt: response.refreshTokenExpiration,
      );
      await _storage.clearRotationPending();
      await _storage.saveUserId(user.id);
      await _storage.saveTenantId(user.tenantId!);
      if (onboarding) await _storage.saveOnboardingCompleted(false);
    });
    if (_session.generation != generation) throw StateError('Session changed.');
    await _persistUser(user);
  }

  Future<void> _persistUser(UserModel user) async {
    final tenantId = user.tenantId?.trim();

    if (user.id.trim().isEmpty || tenantId == null || tenantId.isEmpty) {
      throw StateError('Invalid account identity.');
    }

    final previous = _userNotifier.value;

    final accountChanged =
        previous?.id != user.id ||
        previous?.tenantId != user.tenantId ||
        previous?.role != user.role ||
        !listEquals(previous?.roleNames, user.roleNames) ||
        _session.isBlocked;

    if (accountChanged) {
      _session.invalidate();
      _userNotifier.value = null;

      SyncRuntime.instance.onSessionChanged();
    }

    final generation = _session.generation;
    await CacheOperationLock.instance.run(() async {
      if (_session.generation != generation) {
        throw StateError('Session changed.');
      }
      if (accountChanged && previous != null) {
        await _clearCache(
          CacheScope(tenantId: previous.tenantId ?? '', userId: previous.id),
        );
      }

      await _storage.saveUserId(user.id);
      await _storage.saveUserName(user.name);
      await _storage.saveUserEmail(user.email);
      await _storage.saveUserRole(user.role.name);
      await _storage.saveRoleNames(user.roleNames);
      await _storage.saveTenantId(tenantId);

      await _storage.savePhoneNumber(user.phoneNumber);
      await _storage.saveAvatarUrl(user.avatarUrl);

      final companyName = user.companyName;

      if (companyName != null && companyName.trim().isNotEmpty) {
        await _storage.saveCompanyName(companyName);
      } else {
        await _storage.deleteCompanyName();
      }

      if (_session.generation != generation) {
        throw StateError('Session changed.');
      }
      if (accountChanged) {
        _session.activate();
      }

      _userNotifier.value = user;
      _watchDeadline();

      SyncRuntime.instance.onSessionChanged();
    });
  }

  Future<void> updateUser(UserModel user) {
    return setUser(user);
  }

  Future<void> clearUser({int? expectedGeneration}) async {
    if (expectedGeneration != null &&
        _session.generation != expectedGeneration) {
      return;
    }
    _expiryTimer?.cancel();
    final scope = CacheScope.fromCurrentUser();

    _session.invalidate();

    _userNotifier.value = null;

    SyncRuntime.instance.onSessionChanged();

    await CacheOperationLock.instance.run(() async {
      try {
        // During a failed startup restore the in-memory user may be null.
        // Read the persisted account while holding the same operation lock.
        var cleanupScope = scope;
        if (cleanupScope == null) {
          final tenantId = (await _storage.getTenantId())?.trim();
          final userId = (await _storage.getUserId())?.trim();
          if (tenantId != null &&
              tenantId.isNotEmpty &&
              userId != null &&
              userId.isNotEmpty) {
            cleanupScope = CacheScope(tenantId: tenantId, userId: userId);
          }
        }
        if (cleanupScope != null) {
          await _clearCache(cleanupScope);
        }
      } finally {
        await _storage.clearAuthData();
      }
    });
  }

  Future<void> _clearCache(CacheScope scope) async {
    final cache = CacheService.instance;

    if (!cache.isInitialized) {
      await CacheEncryptionService.instance.deleteKey(scope);
      return;
    }

    await cache.repository.clearAccount(scope);
  }

  Future<void> loadFromStorage() async {
    final generation = _session.generation;
    if (!_session.isBlocked || user != null) return;
    try {
      final restoredUser = await CacheOperationLock.instance.run<UserModel?>(
        () async {
          if (_session.generation != generation || !_session.isBlocked) {
            return null;
          }
          if (await _storage.hasPendingRotation()) return null;

          final token = await _storage.getToken();
          final userId = await _storage.getUserId();
          final tenantId = await _storage.getTenantId();
          final refresh = await _storage.getRefreshToken();
          if (token == null ||
              token.isEmpty ||
              userId == null ||
              userId.trim().isEmpty ||
              tenantId == null ||
              tenantId.trim().isEmpty ||
              refresh == null ||
              refresh.isEmpty) {
            return null;
          }

          final roleNames = await _storage.getRoleNames();
          final claims =
              jsonDecode(
                    utf8.decode(
                      base64Url.decode(
                        base64Url.normalize(token.split('.')[1]),
                      ),
                    ),
                  )
                  as Map<String, dynamic>;
          final deadline = await _storage.offlineDeadline();
          final identity = AuthResponse(
            accessToken: token,
            refreshToken: refresh,
          ).extractUser();
          if (claims['exp'] is! num ||
              deadline == null ||
              !DateTime.now().toUtc().isBefore(deadline) ||
              identity == null ||
              identity.id != userId ||
              identity.tenantId != tenantId ||
              !listEquals(identity.roleNames, roleNames)) {
            return null;
          }

          return UserModel(
            id: userId,
            name: await _storage.getUserName() ?? identity.name,
            email: await _storage.getUserEmail() ?? identity.email,
            role: identity.role,
            roleNames: roleNames,
            tenantId: tenantId,
            companyName: await _storage.getCompanyName(),
            phoneNumber: await _storage.getPhoneNumber(),
            avatarUrl: await _storage.getAvatarUrl(),
          );
        },
      );
      // Never restore a snapshot over a newer login/logout.
      if (_session.generation != generation || !_session.isBlocked) return;
      if (restoredUser == null) {
        await clearUser(expectedGeneration: generation);
        return;
      }

      _session.activate();
      _userNotifier.value = restoredUser;
      _watchDeadline();
      SyncRuntime.instance.onSessionChanged();
    } catch (_) {
      if (_session.generation == generation) {
        try {
          await clearUser(expectedGeneration: generation);
        } catch (_) {
          debugPrint('Local session cleanup failed.');
        }
      }
      debugPrint('Failed to restore local session.');
    }
  }
}
