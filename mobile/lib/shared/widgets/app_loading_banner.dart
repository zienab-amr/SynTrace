import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class AppLoadingBanner extends StatelessWidget {
  final String? message;
  const AppLoadingBanner({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            message ?? 'Loading...',
            style: const TextStyle(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}