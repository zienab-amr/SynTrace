import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';
import '../cubit/github/github_cubit.dart';
import '../cubit/jira/jira_cubit.dart';
import '../widgets/integrations_tab.dart';

class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => JiraCubit()..loadIntegrations()),
      BlocProvider(create: (_) => GitHubCubit()..loadIntegrations()),
    ],
    child: const AppPageScaffold(
      title: 'Integrations',
      subtitle: 'Connect your engineering tools',
      showBackButton: true,
      child: IntegrationsTab(),
    ),
  );
}
