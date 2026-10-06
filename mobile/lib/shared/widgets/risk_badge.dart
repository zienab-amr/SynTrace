import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

enum RiskLevel { high, medium, low }

class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  final String? label;

  const RiskBadge({
    super.key,
    required this.level,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final (color, defaultLabel) = switch (level) {
      RiskLevel.high => (AppColors.error, 'High Risk'),
      RiskLevel.medium => (AppColors.warning, 'Medium Risk'),
      RiskLevel.low => (AppColors.secondary, 'Low Risk'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label ?? defaultLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}