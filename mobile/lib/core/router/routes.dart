class AppRoutes {
  AppRoutes._();

  // Auth
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verifyOtp = '/verify-otp';
  static const String onboarding = '/onboarding';

  // Main
  static const String dashboard = '/dashboard';
  static const String chat = '/chat';
  static const String graph = '/graph';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String reports = '/reports';
  static const String notifications = '/notifications';
  static const String projects = '/projects';
  static const String tasks = '/tasks';

  static String projectDetailsById(String id) => '/projects/$id';
}