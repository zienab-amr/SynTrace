import 'package:equatable/equatable.dart';
import 'package:syntrace/core/services/current_user_service.dart';

class CacheScope extends Equatable {
  final String tenantId;
  final String userId;

  const CacheScope({required this.tenantId, required this.userId});

  static CacheScope? fromCurrentUser() {
    final user = CurrentUserService.instance.user;

    if (user == null) return null;

    final tenantId = user.tenantId?.trim();
    final userId = user.id.trim();

    if (tenantId == null || tenantId.isEmpty || userId.isEmpty) {
      return null;
    }

    return CacheScope(tenantId: tenantId, userId: userId);
  }

  bool get isCurrentSession {
    return this == fromCurrentUser();
  }

  @override
  List<Object?> get props => [tenantId, userId];
}
