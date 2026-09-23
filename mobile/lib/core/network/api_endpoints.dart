class ApiEndpoints {
  ApiEndpoints._(); // عشان مينفعش يتعمل منه instance

  // ═══════════════════════════════════════════
  // Base URL
  // ═══════════════════════════════════════════
  // غيّريها حسب الـ Backend بتاعك
  static const String baseUrl = 'https://localhost:5001/api';

  // ═══════════════════════════════════════════
  // Auth
  // ═══════════════════════════════════════════
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // ═══════════════════════════════════════════
  // Projects
  // ═══════════════════════════════════════════
  static const String projects = '/projects';
  static String projectById(String id) => '/projects/$id';

  // ═══════════════════════════════════════════
  // Tasks
  // ═══════════════════════════════════════════
  static const String tasks = '/tasks';
  static String taskById(String id) => '/tasks/$id';

  // ═══════════════════════════════════════════
  // Meetings
  // ═══════════════════════════════════════════
  static const String meetings = '/meetings';
  static String meetingById(String id) => '/meetings/$id';

  // ═══════════════════════════════════════════
  // Commits
  // ═══════════════════════════════════════════
  static const String commits = '/commits';

  // ═══════════════════════════════════════════
  // Bugs
  // ═══════════════════════════════════════════
  static const String bugs = '/bugs';
  static String bugById(String id) => '/bugs/$id';

  // ═══════════════════════════════════════════
  // Requirements
  // ═══════════════════════════════════════════
  static const String requirements = '/requirements';

  // ═══════════════════════════════════════════
  // AI Chat
  // ═══════════════════════════════════════════
  static const String chat = '/chat';
  static const String chatHistory = '/chat/history';

  // ═══════════════════════════════════════════
  // Knowledge Graph
  // ═══════════════════════════════════════════
  static const String graph = '/graph';
  static const String graphSearch = '/graph/search';

  // ═══════════════════════════════════════════
  // Dashboard
  // ═══════════════════════════════════════════
  static const String dashboardStats = '/dashboard/stats';
  static const String dashboardRecent = '/dashboard/recent';
}