import 'package:go_router/go_router.dart';
import 'package:syntrace/features/screens/chat/chat_screen.dart';
import 'package:syntrace/features/screens/dashboard/dashboard_screen.dart';
import 'package:syntrace/features/screens/graph_screen/graph_screen.dart';
import 'package:syntrace/features/screens/profile/profile_screen.dart';
import 'package:syntrace/features/screens/splash/splash_screen.dart';
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
          path: AppRoutes.graph,
          builder: (context, state) => const ProfileScreen(),
        ),
        
      ],
    ),
  ],
);

class Profile {
  const Profile();
}