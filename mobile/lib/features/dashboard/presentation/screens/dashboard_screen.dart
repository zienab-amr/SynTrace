import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/dashboard/data/models/dashboard_models.dart';
import 'package:syntrace/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:syntrace/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardCubit>().loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Dashboard',
      subtitle: 'Welcome back! Here is what is happening today.',
      child: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (state is DashboardLoaded) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ═══ Stats Grid ═══
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.5,
                            children: [
                              _buildStatCard(
                                context, 
                                'Active Projects', 
                                '${state.stats.activeProjects}', 
                                Icons.folder_open, 
                                Colors.blue,
                                onTap: () => context.go(AppRoutes.projects),
                              ),
                              _buildStatCard(
                                context, 
                                'Open Tasks', 
                                '${state.stats.openTasks}', 
                                Icons.task_alt, 
                                Colors.orange,
                                onTap: () => context.go(AppRoutes.tasks),
                              ),
                              _buildStatCard(
                                context, 
                                'Total Commits', 
                                '${state.stats.totalCommits}', 
                                Icons.commit, 
                                Colors.green,
                                onTap: () => context.go(AppRoutes.projects), 
                              ),
                              _buildStatCard(
                                context, 
                                'Team Members', 
                                '${state.stats.teamMembers}', 
                                Icons.people, 
                                Colors.purple,
                                onTap: () => context.go(AppRoutes.team), 
                              ),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // ═══ Recent Activity ═══
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ...state.activities.map((activity) => _buildActivityCard(context, activity)),
                    ],
                  ),
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, 
    String title, 
    String value, 
    IconData icon, 
    Color color, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, RecentActivity activity) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('hh:mm a').format(activity.timestamp);
    
    IconData icon;
    Color color;
    VoidCallback? onTap;

    switch (activity.type) {
      case 'commit':
        icon = Icons.commit;
        color = Colors.green;
        onTap = () => context.go(AppRoutes.projects);
        break;
      case 'meeting':
        icon = Icons.auto_awesome;
        color = Colors.purple;
        onTap = () => context.go(AppRoutes.meetings);
        break;
      case 'task':
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
        onTap = () => context.go(AppRoutes.tasks);
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.blue;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity.title, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(activity.description, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
                  ],
                ),
              ),
              Text(timeStr, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}