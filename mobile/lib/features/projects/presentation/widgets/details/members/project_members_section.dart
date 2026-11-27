import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/shared/widgets/design_system/design_system.dart';

import '../../../../data/models/project_team_member.dart';

import '../../../cubit/members/project_members_cubit.dart';
import '../../../cubit/members/project_members_state.dart';

import 'project_member_tile.dart';
import 'add_project_member_dialog.dart';
import 'change_project_role_dialog.dart';

class ProjectMembersSection extends StatelessWidget {
  final String projectId;

  const ProjectMembersSection({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(projectId),
      create: (_) => ProjectMembersCubit(projectId: projectId)..loadMembers(),
      child: const _ProjectMembersView(),
    );
  }
}

class _ProjectMembersView extends StatelessWidget {
  const _ProjectMembersView();

  bool _canModify(ProjectMembersCubit cubit) {
    return !cubit.isClosed && cubit.canManage && cubit.state.canModify;
  }

  Future<void> _addMember(BuildContext context) async {
    final cubit = context.read<ProjectMembersCubit>();

    if (!_canModify(cubit)) return;

    final member = await AddProjectMemberDialog.show(
      context,
      existingMemberIds: cubit.state.members
          .map((member) => member.employeeId)
          .toSet(),
    );

    if (!context.mounted || member == null || !_canModify(cubit)) {
      return;
    }

    final success = await cubit.addMember(
      employeeId: member.employeeId,
      role: member.role,
    );

    if (!context.mounted || cubit.isClosed) return;

    _showResult(context, cubit, success, 'Member added successfully.');
  }

  Future<void> _changeRole(
    BuildContext context,
    ProjectTeamMember member,
  ) async {
    final cubit = context.read<ProjectMembersCubit>();

    if (!_canModify(cubit)) return;

    final role = await ChangeProjectRoleDialog.show(context, member);

    if (!context.mounted || role == null || !_canModify(cubit)) {
      return;
    }

    final success = await cubit.changeRole(
      employeeId: member.employeeId,
      role: role,
    );

    if (!context.mounted || cubit.isClosed) return;

    _showResult(context, cubit, success, 'Project role updated.');
  }

  Future<void> _removeMember(
    BuildContext context,
    ProjectTeamMember member,
  ) async {
    final cubit = context.read<ProjectMembersCubit>();

    if (!_canModify(cubit)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('Remove member?'),
          content: Text(
            'Remove ${member.name} from this project? '
            'Their company account will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true || !_canModify(cubit)) {
      return;
    }

    final success = await cubit.removeMember(member.employeeId);

    if (!context.mounted || cubit.isClosed) return;

    _showResult(context, cubit, success, 'Member removed from project.');
  }

  void _showResult(
    BuildContext context,
    ProjectMembersCubit cubit,
    bool success,
    String successMessage,
  ) {
    final String message;

    if (success && cubit.state.hasLoaded && !cubit.state.isFromCache) {
      message = successMessage;
    } else if (success) {
      message = 'Change accepted, but the team could not be refreshed.';
    } else {
      message = cubit.state.errorMessage ?? 'Unable to complete the operation.';
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<ProjectMembersCubit, ProjectMembersState>(
      builder: (context, state) {
        final cubit = context.read<ProjectMembersCubit>();

        final canManage = cubit.canManage && state.canModify;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.hasLoaded
                        ? 'Team members (${state.members.length})'
                        : 'Team members',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                if (canManage)
                  TextButton.icon(
                    onPressed: () => _addMember(context),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
                    label: const Text('Add'),
                  ),

                IconButton(
                  tooltip: 'Refresh team',
                  onPressed: state.isBusy ? null : cubit.loadMembers,
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                ),
              ],
            ),

            const SizedBox(height: 4),

            AppCard(
              padding: const EdgeInsets.all(12),
              child: _buildContent(context, state, canManage),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ProjectMembersState state,
    bool canManage,
  ) {
    if (state.isLoading || state.status == ProjectMembersStatus.initial) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (state.hasError) {
      return _MembersFeedback(
        icon: state.isUnavailable
            ? Icons.cloud_off_outlined
            : Icons.error_outline_rounded,
        message: state.errorMessage ?? 'Unable to load project members.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isFromCache) ...[
          _CachedMembersNotice(lastSyncedAt: state.lastSyncedAt),
          const SizedBox(height: 12),
        ],

        if (state.isMutating || state.isRefreshing) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
        ],

        if (state.members.isEmpty)
          _MembersFeedback(
            icon: Icons.group_outlined,
            message: state.isFromCache
                ? 'No members in the last saved team information.'
                : 'No members assigned to this project yet.',
          )
        else
          for (var index = 0; index < state.members.length; index++) ...[
            if (index > 0) const Divider(height: 1),

            ProjectMemberTile(
              key: ValueKey(state.members[index].employeeId),
              member: state.members[index],
              canManage: canManage,
              isBusy: state.isBusy,
              onChangeRole: () => _changeRole(context, state.members[index]),
              onRemove: () => _removeMember(context, state.members[index]),
            ),
          ],
      ],
    );
  }
}

class _CachedMembersNotice extends StatelessWidget {
  final DateTime? lastSyncedAt;

  const _CachedMembersNotice({this.lastSyncedAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final date = lastSyncedAt?.toLocal();

    final localizations = MaterialLocalizations.of(context);

    final lastUpdated = date == null
        ? null
        : '${localizations.formatMediumDate(date)}'
              ' · '
              '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.onSurfaceVariant.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storage_rounded, size: 15, color: colors.onSurfaceVariant),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Showing saved team information',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),

                if (lastUpdated != null) ...[
                  const SizedBox(height: 3),

                  Text(
                    'Last updated: $lastUpdated',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _MembersFeedback extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MembersFeedback({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),

          const SizedBox(width: 10),

          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
