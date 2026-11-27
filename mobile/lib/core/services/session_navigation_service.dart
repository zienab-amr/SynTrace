import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/cache/cache_session.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';

class SessionNavigationService {
  SessionNavigationService._();

  static Future<String> resolveDestination() async {
    final storage = SecureStorageService.instance;
    final session = CacheSession.instance;
    final generation = session.generation;
    final user = CurrentUserService.instance.user;

    final isLoggedIn = await storage.isLoggedIn();

    if (session.isBlocked ||
        session.generation != generation ||
        !isLoggedIn ||
        user == null ||
        user.id.trim().isEmpty ||
        user.tenantId == null ||
        user.tenantId!.trim().isEmpty) {
      return AppRoutes.login;
    }

    final onboardingCompleted = await storage.getOnboardingCompleted();

    if (session.isBlocked || session.generation != generation) {
      return AppRoutes.login;
    }

    if (onboardingCompleted != true) {
      return AppRoutes.onboarding;
    }

    return AppRoutes.dashboard;
  }
}
