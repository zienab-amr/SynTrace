class ApiEndpoints {
  ApiEndpoints._();

  // ═══════════════════════════════════════════════════════════
  // Base URL
  // ═══════════════════════════════════════════════════════════
  static const String baseUrl = 'http://localhost:8081/api';
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
  // Employee
  // ═══════════════════════════════════════════════════════════
  static const String createEmployee = '/Employee/create-employee';
  static const String updateEmployee = '/Employee/update-employee';
  static const String deleteEmployee = '/Employee/delete-employee';
  static const String changeRole = '/Employee/change-role';
  static const String allEmployees = '/Employee/all-employee';
  static const String employeeById = '/Employee/employee-by-id';
  static const String employeesByName = '/Employee/employees-by-name';
  static const String employeesByRole = '/Employee/employees-by-role';

  // ═══════════════════════════════════════════════════════════
  // Role
  // ═══════════════════════════════════════════════════════════
  static const String allRoles = '/Role/get-all-roles';
  static const String roleByName = '/Role/get-role-by-name';
  static const String createRole = '/Role/create-role';
  static const String updateRole = '/Role/update-role';
  static const String deleteRole = '/Role/delete-role';
  // ═══════════════════════════════════════════════════════════
  // Projects
  // ═══════════════════════════════════════════════════════════
  static const String projects = '/Projects';
  static String projectById(String id) => '/Projects/$id';
  // ═══════════════════════════════════════════════════════════
  // AI Assistant
  // ═══════════════════════════════════════════════════════════
  static const String askAssistant = '/assistant/ask';
  // ═══════════════════════════════════════════════════════════
  // Integrations (Jira)
  // ═══════════════════════════════════════════════════════════
  static const String jiraConnect = '/integrations/Jira/connect-jira';
  static const String jiraConnectEmployee =
      '/integrations/Jira/connect-employee-jira';
  static const String jiraPendingSites =
      '/integrations/Jira/pending-company-sites';
  static const String jiraCompleteConnection =
      '/integrations/Jira/complete-company-connection';
  static const String jiraSync = '/integrations/jira/sync';
  static const String jiraSyncStatus = '/integrations/jira/sync/status';

  static const String jiraStatus = jiraSyncStatus;

  static const String jiraAdminWebhookSetup =
      '/integrations/jira/admin-webhook/setup';
  static const String jiraAdminWebhookStatus =
      '/integrations/jira/admin-webhook/status';
  static const String jiraDisconnect = '/integrations/jira/connection';

  static const String jiraCallback = '/integrations/Jira/callback';

  static String jiraWebhook(String connectionId) =>
      '/integrations/jira/webhook/$connectionId';

  static String jiraWebhookAdmin(String connectionId) =>
      '/integrations/jira/webhook/$connectionId/admin';
}