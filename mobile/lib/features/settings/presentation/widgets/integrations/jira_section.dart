import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/jira/jira_cubit.dart';
import '../../cubit/jira/jira_state.dart';
import '../../../data/models/integration_model.dart';
import '../integration_card.dart';

class JiraSection extends StatelessWidget {
  const JiraSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<JiraCubit, JiraState>(
      listener: (context, state) {
        if (state is JiraError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final cubit = context.read<JiraCubit>();
        if (state is JiraLoading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final current = cubit.current;
        if (current.isEmpty) {
          return TextButton(
            onPressed: cubit.loadIntegrations,
            child: const Text('Load Jira status'),
          );
        }
        final integration = current.single;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntegrationCard(
              integration: integration,
              onConnect: integration.canModify
                  ? () => cubit.connectJira()
                  : null,
              onDisconnect: integration.canModify && cubit.isAdmin
                  ? cubit.disconnectJira
                  : null,
            ),
            if (integration.status == IntegrationStatus.unknown ||
                integration.isFromCache ||
                integration.status == IntegrationStatus.connecting)
              TextButton(
                onPressed: cubit.refresh,
                child: const Text('Refresh Jira status'),
              ),
          ],
        );
      },
    );
  }
}
