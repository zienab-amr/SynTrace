import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/features/employees/presentation/cubit/employees_cubit.dart';
import 'package:syntrace/features/employees/presentation/screens/employees_screen.dart';

import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

import '../../data/models/dashboard_models.dart';

class DashboardWorkspaceSummary extends StatelessWidget {
  final DashboardData data;
  final bool isAdmin;

  const DashboardWorkspaceSummary({
    super.key,
    required this.data,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final jiraCount = data.projects
        ?.where((project) => project.hasJiraProject)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Metric(
                label: 'Projects',
                value: data.totalProjects,
                onTap: () => context.go(AppRoutes.projects),
              ),
            ),
            _divider(colors.border),
            Expanded(
              child: _Metric(
                label: 'Jira linked',
                value: jiraCount,
                onTap: () => context.go(AppRoutes.projects),
              ),
            ),
            if (isAdmin) ...[
              _divider(colors.border),
              Expanded(
                child: _Metric(
                  label: 'Members',
                  value: data.teamMembersCount,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider(
                        create: (_) => EmployeesCubit(),
                        child: const AllEmployeesScreen(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (data.hasProjectsError || (isAdmin && data.hasTeamError)) ...[
          const SizedBox(height: 10),
          Text(
            'Some workspace data is unavailable.',
            style: context.appText.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _divider(Color color) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      color: color,
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int? value;
  final VoidCallback onTap;

  const _Metric({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = context.appText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value?.toString() ?? '—',
                style: text.headlineMedium?.copyWith(
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: text.bodySmall?.copyWith(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
