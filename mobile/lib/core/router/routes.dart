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
  static const String projects = '/projects';
  static const String tasks = '/tasks';
  static const String meetings = '/meetings';
  static const String jiraCallback = '/settings/jira-callback';
    
  static const String jiraActivity = '/jira-activity';


  // Roles
  static const String roles = '/roles';

  static const String employees = '/employees';
  static const String addEmployee = '/employees/add';

  static String profileDetailsById(String id) => '/profile/$id';
  static String projectDetailsById(String id) => '/projects/$id';
  static const String team = '/team';
  static const String developers = '/developers';
}
