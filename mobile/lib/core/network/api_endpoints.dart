import 'package:flutter/foundation.dart' show kIsWeb;

class ApiEndpoints {
  ApiEndpoints._();

  // Web defaults to the gateway's same-origin API; native keeps the
  // existing absolute development URL. Both can be overridden at build time.
  static const String configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb
        ? '/api'
        : 'https://jackeline-cibarious-supergallantly.ngrok-free.dev/api',
  );

  // Resolve root-relative web URLs before passing them to Dio or SignalR.
  static final String baseUrl = resolveApiBaseUrl(
    configuredBaseUrl,
    isWeb: kIsWeb,
    browserUri: Uri.base,
  );

  static String resolveApiBaseUrl(
    String value, {
    required bool isWeb,
    required Uri browserUri,
  }) {
    final raw = value.trim();
    final parsed = Uri.tryParse(raw);
    if (parsed == null || raw.isEmpty || raw.contains('\\')) {
      throw const FormatException('Invalid API_BASE_URL.');
    }

    final Uri uri;
    if (parsed.hasScheme) {
      uri = parsed;
    } else if (isWeb && raw.startsWith('/') && !raw.startsWith('//')) {
      uri = browserUri.resolveUri(parsed);
    } else {
      throw const FormatException(
        'Use an absolute API URL on mobile or a root-relative URL on web.',
      );
    }

    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !path.endsWith('/api')) {
      throw const FormatException(
        'API_BASE_URL must be an HTTP(S) URL ending in /api.',
      );
    }
    return uri.replace(path: path).toString();
  }

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
  static const String projects = '/projects';

  static String projectById(String id) => '/projects/$id';

  static const String projectJiraOptions = '/projects/jira-options';

  static String projectJira(String projectId) => '/projects/$projectId/jira';

  static String projectMember(String projectId, String employeeId) =>
      '/projects/$projectId/members/$employeeId';

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
  static String githubProjectActivity(String projectId) =>
      '/projects/$projectId/github/activity';

  static String githubProject(String projectId) =>
      '/integrations/github/projects/$projectId';
  static String githubProjectRepository(String projectId) =>
      '/integrations/github/projects/$projectId/repository';
  static String githubProjectSync(String projectId) =>
      '/integrations/github/projects/$projectId/sync';
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // Knowledge Sources & Meeting Notes
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  static const String clients = '/Client';

  static const String knowledgeSources = '/knowledge/sources';

  static const String knowledgeSourcesUpload = '/knowledge/sources/upload';

  static String knowledgeSourceById(String id) => '/knowledge/sources/$id';

  static String knowledgeSourceVersions(String id) =>
      '/knowledge/sources/$id/versions';

  static String knowledgeSourceVersionUpload(String id) =>
      '/knowledge/sources/$id/versions/upload';

  static String knowledgeSourceRetry(String id, int version) =>
      '/knowledge/sources/$id/versions/$version/retry';

  static String projectMembers(String projectId) =>
      '$projects/${Uri.encodeComponent(projectId)}/members';

  // Current employee profile
  static const String myProfile = '/Employee/me';

  // Integration identities
  static const String myIntegrationIdentities = '/integrations/identities/me';

  // Security audit
  static const String auditLogs = '/audit';

  // Clients
  static String clientById(String id) => '$clients/${Uri.encodeComponent(id)}';

  // Knowledge source operations
  static String knowledgeSourceReview(String id, int version) =>
      '${knowledgeSourceById(id)}/versions/$version/review';

  static String knowledgeSourceExtraction(String id, int version) =>
      '${knowledgeSourceById(id)}/versions/$version/extraction';

  static String knowledgeSourceProject(String id) =>
      '${knowledgeSourceById(id)}/project';

  static String signalRBaseFor(String absoluteApiUrl) {
    final uri = Uri.parse(absoluteApiUrl);
    final path = uri.path.replaceFirst(RegExp(r'/api/?$'), '');
    return uri.replace(path: path).toString().replaceFirst(RegExp(r'/$'), '');
  }

  static String get signalRBaseUrl => signalRBaseFor(baseUrl);

  static String get projectStatusHub => '$signalRBaseUrl/hubs/project-status';
}
