import 'package:flutter/material.dart';

import '../../data/models/integration_model.dart';
import 'integration_status_badge.dart';

class IntegrationCard extends StatelessWidget {
  final IntegrationModel integration;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  const IntegrationCard({
    super.key,
    required this.integration,
    this.onConnect,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _IntegrationLogo(type: integration.type),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  integration.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  integration.accountName ?? integration.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 8),

                if (integration.suspended)
                  Text(
                    integration.isFromCache ? 'Suspended · Saved' : 'Suspended',
                    style: theme.textTheme.labelSmall,
                  )
                else
                  IntegrationStatusBadge(
                    status: integration.status,
                    isFromCache: integration.isFromCache,
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          _IntegrationAction(
            integration: integration,
            onConnect: onConnect,
            onDisconnect: onDisconnect,
          ),
        ],
      ),
    );
  }
}

class _IntegrationLogo extends StatelessWidget {
  final IntegrationType type;

  const _IntegrationLogo({required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final (icon, color) = switch (type) {
      IntegrationType.jira => (Icons.task_alt_rounded, const Color(0xFF0052CC)),
      IntegrationType.github => (Icons.code_rounded, colors.onSurface),
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 23),
    );
  }
}

class _IntegrationAction extends StatelessWidget {
  final IntegrationModel integration;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  const _IntegrationAction({
    required this.integration,
    this.onConnect,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (integration.status == IntegrationStatus.connecting) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!integration.canModify) {
      return Tooltip(
        message: 'Connect to verify integration status',
        child: Icon(
          Icons.lock_outline_rounded,
          color: colors.onSurfaceVariant,
          size: 19,
        ),
      );
    }

    if (integration.status == IntegrationStatus.connected) {
      if (onDisconnect == null) {
        return const SizedBox.shrink();
      }
      return OutlinedButton(
        onPressed: onDisconnect,
        child: const Text('Disconnect'),
      );
    }

    return FilledButton(onPressed: onConnect, child: const Text('Connect'));
  }
}
