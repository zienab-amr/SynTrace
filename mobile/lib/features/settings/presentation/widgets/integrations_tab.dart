import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/github/github_cubit.dart';
import '../cubit/jira/jira_cubit.dart';
import 'integrations/github_section.dart';
import 'integrations/jira_section.dart';

class IntegrationsTab extends StatelessWidget {
  const IntegrationsTab({super.key});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      await Future.wait([
        context.read<JiraCubit>().refresh(),
        context.read<GitHubCubit>().refresh(),
      ]);
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [JiraSection(), SizedBox(height: 12), GitHubSection()],
    ),
  );
}
