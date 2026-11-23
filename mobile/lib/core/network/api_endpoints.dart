class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'https://jackeline-cibarious-supergallantly.ngrok-free.dev/api';

  static const String login = '/Auth/login';
  static const String register = '/Auth/register';
  static const String logout = '/Auth/logout';
  static const String refreshToken = '/Auth/refresh-token';
  static const String sendOtp = '/Auth/send-otp';
  static const String verifyOtp = '/Auth/verify-otp';
  static const String resetPassword = '/Auth/reset-password';
  static const String checkEmail = '/Auth/check-email';

  static const String createEmployee = '/Employee/create-employee';
  static const String updateEmployee = '/Employee/update-employee';
  static const String deleteEmployee = '/Employee/delete-employee';
  static const String changeRole = '/Employee/change-role';
  static const String allEmployees = '/Employee/all-employee';
  static const String employeeById = '/Employee/employee-by-id';
  static const String employeesByName = '/Employee/employees-by-name';
  static const String employeesByRole = '/Employee/employees-by-role';

  static const String allRoles = '/Role/get-all-roles';
  static const String roleByName = '/Role/get-role-by-name';
  static const String createRole = '/Role/create-role';
  static const String updateRole = '/Role/update-role';
  static const String deleteRole = '/Role/delete-role';

  static const String projects = '/Projects';
  static String projectById(String id) => '/Projects/$id';

  static const String askAssistant = '/assistant/ask';
  static const String getConversations = '/assistant/conversations';
  static String getConversationMessages(String id) =>
      '/assistant/conversations/$id/messages';
  static String deleteConversation(String id) => '/assistant/conversations/$id';

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

  static const String githubConnect = '/integrations/github/connect';
  static const String githubAuthorizeCompany =
      '/integrations/github/authorize-company';
  static const String githubConnectEmployee =
      '/integrations/github/connect-employee';
  static const String githubCallback = '/integrations/github/callback';
  static const String githubPending = '/integrations/github/pending';
  static const String githubComplete = '/integrations/github/complete';
  static const String githubCompany = '/integrations/github/company';
  static const String githubEmployee = '/integrations/github/employee';
  static const String githubRepositories = '/integrations/github/repositories';

  static String githubProject(String projectId) =>
      '/integrations/github/projects/$projectId';
  static String githubProjectRepository(String projectId) =>
      '/integrations/github/projects/$projectId/repository';
  static String githubProjectSync(String projectId) =>
      '/integrations/github/projects/$projectId/sync';
}
