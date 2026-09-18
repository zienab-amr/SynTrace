import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/features/auth/presentation/screens/login_screen.dart';
import 'package:syntrace/features/auth/presentation/screens/signup_screen.dart';
import 'package:syntrace/features/chat/presentation/screens/chat_screen.dart';
import 'package:syntrace/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:syntrace/features/graph/presentation/screens/graph_screen.dart';
import 'package:syntrace/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:syntrace/features/profile/presentation/screens/profile_screen.dart';
import 'package:syntrace/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:syntrace/features/projects/presentation/screens/project_details_screen.dart';
import 'package:syntrace/features/projects/presentation/screens/projects_screen.dart';
import 'package:syntrace/features/reports/presentation/screens/reports_screen.dart';
import 'package:syntrace/features/settings/presentation/screens/settings_screen.dart';
import 'package:syntrace/features/splash/presentation/screens/splash_screen.dart';
import 'package:syntrace/shared/widgets/app_shell.dart';
import 'routes.dart';
import 'package:syntrace/features/tasks/presentation/cubit/tasks_cubit.dart';
import 'package:syntrace/features/tasks/presentation/screens/tasks_screen.dart';

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
           GoRoute(
                path: AppRoutes.projects,
                builder: (context, state) => BlocProvider(
                 create: (_) => ProjectsCubit(),
                 child: const ProjectsScreen(),
                 ),
                 routes: [
                     GoRoute(
                        path: ':id',
                        builder: (context, state) {
                        final projectId = state.pathParameters['id'] ?? '';
                        return ProjectDetailsScreen(projectId: projectId);
                      },
                     ),
                   ],
                ),
                GoRoute(
                     path: AppRoutes.tasks,
                     builder: (context, state) => BlocProvider(
                     create: (_) => TasksCubit(),
                     child: const TasksScreen(),
                   ),
                  ),
      ],
    ),
  ],
);

class Profile {
  const Profile();
}