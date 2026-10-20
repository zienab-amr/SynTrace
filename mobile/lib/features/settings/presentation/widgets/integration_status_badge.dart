import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/settings/data/models/integration_model.dart';

class IntegrationStatusBadge extends StatelessWidget
{
  final IntegrationStatus status;

  const IntegrationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context)
  {
    final (color, label) = switch (status)
    {
      IntegrationStatus.connected => (AppColors.secondary, 'Connected'),
      IntegrationStatus.connecting => (AppColors.warning, 'Connecting'),
      IntegrationStatus.disconnected => (AppColors.textMuted, 'Not Connected'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}