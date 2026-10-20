import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_state.dart';
import 'package:syntrace/features/settings/presentation/widgets/integration_card.dart';
import 'package:syntrace/shared/widgets/error_state_view.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class IntegrationsScreen extends StatefulWidget
{
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen>
{
  @override
  void initState() {
    super.initState();
    context.read<IntegrationsCubit>().loadIntegrations();
  }

  @override
  Widget build(BuildContext context)
  {
    return AppPageScaffold(
      title: 'Integrations',
      subtitle: 'Connect your engineering tools',
      showBackButton: true,
      child: BlocBuilder<IntegrationsCubit, IntegrationsState>(
        builder: (context, state) {
          if (state is IntegrationsLoading)
          {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is IntegrationsError)
          {
            return ErrorStateView(
              message: state.message,
              onRetry: () =>
                  context.read<IntegrationsCubit>().loadIntegrations(),
            );
          }

          if (state is IntegrationsLoaded)
          {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.integrations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final integration = state.integrations[index];
                return IntegrationCard(
                  integration: integration,
                  onConnect: () => context
                      .read<IntegrationsCubit>()
                      .connect(integration.type),
                  onDisconnect: () => context
                      .read<IntegrationsCubit>()
                      .disconnect(integration.type),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}