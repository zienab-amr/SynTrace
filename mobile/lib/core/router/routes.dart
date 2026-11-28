class AppRoutes {
  AppRoutes._();

  // Auth
  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String signup = '/signup';
  static const String verifyOtp = '/verify-otp';
  static const String onboarding = '/onboarding';
  static const String workspace = '/workspace';
  static const String intro = '/intro';

  // Main
  static const String dashboard = '/dashboard';
  static const String chat = '/chat';
  static const String graph = '/graph';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String reports = '/reports';
  static const String projects = '/projects';
  static const String tasks = '/tasks';
  static const String meetings = '/meetings';
  static const String jiraCallback = '/jira/callback';
  static const String githubCallback = '/github/callback';

  static const String jiraActivity = '/jira-activity';

  // Roles
  static const String roles = '/roles';

  static const String employees = '/employees';
  static const String addEmployee = '/employees/add';

  static String profileDetailsById(String id) => '/profile/$id';
  static String projectDetailsById(String id) => '/projects/$id';
  static const String createProject = '/projects/create';
  static const String team = '/team';
  static const String developers = '/developers';
}
