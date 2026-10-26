class ApiEndpoints 
{
  ApiEndpoints._();

  // ═══════════════════════════════════════════════════════════
  // Base URL
  // ═══════════════════════════════════════════════════════════
   static const String baseUrl = 'http://localhost:5221/api';
  // ═══════════════════════════════════════════════════════════
  // Auth
  // ═══════════════════════════════════════════════════════════
  static const String login = '/Auth/login';
  static const String register = '/Auth/register';
  static const String logout = '/Auth/logout';
  static const String refreshToken = '/Auth/refresh-token';
  static const String sendOtp = '/Auth/send-otp';
  static const String verifyOtp = '/Auth/verify-otp';
  static const String resetPassword = '/Auth/reset-password';
  static const String checkEmail = '/Auth/check-email';

  // ═══════════════════════════════════════════════════════════
  // Projects
  // ═══════════════════════════════════════════════════════════
  static const String projects = '/Projects';
  static String projectById(String id) => '/Projects/$id';

  // ═══════════════════════════════════════════════════════════
  // Tasks
  // ═══════════════════════════════════════════════════════════
  static const String tasks = '/Tasks';
  static String taskById(String id) => '/Tasks/$id';

  // ═══════════════════════════════════════════════════════════
  // Chat
  // ═══════════════════════════════════════════════════════════
  static const String chat = '/Chat';

  // ═══════════════════════════════════════════════════════════
  // Graph
  // ═══════════════════════════════════════════════════════════
  static const String graph = '/Graph';

  // ═══════════════════════════════════════════════════════════
  // Dashboard
  // ═══════════════════════════════════════════════════════════
  static const String dashboardStats = '/Dashboard/stats';
  
  // ═══════════════════════════════════════════════════════════
  static const String me = '/Employee/me';

  // ═══════════════════════════════════════════════════════════
  // Integrations (Jira)
  // ═══════════════════════════════════════════════════════════
  static const String jiraConnect = '/integrations/Jira/connect-jira';
  static const String jiraStatus = '/integrations/Jira/status';
}