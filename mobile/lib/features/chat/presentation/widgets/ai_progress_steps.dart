import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/chat/data/models/chat_message.dart';

class AiProgressSteps extends StatelessWidget {
  final List<ProgressStep> steps;

  const AiProgressSteps({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.map((step) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _buildIcon(step),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    step.label,
                    style: TextStyle(
                      color: step.isDone
                          ? theme.colorScheme.onSurface.withOpacity(0.6)
                          : theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: step.isDone
                          ? FontWeight.normal
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIcon(ProgressStep step) {
    if (step.isDone) {
      return const Icon(
        Icons.check,
        color: AppColors.secondary,
        size: 14,
      );
    }
    return const SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        color: AppColors.primary,
      ),
    );
  }
}