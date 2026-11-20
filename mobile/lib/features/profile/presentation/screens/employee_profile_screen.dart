import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/profile/data/profile_data_service.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class EmployeeProfileScreen extends StatelessWidget {
  final String employeeId;

  const EmployeeProfileScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: 'Employee Profile',
      showBackButton: true,
      child: FutureBuilder<ProfileDataBundle?>(
        future: ProfileDataService.getProfileData(employeeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Employee not found'));
          }

          final data = snapshot.data!;
          final user = data.user;

          return LayoutBuilder(
            builder: (context, constraints) {
              // لو الشاشة كبيرة (ويب/تابلت)، هنقسمها لعمودين
              final isDesktop = constraints.maxWidth > 900;

              // الهيدر وكروت الإحصائيات (بياخدوا الشاشة كلها فوق)
              final headerAndStats = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                user.email,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  user.role.value.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stats Row
                  Row(
                    children: [
                      _buildStatCard(
                        theme,
                        'Projects',
                        '${data.projects.length}',
                        Icons.folder_outlined,
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        theme,
                        'Tasks',
                        '${data.tasks.length}',
                        Icons.task_alt,
                        Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        theme,
                        'Commits',
                        '${data.commits.length}',
                        Icons.commit,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              );

              // المشاريع
              final projectsList = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(theme, 'Assigned Projects'),
                  if (data.projects.isEmpty)
                    Text(
                      'No projects assigned',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ...data.projects.map(
                    (p) => _buildListItem(
                      theme,
                      title: p.name,
                      subtitle: p.description ?? 'No description',
                      icon: Icons.folder,
                      color: Colors.blue,
                    ),
                  ),
                ],
              );

              // التاسكات
              final tasksList = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(theme, 'Recent Tasks'),
                  if (data.tasks.isEmpty)
                    Text(
                      'No tasks assigned',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ...data.tasks.map(
                    (t) => _buildListItem(
                      theme,
                      title: t,
                      subtitle: 'In Progress',
                      icon: Icons.task,
                      color: Colors.orange,
                    ),
                  ),
                ],
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: isDesktop
                    ? Column(
                        children: [
                          headerAndStats, // الهيدر فوق
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: projectsList), // المشاريع شمال
                              const SizedBox(width: 24),
                              Expanded(child: tasksList), // التاسكات يمين
                            ],
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          headerAndStats, // في الموبايل كله تحت بعضه
                          projectsList,
                          const SizedBox(height: 24),
                          tasksList,
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildListItem(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
