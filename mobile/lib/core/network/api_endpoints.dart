class ApiEndpoints 
{
  ApiEndpoints._();

  // ═══════════════════════════════════════════════════════════
  // Base URL
  // ═══════════════════════════════════════════════════════════
   static const String baseUrl = 'http://localhost:5221';
  // ═══════════════════════════════════════════════════════════
  // Auth
  // ═══════════════════════════════════════════════════════════
  static const String login = '/api/Auth/login';
  static const String register = '/api/Auth/register';
  static const String logout = '/api/Auth/logout';
  static const String refreshToken = '/api/Auth/refresh-token';
  static const String sendOtp = '/api/Auth/send-otp';
  static const String verifyOtp = '/api/Auth/verify-otp';
  static const String resetPassword = '/api/Auth/reset-password';
  static const String checkEmail = '/api/Auth/check-email';

  // ═══════════════════════════════════════════════════════════
  // Projects
  // ═══════════════════════════════════════════════════════════
  static const String projects = '/api/Projects';
  static String projectById(String id) => '/api/Projects/$id';

  // ═══════════════════════════════════════════════════════════
  // Tasks
  // ═══════════════════════════════════════════════════════════
  static const String tasks = '/api/Tasks';
  static String taskById(String id) => '/api/Tasks/$id';

  // ═══════════════════════════════════════════════════════════
  // Chat
  // ═══════════════════════════════════════════════════════════
  static const String chat = '/api/Chat';

  // ═══════════════════════════════════════════════════════════
  // Graph
  // ═══════════════════════════════════════════════════════════
  static const String graph = '/api/Graph';

  // ═══════════════════════════════════════════════════════════
  // Dashboard
  // ═══════════════════════════════════════════════════════════
  static const String dashboardStats = '/api/Dashboard/stats';
  
  // ═══════════════════════════════════════════════════════════
  static const String me = '/api/Employee/me';

  // ═══════════════════════════════════════════════════════════
  // Integrations (Jira)
  // ═══════════════════════════════════════════════════════════
  static const String jiraConnect = '/api/integrations/Jira/connect-jira';
  static const String jiraStatus = '/api/integrations/Jira/status';
}