import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class CreateButton extends StatelessWidget {
  const CreateButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        context.push(AppRoutes.createProject);
      },
      icon: const Icon(Icons.add, size: 18),
      label: const Text(
        'New Project',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}