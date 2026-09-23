import 'package:go_router/go_router.dart';
import 'package:syntrace/features/auth/presentation/screens/login_screen.dart';
import 'package:syntrace/features/auth/presentation/screens/signup_screen.dart';
import 'package:syntrace/features/chat/presentation/screens/chat_screen.dart';
import 'package:syntrace/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:syntrace/features/graph/presentation/screens/graph_screen.dart';
import 'package:syntrace/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:syntrace/features/profile/presentation/screens/profile_screen.dart';
import 'package:syntrace/features/reports/presentation/screens/reports_screen.dart';
import 'package:syntrace/features/settings/presentation/screens/settings_screen.dart';
import 'package:syntrace/features/splash/presentation/screens/splash_screen.dart';
import 'package:syntrace/shared/widgets/app_shell.dart';
import 'routes.dart';

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    // Splash
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),

    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.chat,
          builder: (context, state) => const ChatScreen(),
        ),
        GoRoute(
          path: AppRoutes.graph,
          builder: (context, state) => const GraphScreen(),
        ),
        
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const  SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.reports,
          builder: (context, state) => const  ReportsScreen(),
        ),

        GoRoute(
          path: AppRoutes.notifications,
          builder: (context, state) => const  NotificationsScreen(),
        ),
        GoRoute(
           path: AppRoutes.login,
           builder: (context, state) => const LoginScreen(),
           ),
           GoRoute(
           path: AppRoutes.signup,
           builder: (context, state) => const SignupScreen(),
           ),
      ],
    ),
  ],
);

class Profile {
  const Profile();
}