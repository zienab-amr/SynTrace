import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

import '../../data/models/integration_model.dart';

class IntegrationStatusBadge extends StatelessWidget {
  final IntegrationStatus status;
  final bool isFromCache;

  const IntegrationStatusBadge({
    super.key,
    required this.status,
    this.isFromCache = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (color, label) = switch (status) {
      IntegrationStatus.connected => (AppColors.secondary, 'Connected'),
      IntegrationStatus.connecting => (AppColors.warning, 'Connecting'),
      IntegrationStatus.disconnected => (
        theme.colorScheme.onSurfaceVariant,
        'Not connected',
      ),
      IntegrationStatus.unknown => (
        theme.colorScheme.onSurfaceVariant,
        'Not verified',
      ),
    };

    final displayColor = isFromCache
        ? theme.colorScheme.onSurfaceVariant
        : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFromCache)
            Icon(Icons.storage_rounded, size: 11, color: displayColor)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: displayColor,
                shape: BoxShape.circle,
              ),
            ),

          const SizedBox(width: 6),

          Text(
            isFromCache ? '$label · Saved' : label,
            style: TextStyle(
              color: displayColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
