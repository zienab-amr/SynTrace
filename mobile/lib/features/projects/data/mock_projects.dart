import 'package:syntrace/core/models/project_model.dart';
import 'package:syntrace/core/models/user_model.dart';

/// ═══════════════════════════════════════════════════════════
/// Mock Projects
/// ═══════════════════════════════════════════════════════════
class MockProjects {
  MockProjects._();

  static final List<ProjectModel> projects = [
    ProjectModel(
      id: 'proj-1',
      name: 'ERP Platform v3.0',
      description: 'Platform Team · Flutter',
      status: ProjectStatus.active,
      startDate: DateTime(2024, 9, 3),
      tenantId: 'tenant-A',
      ownerId: 'user-1',
      memberIds: const ['user-1', 'user-2', 'user-3', 'user-4'],
      currentSprint: 14,
      totalSprints: 20,
      sprintEnd: DateTime(2024, 9, 17),
    ),
    ProjectModel(
      id: 'proj-2',
      name: 'Mobile Customer App',
      description: 'Mobile Team · Flutter',
      status: ProjectStatus.active,
      startDate: DateTime(2024, 9, 5),
      tenantId: 'tenant-A',
      ownerId: 'user-2',
      memberIds: const ['user-2', 'user-5'],
      currentSprint: 8,
      totalSprints: 12,
      sprintEnd: DateTime(2024, 9, 19),
    ),
    ProjectModel(
      id: 'proj-3',
      name: 'API Gateway Rewrite',
      description: 'Backend Team · Go',
      status: ProjectStatus.active,
      startDate: DateTime(2024, 9, 10),
      tenantId: 'tenant-A',
      ownerId: 'user-3',
      memberIds: const ['user-3', 'user-6'],
      currentSprint: 3,
      totalSprints: 10,
      sprintEnd: DateTime(2024, 9, 24),
    ),
    ProjectModel(
      id: 'proj-4',
      name: 'Analytics Dashboard',
      description: 'Data Team · React',
      status: ProjectStatus.active,
      startDate: DateTime(2024, 8, 15),
      tenantId: 'tenant-A',
      ownerId: 'user-4',
      memberIds: const ['user-1', 'user-4', 'user-5'],
      currentSprint: 6,
      totalSprints: 15,
      sprintEnd: DateTime(2024, 9, 20),
    ),
    ProjectModel(
      id: 'proj-5',
      name: 'HR Management System',
      description: 'Enterprise Team · .NET',
      status: ProjectStatus.active,
      startDate: DateTime(2024, 7, 1),
      tenantId: 'tenant-A',
      ownerId: 'user-3',
      memberIds: const ['user-2', 'user-3', 'user-6', 'user-1'],
      currentSprint: 12,
      totalSprints: 18,
      sprintEnd: DateTime(2024, 9, 18),
    ),
    ProjectModel(
      id: 'proj-6',
      name: 'Legacy Code Migration',
      description: 'Platform Team · Java',
      status: ProjectStatus.onHold,
      startDate: DateTime(2024, 6, 1),
      tenantId: 'tenant-A',
      ownerId: 'user-1',
      memberIds: const ['user-1', 'user-6'],
      currentSprint: 5,
      totalSprints: 25,
      sprintEnd: DateTime(2024, 10, 1),
    ),
    ProjectModel(
      id: 'proj-7',
      name: 'Payment Integration',
      description: 'Fintech Team · Node.js',
      status: ProjectStatus.completed,
      startDate: DateTime(2024, 5, 15),
      endDate: DateTime(2024, 8, 30),
      tenantId: 'tenant-A',
      ownerId: 'user-5',
      memberIds: const ['user-5', 'user-2'],
      currentSprint: 10,
      totalSprints: 10,
      sprintEnd: DateTime(2024, 8, 30),
    ),
    ProjectModel(
      id: 'proj-8',
      name: 'Notification Service',
      description: 'Backend Team · Go',
      status: ProjectStatus.archived,
      startDate: DateTime(2024, 3, 1),
      endDate: DateTime(2024, 6, 15),
      tenantId: 'tenant-A',
      ownerId: 'user-6',
      memberIds: const ['user-6', 'user-3'],
      currentSprint: 8,
      totalSprints: 8,
      sprintEnd: DateTime(2024, 6, 15),
    ),
  ];
}

/// ═══════════════════════════════════════════════════════════
/// Project Risk
/// ═══════════════════════════════════════════════════════════
enum ProjectRisk { high, medium, low }

/// ═══════════════════════════════════════════════════════════
/// Mock Users
/// ═══════════════════════════════════════════════════════════
class MockUsers {
  MockUsers._();

  static const List<UserModel> users = [
    UserModel(
      id: 'user-1',
      name: 'Ahmed Kamal',
      email: 'ahmed@syntrace.com',
      role: UserRole.developer,
    ),
    UserModel(
      id: 'user-2',
      name: 'Sara Mohamed',
      email: 'sara@syntrace.com',
      role: UserRole.developer,
    ),
    UserModel(
      id: 'user-3',
      name: 'Mohamed Ali',
      email: 'mohamed@syntrace.com',
      role: UserRole.manager,
    ),
    UserModel(
      id: 'user-4',
      name: 'Nour Hassan',
      email: 'nour@syntrace.com',
      role: UserRole.developer,
    ),
    UserModel(
      id: 'user-5',
      name: 'Rana Ibrahim',
      email: 'rana@syntrace.com',
      role: UserRole.developer,
    ),
    UserModel(
      id: 'user-6',
      name: 'Omar Yasser',
      email: 'omar@syntrace.com',
      role: UserRole.developer,
    ),
    UserModel(
      id: 'user-7',
      name: 'Layla Mostafa',
      email: 'layla@syntrace.com',
      role: UserRole.manager,
    ),
    UserModel(
      id: 'user-8',
      name: 'Youssef Tarek',
      email: 'youssef@syntrace.com',
      role: UserRole.developer,
    ),
  ];

  static List<UserModel> getByIds(List<String> ids) {
    return users.where((u) => ids.contains(u.id)).toList();
  }
}

/// ═══════════════════════════════════════════════════════════
/// Mock Tasks
/// ═══════════════════════════════════════════════════════════
class MockTaskItem {
  final String id;
  final String projectId;
  final String title;
  final String status; // todo | in_progress | done | blocked
  final String priority; // low | medium | high | critical
  final String assigneeName;

  const MockTaskItem({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    required this.priority,
    required this.assigneeName,
  });
}

class MockTasks {
  MockTasks._();

  static const List<MockTaskItem> tasks = [
    // ═══════════════════════════════════════
    // proj-1: ERP Platform (15 tasks)
    // ═══════════════════════════════════════
    MockTaskItem(
      id: 'SYNT-45',
      projectId: 'proj-1',
      title: 'Fix Customer Table schema',
      status: 'in_progress',
      priority: 'high',
      assigneeName: 'Ahmed Kamal',
    ),
    MockTaskItem(
      id: 'SYNT-46',
      projectId: 'proj-1',
      title: 'Update validation rules',
      status: 'todo',
      priority: 'medium',
      assigneeName: 'Sara Mohamed',
    ),
    MockTaskItem(
      id: 'SYNT-47',
      projectId: 'proj-1',
      title: 'Add API integration',
      status: 'done',
      priority: 'low',
      assigneeName: 'Mohamed Ali',
    ),
    MockTaskItem(
      id: 'SYNT-48',
      projectId: 'proj-1',
      title: 'Refactor auth service',
      status: 'blocked',
      priority: 'critical',
      assigneeName: 'Nour Hassan',
    ),
    MockTaskItem(
      id: 'SYNT-49',
      projectId: 'proj-1',
      title: 'Add unit tests for invoice module',
      status: 'done',
      priority: 'medium',
      assigneeName: 'Ahmed Kamal',
    ),
    MockTaskItem(
      id: 'SYNT-53',
      projectId: 'proj-1',
      title: 'Migrate to PostgreSQL 16',
      status: 'in_progress',
      priority: 'high',
      assigneeName: 'Sara Mohamed',
    ),
    MockTaskItem(
      id: 'SYNT-54',
      projectId: 'proj-1',
      title: 'Implement audit log',
      status: 'todo',
      priority: 'medium',
      assigneeName: 'Ahmed Kamal',
    ),
    MockTaskItem(
      id: 'SYNT-55',
      projectId: 'proj-1',
      title: 'Fix date format in reports',
      status: 'done',
      priority: 'low',
      assigneeName: 'Nour Hassan',
    ),
    MockTaskItem(
      id: 'SYNT-56',
      projectId: 'proj-1',
      title: 'Add export to Excel feature',
      status: 'blocked',
      priority: 'high',
      assigneeName: 'Sara Mohamed',
    ),
    MockTaskItem(
      id: 'SYNT-57',
      projectId: 'proj-1',
      title: 'Optimize slow queries',
      status: 'in_progress',
      priority: 'critical',
      assigneeName: 'Mohamed Ali',
    ),
    MockTaskItem(
      id: 'SYNT-58',
      projectId: 'proj-1',
      title: 'Add CSV import',
      status: 'todo',
      priority: 'low',
      assigneeName: 'Ahmed Kamal',
    ),
    MockTaskItem(
      id: 'SYNT-59',
      projectId: 'proj-1',
      title: 'Update UI to Material 3',
      status: 'done',
      priority: 'medium',
      assigneeName: 'Nour Hassan',
    ),
    MockTaskItem(
      id: 'SYNT-62',
      projectId: 'proj-1',
      title: 'Setup CI/CD pipeline',
      status: 'done',
      priority: 'high',
      assigneeName: 'Mohamed Ali',
    ),
    MockTaskItem(
      id: 'SYNT-63',
      projectId: 'proj-1',
      title: 'Add two-factor authentication',
      status: 'todo',
      priority: 'critical',
      assigneeName: 'Sara Mohamed',
    ),
    MockTaskItem(
      id: 'SYNT-64',
      projectId: 'proj-1',
      title: 'Fix memory leak in dashboard',
      status: 'blocked',
      priority: 'high',
      assigneeName: 'Ahmed Kamal',
    ),

    // ═══════════════════════════════════════
    // proj-2: Mobile App (10 tasks)
    // ═══════════════════════════════════════
    MockTaskItem(
      id: 'SYNT-50',
      projectId: 'proj-2',
      title: 'Design login screen',
      status: 'in_progress',
      priority: 'high',
      assigneeName: 'Sara Mohamed',
    ),
    MockTaskItem(
      id: 'SYNT-51',
      projectId: 'proj-2',
      title: 'Add biometric auth',
      status: 'todo',
      priority: 'medium',
      assigneeName: 'Rana Ibrahim',
    ),
    MockTaskItem(
      id: 'SYNT-52',
      projectId: 'proj-2',
      title: 'Fix cart bug',
      status: 'blocked',
      priority: 'critical',
      assigneeName: 'Sara Mohamed',
    ),
    MockTaskItem(
      id: 'SYNT-70',
      projectId: 'proj-2',
      title: 'Add push notifications',
      status: 'done',
      priority: 'high',
      assigneeName: 'Rana Ibrahim',
    ),
    MockTaskItem(
      id: 'SYNT-71',
      projectId: 'proj-2',
      title: 'Implement dark mode',
      status: 'done',
      priority: 'medium',
      assigneeName: 'Sara Mohamed',
    ),
    MockTaskItem(
      id: 'SYNT-72',
      projectId: 'proj-2',
      title: 'Add offline support',
      status: 'in_progress',
      priority: 'high',
      assigneeName: 'Rana Ibrahim',
    ),
    MockTaskItem(
      id: 'SYNT-73',
      projectId: 'proj-2',
      title: 'Fix crash on Android 14',
      status: 'blocked',
      priority: 'critical',
      assigneeName: 'Sara Mohamed',
    ),
    MockTaskItem(
      id: 'SYNT-74',
      projectId: 'proj-2',
      title: 'Add social login',
      status: 'todo',
      priority: 'medium',
      assigneeName: 'Rana Ibrahim',
    ),
    MockTaskItem(
      id: 'SYNT-75',
      projectId: 'proj-2',
      title: 'Optimize image loading',
      status: 'done',
      priority: 'low',
      assigneeName: 'Sara Mohamed',
    ),
    MockTaskItem(
      id: 'SYNT-76',
      projectId: 'proj-2',
      title: 'Add product reviews',
      status: 'todo',
      priority: 'low',
      assigneeName: 'Rana Ibrahim',
    ),

    // ═══════════════════════════════════════
    // proj-3: API Gateway (8 tasks)
    // ═══════════════════════════════════════
    MockTaskItem(
      id: 'SYNT-60',
      projectId: 'proj-3',
      title: 'Setup rate limiting',
      status: 'in_progress',
      priority: 'high',
      assigneeName: 'Mohamed Ali',
    ),
    MockTaskItem(
      id: 'SYNT-61',
      projectId: 'proj-3',
      title: 'Add API docs',
      status: 'todo',
      priority: 'low',
      assigneeName: 'Omar Yasser',
    ),
    MockTaskItem(
      id: 'SYNT-80',
      projectId: 'proj-3',
      title: 'Implement JWT refresh',
      status: 'done',
      priority: 'high',
      assigneeName: 'Mohamed Ali',
    ),
    MockTaskItem(
      id: 'SYNT-81',
      projectId: 'proj-3',
      title: 'Add request logging',
      status: 'in_progress',
      priority: 'medium',
      assigneeName: 'Omar Yasser',
    ),
    MockTaskItem(
      id: 'SYNT-82',
      projectId: 'proj-3',
      title: 'Setup Prometheus metrics',
      status: 'todo',
      priority: 'medium',
      assigneeName: 'Mohamed Ali',
    ),
    MockTaskItem(
      id: 'SYNT-83',
      projectId: 'proj-3',
      title: 'Add WebSocket support',
      status: 'blocked',
      priority: 'high',
      assigneeName: 'Omar Yasser',
    ),
    MockTaskItem(
      id: 'SYNT-84',
      projectId: 'proj-3',
      title: 'Fix CORS misconfiguration',
      status: 'done',
      priority: 'critical',
      assigneeName: 'Mohamed Ali',
    ),
    MockTaskItem(
      id: 'SYNT-85',
      projectId: 'proj-3',
      title: 'Add circuit breaker',
      status: 'todo',
      priority: 'high',
      assigneeName: 'Omar Yasser',
    ),

    // ═══════════════════════════════════════
    // proj-4: Analytics Dashboard (6 tasks)
    // ═══════════════════════════════════════
    MockTaskItem(
      id: 'SYNT-90',
      projectId: 'proj-4',
      title: 'Design chart components',
      status: 'done',
      priority: 'high',
      assigneeName: 'Nour Hassan',
    ),
    MockTaskItem(
      id: 'SYNT-91',
      projectId: 'proj-4',
      title: 'Add real-time updates',
      status: 'in_progress',
      priority: 'high',
      assigneeName: 'Ahmed Kamal',
    ),
    MockTaskItem(
      id: 'SYNT-92',
      projectId: 'proj-4',
      title: 'Export to PDF',
      status: 'todo',
      priority: 'medium',
      assigneeName: 'Rana Ibrahim',
    ),
    MockTaskItem(
      id: 'SYNT-93',
      projectId: 'proj-4',
      title: 'Add date range filter',
      status: 'done',
      priority: 'medium',
      assigneeName: 'Nour Hassan',
    ),
    MockTaskItem(
      id: 'SYNT-94',
      projectId: 'proj-4',
      title: 'Fix chart rendering on Safari',
      status: 'blocked',
      priority: 'high',
      assigneeName: 'Ahmed Kamal',
    ),
    MockTaskItem(
      id: 'SYNT-95',
      projectId: 'proj-4',
      title: 'Add custom dashboards',
      status: 'todo',
      priority: 'low',
      assigneeName: 'Rana Ibrahim',
    ),

    // ═══════════════════════════════════════
    // proj-5: HR System (5 tasks)
    // ═══════════════════════════════════════
    MockTaskItem(
      id: 'SYNT-100',
      projectId: 'proj-5',
      title: 'Employee CRUD',
      status: 'done',
      priority: 'high',
      assigneeName: 'Sara Mohamed',
    ),
    MockTaskItem(
      id: 'SYNT-101',
      projectId: 'proj-5',
      title: 'Attendance tracking',
      status: 'in_progress',
      priority: 'high',
      assigneeName: 'Mohamed Ali',
    ),
    MockTaskItem(
      id: 'SYNT-102',
      projectId: 'proj-5',
      title: 'Payroll module',
      status: 'todo',
      priority: 'critical',
      assigneeName: 'Omar Yasser',
    ),
    MockTaskItem(
      id: 'SYNT-103',
      projectId: 'proj-5',
      title: 'Leave management',
      status: 'in_progress',
      priority: 'medium',
      assigneeName: 'Ahmed Kamal',
    ),
    MockTaskItem(
      id: 'SYNT-104',
      projectId: 'proj-5',
      title: 'Reports generation',
      status: 'blocked',
      priority: 'high',
      assigneeName: 'Sara Mohamed',
    ),
  ];

  static List<MockTaskItem> getByProject(String projectId) {
    return tasks.where((t) => t.projectId == projectId).toList();
  }

  static int openCount(String projectId) {
    return tasks
        .where((t) => t.projectId == projectId && t.status != 'done')
        .length;
  }

  static int doneCount(String projectId) {
    return tasks
        .where((t) => t.projectId == projectId && t.status == 'done')
        .length;
  }

  static int blockedCount(String projectId) {
    return tasks
        .where((t) => t.projectId == projectId && t.status == 'blocked')
        .length;
  }

  static int totalCount(String projectId) {
    return tasks.where((t) => t.projectId == projectId).length;
  }
}

/// ═══════════════════════════════════════════════════════════
/// Mock PRs
/// ═══════════════════════════════════════════════════════════
class MockPRItem {
  final String id;
  final String projectId;
  final String title;
  final String authorName;
  final String status; // open | merged | closed
  final int additions;
  final int deletions;

  const MockPRItem({
    required this.id,
    required this.projectId,
    required this.title,
    required this.authorName,
    required this.status,
    required this.additions,
    required this.deletions,
  });
}

class MockPRs {
  MockPRs._();

  static const List<MockPRItem> prs = [
    // proj-1
    MockPRItem(
      id: '#142',
      projectId: 'proj-1',
      title: 'Add customer migration',
      authorName: 'Ahmed Kamal',
      status: 'open',
      additions: 240,
      deletions: 32,
    ),
    MockPRItem(
      id: '#141',
      projectId: 'proj-1',
      title: 'Fix login bug',
      authorName: 'Sara Mohamed',
      status: 'merged',
      additions: 12,
      deletions: 8,
    ),
    MockPRItem(
      id: '#140',
      projectId: 'proj-1',
      title: 'Refactor dashboard',
      authorName: 'Mohamed Ali',
      status: 'open',
      additions: 380,
      deletions: 120,
    ),
    MockPRItem(
      id: '#139',
      projectId: 'proj-1',
      title: 'Add audit log',
      authorName: 'Nour Hassan',
      status: 'open',
      additions: 90,
      deletions: 5,
    ),
    MockPRItem(
      id: '#138',
      projectId: 'proj-1',
      title: 'Optimize queries',
      authorName: 'Ahmed Kamal',
      status: 'merged',
      additions: 45,
      deletions: 180,
    ),
    MockPRItem(
      id: '#137',
      projectId: 'proj-1',
      title: 'Fix CI pipeline',
      authorName: 'Mohamed Ali',
      status: 'closed',
      additions: 30,
      deletions: 12,
    ),

    // proj-2
    MockPRItem(
      id: '#152',
      projectId: 'proj-2',
      title: 'Add biometric login',
      authorName: 'Sara Mohamed',
      status: 'open',
      additions: 120,
      deletions: 15,
    ),
    MockPRItem(
      id: '#151',
      projectId: 'proj-2',
      title: 'Fix cart performance',
      authorName: 'Rana Ibrahim',
      status: 'merged',
      additions: 45,
      deletions: 60,
    ),
    MockPRItem(
      id: '#150',
      projectId: 'proj-2',
      title: 'Add push notifications',
      authorName: 'Sara Mohamed',
      status: 'open',
      additions: 200,
      deletions: 25,
    ),
    MockPRItem(
      id: '#149',
      projectId: 'proj-2',
      title: 'Dark mode theme',
      authorName: 'Rana Ibrahim',
      status: 'merged',
      additions: 180,
      deletions: 90,
    ),

    // proj-3
    MockPRItem(
      id: '#160',
      projectId: 'proj-3',
      title: 'Add rate limiter',
      authorName: 'Mohamed Ali',
      status: 'open',
      additions: 210,
      deletions: 18,
    ),
    MockPRItem(
      id: '#161',
      projectId: 'proj-3',
      title: 'Update API docs',
      authorName: 'Omar Yasser',
      status: 'open',
      additions: 80,
      deletions: 5,
    ),
    MockPRItem(
      id: '#162',
      projectId: 'proj-3',
      title: 'Fix CORS issue',
      authorName: 'Omar Yasser',
      status: 'merged',
      additions: 15,
      deletions: 3,
    ),
    MockPRItem(
      id: '#163',
      projectId: 'proj-3',
      title: 'JWT refresh token',
      authorName: 'Mohamed Ali',
      status: 'open',
      additions: 130,
      deletions: 45,
    ),

    // proj-4
    MockPRItem(
      id: '#170',
      projectId: 'proj-4',
      title: 'Add chart library',
      authorName: 'Nour Hassan',
      status: 'open',
      additions: 300,
      deletions: 10,
    ),
    MockPRItem(
      id: '#171',
      projectId: 'proj-4',
      title: 'Real-time updates',
      authorName: 'Ahmed Kamal',
      status: 'open',
      additions: 150,
      deletions: 25,
    ),

    // proj-5
    MockPRItem(
      id: '#180',
      projectId: 'proj-5',
      title: 'Employee CRUD API',
      authorName: 'Sara Mohamed',
      status: 'merged',
      additions: 420,
      deletions: 15,
    ),
    MockPRItem(
      id: '#181',
      projectId: 'proj-5',
      title: 'Attendance module',
      authorName: 'Mohamed Ali',
      status: 'open',
      additions: 280,
      deletions: 40,
    ),
    MockPRItem(
      id: '#182',
      projectId: 'proj-5',
      title: 'Leave request flow',
      authorName: 'Ahmed Kamal',
      status: 'open',
      additions: 190,
      deletions: 30,
    ),
  ];

  static List<MockPRItem> getByProject(String projectId) {
    return prs.where((p) => p.projectId == projectId).toList();
  }

  static int count(String projectId) {
    return prs.where((p) => p.projectId == projectId).length;
  }
}

/// ═══════════════════════════════════════════════════════════
/// Mock Commits
/// ═══════════════════════════════════════════════════════════
class MockCommitItem {
  final String sha;
  final String projectId;
  final String message;
  final String authorName;
  final String timeAgo;

  const MockCommitItem({
    required this.sha,
    required this.projectId,
    required this.message,
    required this.authorName,
    required this.timeAgo,
  });
}

class MockCommits {
  MockCommits._();

  static const List<MockCommitItem> commits = [
    // proj-1
    MockCommitItem(
      sha: 'a3f2b1c',
      projectId: 'proj-1',
      message: 'Add customer table migration',
      authorName: 'Ahmed Kamal',
      timeAgo: '2 hours ago',
    ),
    MockCommitItem(
      sha: '8e4d9f2',
      projectId: 'proj-1',
      message: 'Fix validation error',
      authorName: 'Sara Mohamed',
      timeAgo: '5 hours ago',
    ),
    MockCommitItem(
      sha: '1c7a3b8',
      projectId: 'proj-1',
      message: 'Update API endpoints',
      authorName: 'Mohamed Ali',
      timeAgo: '1 day ago',
    ),
    MockCommitItem(
      sha: 'f2b4a1d',
      projectId: 'proj-1',
      message: 'Refactor auth middleware',
      authorName: 'Nour Hassan',
      timeAgo: '1 day ago',
    ),
    MockCommitItem(
      sha: '9d3e7c5',
      projectId: 'proj-1',
      message: 'Add unit tests',
      authorName: 'Ahmed Kamal',
      timeAgo: '2 days ago',
    ),
    MockCommitItem(
      sha: '6a8f2b9',
      projectId: 'proj-1',
      message: 'Optimize database indexes',
      authorName: 'Mohamed Ali',
      timeAgo: '3 days ago',
    ),

    // proj-2
    MockCommitItem(
      sha: 'b5e8a3f',
      projectId: 'proj-2',
      message: 'Add biometric module',
      authorName: 'Sara Mohamed',
      timeAgo: '1 hour ago',
    ),
    MockCommitItem(
      sha: '2d9c4e1',
      projectId: 'proj-2',
      message: 'Fix cart state',
      authorName: 'Rana Ibrahim',
      timeAgo: '3 hours ago',
    ),
    MockCommitItem(
      sha: '7f1b8a2',
      projectId: 'proj-2',
      message: 'Add dark theme',
      authorName: 'Sara Mohamed',
      timeAgo: '1 day ago',
    ),
    MockCommitItem(
      sha: '3e5c9d4',
      projectId: 'proj-2',
      message: 'Update icons',
      authorName: 'Rana Ibrahim',
      timeAgo: '2 days ago',
    ),

    // proj-3
    MockCommitItem(
      sha: 'f8b2c5d',
      projectId: 'proj-3',
      message: 'Add rate limiter middleware',
      authorName: 'Mohamed Ali',
      timeAgo: '30 min ago',
    ),
    MockCommitItem(
      sha: '7a1e9b3',
      projectId: 'proj-3',
      message: 'Update OpenAPI spec',
      authorName: 'Omar Yasser',
      timeAgo: '6 hours ago',
    ),
    MockCommitItem(
      sha: '4c6f8d2',
      projectId: 'proj-3',
      message: 'Fix CORS headers',
      authorName: 'Omar Yasser',
      timeAgo: '2 days ago',
    ),

    // proj-4
    MockCommitItem(
      sha: 'c1d4e7a',
      projectId: 'proj-4',
      message: 'Add chart components',
      authorName: 'Nour Hassan',
      timeAgo: '4 hours ago',
    ),
    MockCommitItem(
      sha: 'e9b3f6c',
      projectId: 'proj-4',
      message: 'Fix responsive layout',
      authorName: 'Ahmed Kamal',
      timeAgo: '1 day ago',
    ),

    // proj-5
    MockCommitItem(
      sha: 'd2a5b8e',
      projectId: 'proj-5',
      message: 'Add employee CRUD',
      authorName: 'Sara Mohamed',
      timeAgo: '3 hours ago',
    ),
    MockCommitItem(
      sha: 'a4f7c1d',
      projectId: 'proj-5',
      message: 'Fix attendance bug',
      authorName: 'Mohamed Ali',
      timeAgo: '1 day ago',
    ),
    MockCommitItem(
      sha: 'b6e9d2a',
      projectId: 'proj-5',
      message: 'Update payroll rules',
      authorName: 'Omar Yasser',
      timeAgo: '2 days ago',
    ),
  ];

  static List<MockCommitItem> getByProject(String projectId) {
    return commits.where((c) => c.projectId == projectId).toList();
  }

  static int count(String projectId) {
    return commits.where((c) => c.projectId == projectId).length;
  }
}

/// ═══════════════════════════════════════════════════════════
/// Mock Bugs
/// ═══════════════════════════════════════════════════════════
class MockBugItem {
  final String id;
  final String projectId;
  final String title;
  final String severity; // low | medium | high | critical
  final String status; // open | resolved

  const MockBugItem({
    required this.id,
    required this.projectId,
    required this.title,
    required this.severity,
    required this.status,
  });
}

class MockBugs {
  MockBugs._();

  static const List<MockBugItem> bugs = [
    // proj-1
    MockBugItem(
      id: 'BUG-12',
      projectId: 'proj-1',
      title: 'Customer data corrupted',
      severity: 'critical',
      status: 'open',
    ),
    MockBugItem(
      id: 'BUG-11',
      projectId: 'proj-1',
      title: 'Login timeout on slow network',
      severity: 'high',
      status: 'open',
    ),
    MockBugItem(
      id: 'BUG-10',
      projectId: 'proj-1',
      title: 'Typo in error message',
      severity: 'low',
      status: 'resolved',
    ),
    MockBugItem(
      id: 'BUG-13',
      projectId: 'proj-1',
      title: 'Export fails for large datasets',
      severity: 'medium',
      status: 'open',
    ),
    MockBugItem(
      id: 'BUG-14',
      projectId: 'proj-1',
      title: 'Session expires too fast',
      severity: 'high',
      status: 'open',
    ),

    // proj-2
    MockBugItem(
      id: 'BUG-20',
      projectId: 'proj-2',
      title: 'Cart total wrong',
      severity: 'high',
      status: 'open',
    ),
    MockBugItem(
      id: 'BUG-21',
      projectId: 'proj-2',
      title: 'Biometric fails on Android 12',
      severity: 'medium',
      status: 'open',
    ),
    MockBugItem(
      id: 'BUG-22',
      projectId: 'proj-2',
      title: 'App crashes on logout',
      severity: 'critical',
      status: 'open',
    ),
    MockBugItem(
      id: 'BUG-23',
      projectId: 'proj-2',
      title: 'Images not cached',
      severity: 'low',
      status: 'resolved',
    ),

    // proj-3
    MockBugItem(
      id: 'BUG-30',
      projectId: 'proj-3',
      title: 'Rate limit too strict',
      severity: 'medium',
      status: 'open',
    ),
    MockBugItem(
      id: 'BUG-31',
      projectId: 'proj-3',
      title: 'JWT expiry not handled',
      severity: 'high',
      status: 'open',
    ),

    // proj-4
    MockBugItem(
      id: 'BUG-40',
      projectId: 'proj-4',
      title: 'Chart not rendering on Safari',
      severity: 'high',
      status: 'open',
    ),
    MockBugItem(
      id: 'BUG-41',
      projectId: 'proj-4',
      title: 'Filter resets on refresh',
      severity: 'medium',
      status: 'open',
    ),

    // proj-5
    MockBugItem(
      id: 'BUG-50',
      projectId: 'proj-5',
      title: 'Payroll calculation off by 0.01',
      severity: 'critical',
      status: 'open',
    ),
    MockBugItem(
      id: 'BUG-51',
      projectId: 'proj-5',
      title: 'Attendance shows duplicate entries',
      severity: 'medium',
      status: 'open',
    ),
  ];

  static List<MockBugItem> getByProject(String projectId) {
    return bugs.where((b) => b.projectId == projectId).toList();
  }

  static int openCount(String projectId) {
    return bugs
        .where((b) => b.projectId == projectId && b.status == 'open')
        .length;
  }
}

/// ═══════════════════════════════════════════════════════════
/// Project Stats — محسوبة من الـ Mock Data
/// ═══════════════════════════════════════════════════════════
class ProjectStats {
  final String projectId;
  final int healthPercent;
  final int openTasks;
  final int blockedTasks;
  final int pullRequests;
  final int commitsCount;
  final int openBugs;
  final double progress;
  final ProjectRisk risk;

  const ProjectStats({
    required this.projectId,
    required this.healthPercent,
    required this.openTasks,
    required this.blockedTasks,
    required this.pullRequests,
    required this.commitsCount,
    required this.openBugs,
    required this.progress,
    required this.risk,
  });
}

class MockProjectStats {
  MockProjectStats._();

  static ProjectStats forProject(String projectId) {
    final totalTasks = MockTasks.totalCount(projectId);
    final doneTasks = MockTasks.doneCount(projectId);
    final openTasks = MockTasks.openCount(projectId);
    final blockedTasks = MockTasks.blockedCount(projectId);
    final prs = MockPRs.count(projectId);
    final commits = MockCommits.count(projectId);
    final openBugs = MockBugs.openCount(projectId);

    // ─── Progress: نسبة الـ Done ───
    final progress = totalTasks > 0 ? doneTasks / totalTasks : 0.0;

    // ─── Health ───
    final doneRatio = totalTasks > 0 ? doneTasks / totalTasks : 0.0;
    final blockedPenalty =
        totalTasks > 0 ? (blockedTasks / totalTasks) * 0.25 : 0.0;
    final bugsPenalty = (openBugs / 10).clamp(0.0, 0.15);
    final commitBonus = (commits / 10).clamp(0.0, 0.10);

    final health = ((doneRatio * 0.5) +
            (0.25 - blockedPenalty) +
            (0.15 - bugsPenalty) +
            commitBonus)
        .clamp(0.0, 1.0);

    // ─── Risk ───
    final ProjectRisk risk;
    if (health < 0.5) {
      risk = ProjectRisk.high;
    } else if (health < 0.75) {
      risk = ProjectRisk.medium;
    } else {
      risk = ProjectRisk.low;
    }

    return ProjectStats(
      projectId: projectId,
      healthPercent: (health * 100).toInt(),
      openTasks: openTasks,
      blockedTasks: blockedTasks,
      pullRequests: prs,
      commitsCount: commits,
      openBugs: openBugs,
      progress: progress,
      risk: risk,
    );
  }

  static ProjectStats? get(String projectId) {
    try {
      return forProject(projectId);
    } catch (_) {
      return null;
    }
  }

  static Map<String, ProjectStats> get stats {
    return {
      for (final p in MockProjects.projects) p.id: forProject(p.id),
    };
  }
}