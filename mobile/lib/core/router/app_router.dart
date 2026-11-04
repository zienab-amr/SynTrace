import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/features/auth/presentation/cubit/login_cubit.dart';
import 'package:syntrace/features/auth/presentation/screens/login_screen.dart';
import 'package:syntrace/features/auth/presentation/screens/otp_screen.dart';
import 'package:syntrace/features/auth/presentation/screens/signup_screen.dart';
import 'package:syntrace/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:syntrace/features/chat/presentation/screens/chat_screen.dart';
import 'package:syntrace/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:syntrace/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:syntrace/features/developers/presentation/cubit/developers_cubit.dart';
import 'package:syntrace/features/developers/presentation/screens/developers_screen.dart';
import 'package:syntrace/features/graph/presentation/screens/graph_screen.dart';
import 'package:syntrace/features/meetings/presentation/cubit/meeting_notes_cubit.dart';
import 'package:syntrace/features/meetings/presentation/screens/meeting_notes_screen.dart';
import 'package:syntrace/features/notifications/presentation/cubit/jira_events_cubit.dart';
import 'package:syntrace/features/notifications/presentation/screens/jira_activity_screen.dart';
import 'package:syntrace/features/profile/presentation/screens/employee_profile_screen.dart';
import 'package:syntrace/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:syntrace/features/projects/presentation/screens/project_details_screen.dart';
import 'package:syntrace/features/projects/presentation/screens/projects_screen.dart';
import 'package:syntrace/features/role/presentation/cubit/roles_cubit.dart';
import 'package:syntrace/features/role/presentation/screens/roles_screen.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:syntrace/features/settings/presentation/screens/jira_callback_screen.dart';
import 'package:syntrace/features/settings/presentation/screens/settings_screen.dart';
import 'package:syntrace/features/splash/presentation/screens/splash_screen.dart';
import 'package:syntrace/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:syntrace/features/onboarding/presentation/screens/onboarding_wizard_screen.dart';
import 'package:syntrace/shared/widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    // ═══ Splash ═══
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),

    // ═══ Auth ═══
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => BlocProvider(
        create: (context) => LoginCubit(),
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => BlocProvider(
        create: (context) => LoginCubit(),
        child: const SignupScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.verifyOtp,
      builder: (context, state) {
        final email = state.extra as String? ?? '';
        return BlocProvider(
          create: (context) => LoginCubit(),
          child: OtpScreen(email: email),
        );
      },
    ),

    // ═══ Onboarding ═══
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => BlocProvider(
        create: (context) => OnboardingCubit(),
        child: const OnboardingWizardScreen(),
      ),
    ),

    // ═══ Main App (With Sidebar) ═══
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        // Dashboard
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (context, state) => BlocProvider(
            create: (context) => DashboardCubit(),
            child: const DashboardScreen(),
          ),
        ),

        // Chat
        GoRoute(
          path: AppRoutes.chat,
          builder: (context, state) => BlocProvider(
            create: (context) => ChatCubit(),
            child: const ChatScreen(),
          ),
        ),

        // Graph
        // Graph
        GoRoute(
          path: AppRoutes.graph,
          builder: (context, state) => const GraphScreen(),
        ),

        // Projects
        GoRoute(
          path: AppRoutes.projects,
          builder: (context, state) => BlocProvider(
            create: (context) => ProjectsCubit(),
            child: const ProjectsScreen(),
          ),
        ),

        // Project Details
        GoRoute(
          path: '/projects/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ProjectDetailsScreen(projectId: id);
          },
        ),

        GoRoute(
          path: AppRoutes.developers,
          builder: (context, state) => BlocProvider(
            create: (context) => DevelopersCubit(),
            child: const DevelopersScreen(),
          ),
        ),

        GoRoute(
          path: '/profile/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return EmployeeProfileScreen(employeeId: id);
          },
        ),

        // Meetings
        GoRoute(
          path: AppRoutes.meetings,
          builder: (context, state) => BlocProvider(
            create: (context) => MeetingNotesCubit(),
            child: const MeetingNotesScreen(),
          ),
        ),

        // Activity Feed
        GoRoute(
          path: '/jira-callback',
          builder: (context, state) {
            final status = state.uri.queryParameters['status'] ?? '';
            final pendingId = state.uri.queryParameters['pendingId'];
            return BlocProvider(
              create: (context) => IntegrationsCubit(),
              child: JiraCallbackScreen(status: status, pendingId: pendingId),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.roles,
          builder: (context, state) => BlocProvider(
            create: (context) => RolesCubit(),
            child: const RolesScreen(),
          ),
        ),

        // Settings
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => SettingsCubit()),
              BlocProvider(create: (context) => IntegrationsCubit()),
            ],
            child: const SettingsScreen(),
          ),
        ),
      ],
    ),
  ],
);
