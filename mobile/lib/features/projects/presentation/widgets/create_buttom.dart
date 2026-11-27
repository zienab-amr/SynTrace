import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/shared/widgets/design_system/design_system.dart';

import '../cubit/projects_cubit.dart';

class CreateButton extends StatelessWidget {
  const CreateButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'New Project',
      icon: Icons.add_rounded,
      fullWidth: false,
      onPressed: () async {
        final created = await context.push<bool>(AppRoutes.createProject);

        if (!context.mounted) return;

        if (created == true) {
          await context.read<ProjectsCubit>().refresh();
        }
      },
    );
  }
}
