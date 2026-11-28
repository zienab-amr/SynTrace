import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/cache/cache_session.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import 'package:syntrace/features/settings/data/models/github_model.dart';

import 'package:syntrace/shared/widgets/design_system/design_system.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

import '../../data/models/project_api_model.dart';
import '../../data/models/project_team_member.dart';

import '../cubit/create_project_cubit.dart';
import '../cubit/create_project_state.dart';
import '../cubit/project_setup_cubit.dart';
import '../cubit/project_setup_state.dart';

import '../widgets/create_project/create_client_dialog.dart';
import '../widgets/create_project/create_project_feedback.dart';
import '../widgets/create_project/project_details_form.dart';
import '../widgets/create_project/project_wizard_progress.dart';
import '../widgets/create_project/project_team_step.dart';
import '../widgets/create_project/project_integrations_step.dart';
import '../widgets/create_project/project_review_step.dart';
import '../widgets/create_project/project_creation_result.dart';

part 'create_project_view.dart';
part 'create_project_validation.dart';
part 'create_project_content.dart';
part 'project_submitting_view.dart';

class CreateProjectScreen extends StatelessWidget {
  const CreateProjectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        if (user?.role != UserRole.admin ||
            user?.tenantId?.isNotEmpty != true) {
          return AppPageScaffold(
            title: 'Create project',
            showBackButton: true,
            child: CreateProjectFeedback(
              icon: Icons.lock_outline_rounded,
              title: 'Access restricted',
              message: 'Only workspace administrators can create projects.',
              actionLabel: 'Back to projects',
              onAction: () {
                context.go(AppRoutes.projects);
              },
            ),
          );
        }

        return MultiBlocProvider(
          key: ValueKey(
            '${user!.tenantId}:${user.id}:${CacheSession.instance.generation}',
          ),
          providers: [
            BlocProvider(create: (_) => CreateProjectCubit()..loadClients()),
            BlocProvider(create: (_) => ProjectSetupCubit()),
          ],
          child: const _CreateProjectView(),
        );
      },
    );
  }
}
