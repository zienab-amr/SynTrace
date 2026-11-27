class ProjectCacheKeys {
  ProjectCacheKeys._();

  static const String resourceType = 'projects';

  static const String list = 'all_projects';

  static String details(String projectId) {
    return 'details:$projectId';
  }
}
