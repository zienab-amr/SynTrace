import 'package:flutter/material.dart';

class ProjectWizardProgress extends StatelessWidget {
  final int currentStep;

  const ProjectWizardProgress({super.key, required this.currentStep});

  static const _steps = ['Details', 'Team', 'Integrations', 'Review'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            Expanded(
              child: _WizardStep(
                index: i,
                label: _steps[i],
                isActive: i == currentStep,
                isCompleted: i < currentStep,
              ),
            ),
            if (i < _steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(top: 17),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 12,
                  height: 2,
                  color: i < currentStep
                      ? scheme.primary
                      : scheme.outlineVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _WizardStep extends StatelessWidget {
  final int index;
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _WizardStep({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final highlighted = isActive || isCompleted;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlighted ? scheme.primary : scheme.surfaceContainerHigh,
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? Icon(Icons.check_rounded, color: scheme.onPrimary, size: 20)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: highlighted
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
