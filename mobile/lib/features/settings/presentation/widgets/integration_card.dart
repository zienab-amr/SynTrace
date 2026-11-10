import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/settings/data/models/integration_model.dart';

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
    final isConnected = integration.status == IntegrationStatus.connected;
    final isConnecting = integration.status == IntegrationStatus.connecting;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildLogo(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        integration.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected
                          ? 'Connected'
                          : (isConnecting ? 'Connecting...' : 'Not connected'),
                      style: TextStyle(
                        color: isConnected
                            ? AppColors.secondary
                            : (isConnecting
                                ? AppColors.warning
                                : theme.colorScheme.onSurface.withOpacity(0.4)),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _buildSubtitle(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildButton(context, isConnected, isConnecting),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    final (icon, color) = switch (integration.type) {
      IntegrationType.jira => (Icons.task_alt, const Color(0xFF0052CC)),
      IntegrationType.github => (Icons.code, const Color(0xFF333333)),
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  String _buildSubtitle() {
    if (integration.status == IntegrationStatus.connected &&
        integration.accountName != null) {
      return integration.accountName!;
    }
    return integration.description;
  }

  Widget _buildButton(
    BuildContext context,
    bool isConnected,
    bool isConnecting,
  ) {
    if (isConnecting) {
      return const SizedBox(
        width: 80,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (isConnected) {
      return SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: onDisconnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Connected',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onConnect,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Connect',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}