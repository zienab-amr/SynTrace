import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_workspace_map.dart';
import '../widgets/dashboard_workspace_summary.dart';
import '../widgets/dashboard_projects_section.dart';
import '../widgets/dashboard_feedback.dart';

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
    final colors = context.appColors;

    return ColoredBox(
      color: colors.canvas,
      child: ValueListenableBuilder<UserModel?>(
        valueListenable: CurrentUserService.instance.userNotifier,
        builder: (context, user, _) {
          if (user == null) {
            return const Center(
              child: DashboardFeedback(
                icon: Icons.lock_outline,
                message: 'Your workspace is unavailable.',
              ),
            );
          }

          return BlocBuilder<DashboardCubit, DashboardState>(
            builder: (context, state) {
              return _DashboardContent(
                user: user,
                state: state,
                onRefresh: context.read<DashboardCubit>().refresh,
              );
            },
          );
        },
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final UserModel user;
  final DashboardState state;
  final Future<void> Function() onRefresh;

  const _DashboardContent({
    required this.user,
    required this.state,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardHeader(
                      name: user.name,
                      companyName: user.companyName,
                    ),

                    const SizedBox(height: 24),

                    if (state is DashboardLoaded)
                      _buildLoaded(context, state as DashboardLoaded)
                    else if (state is DashboardError)
                      _buildError(context, state as DashboardError)
                    else
                      const _DashboardLoadingView(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, DashboardLoaded loaded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loaded.isRefreshing) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
        ],

        if (loaded.isFromCache &&
            (loaded.data.projects != null ||
                loaded.data.teamMembersCount != null)) ...[
          const Text('Workspace may include saved data · Pull to refresh'),
          const SizedBox(height: 12),
        ],

        DashboardWorkspaceMap(projectCount: loaded.data.totalProjects),

        const SizedBox(height: 20),

        DashboardWorkspaceSummary(data: loaded.data, isAdmin: user.isAdmin),

        const SizedBox(height: 18),

        const Divider(height: 1),

        const SizedBox(height: 14),

        DashboardProjectsSection(
          data: loaded.data,
          isAdmin: user.isAdmin,
          onRetry: onRefresh,
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, DashboardError error) {
    return Column(
      children: [
        const DashboardWorkspaceMap(projectCount: null),

        const SizedBox(height: 16),

        DashboardFeedback(
          icon: Icons.cloud_off_outlined,
          message: error.message,
          actionLabel: 'Try again',
          onAction: onRefresh,
        ),
      ],
    );
  }
}

class _DashboardLoadingView extends StatelessWidget {
  const _DashboardLoadingView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        Container(
          height: 260,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: const Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Row(
          children: List.generate(
            3,
            (index) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _placeholder(colors.surfaceMuted, 38, 24),
                    const SizedBox(height: 8),
                    _placeholder(colors.surfaceMuted, 55, 7),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(Color color, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
