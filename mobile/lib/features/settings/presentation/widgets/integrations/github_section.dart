import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/github/github_cubit.dart';
import '../../cubit/github/github_state.dart';
import '../../../data/models/integration_model.dart';
import '../integration_card.dart';

class GitHubSection extends StatelessWidget {
  const GitHubSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GitHubCubit, GitHubState>(
      listener: (context, state) {
        if (state is GitHubError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final cubit = context.read<GitHubCubit>();
        if (state is GitHubLoading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final current = cubit.current;
        if (current.isEmpty) {
          return TextButton(
            onPressed: cubit.loadIntegrations,
            child: const Text('Load GitHub status'),
          );
        }
        final integration = current.single;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntegrationCard(
              integration: integration,
              onConnect: integration.canModify
                  ? () => cubit.connectGitHub()
                  : null,
              onDisconnect: integration.canModify
                  ? cubit.disconnectGitHub
                  : null,
            ),
            if (integration.status == IntegrationStatus.unknown ||
                integration.isFromCache ||
                integration.status == IntegrationStatus.connecting)
              TextButton(
                onPressed: cubit.refresh,
                child: const Text('Refresh GitHub status'),
              ),
          ],
        );
      },
    );
  }
}
