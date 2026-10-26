import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/settings/data/models/integration_model.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_state.dart';
import 'package:syntrace/features/settings/presentation/widgets/integration_card.dart';

class IntegrationsTab extends StatelessWidget {
  const IntegrationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IntegrationsCubit, IntegrationsState>(
      listener: (context, state) {
        // If there is an error, show a SnackBar at the bottom
        if (state is IntegrationsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is IntegrationsLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        // Safely get the current list from the cubit
        final integrations = context.read<IntegrationsCubit>().current;

        // If the list is empty and we have an error, show a retry button
        if (integrations.isEmpty && state is IntegrationsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Failed to load integrations'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      context.read<IntegrationsCubit>().loadIntegrations(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Render the list normally
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: integrations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final integration = integrations[index];
            return IntegrationCard(
              integration: integration,
              onConnect: () {
                if (integration.type == IntegrationType.jira) {
                  context.read<IntegrationsCubit>().connectJira();
                } else {
                  context.read<IntegrationsCubit>().connect(integration.type);
                }
              },
              onDisconnect: () => context
                  .read<IntegrationsCubit>()
                  .disconnect(integration.type),
            );
          },
        );
      },
    );
  }
}