import 'package:flutter/material.dart';

class OrganizationInfoStep extends StatelessWidget {
  final String organizationName;
  final String industry;
  final String customIndustry;
  final String teamSize;

  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onIndustryChanged;
  final ValueChanged<String> onCustomIndustryChanged;
  final ValueChanged<String> onTeamSizeChanged;

  const OrganizationInfoStep({
    super.key,
    required this.organizationName,
    required this.industry,
    required this.customIndustry,
    required this.teamSize,
    required this.onNameChanged,
    required this.onIndustryChanged,
    required this.onCustomIndustryChanged,
    required this.onTeamSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hasOrganization = organizationName.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Your workspace', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Review the organization connected to your account.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.business_outlined,
                  color: scheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 20),
              Text('ORGANIZATION', style: theme.textTheme.labelSmall),
              const SizedBox(height: 6),
              Text(
                hasOrganization
                    ? organizationName
                    : 'Organization name unavailable',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                hasOrganization
                    ? 'This workspace is linked to your account.'
                    : 'Your organization name could not be loaded.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You can manage your team and workspace '
                'from the application after setup.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
