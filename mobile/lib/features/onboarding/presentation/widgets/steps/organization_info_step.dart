import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/onboarding/data/onboarding_data.dart';

class OrganizationInfoStep extends StatefulWidget {
  final String organizationName;
  final String industry;
  final String customIndustry;
  final String teamSize;
  final void Function(String) onNameChanged;
  final void Function(String) onIndustryChanged;
  final void Function(String) onCustomIndustryChanged;
  final void Function(String) onTeamSizeChanged;

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
  State<OrganizationInfoStep> createState() => _OrganizationInfoStepState();
}

class _OrganizationInfoStepState extends State<OrganizationInfoStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _customIndustryController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.organizationName);
    _customIndustryController =
        TextEditingController(text: widget.customIndustry);
  }

  @override
  void didUpdateWidget(covariant OrganizationInfoStep oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ─── Sync Name ───
    if (widget.organizationName != _nameController.text) {
      final selection = _nameController.selection;
      _nameController.text = widget.organizationName;
      if (selection.start <= _nameController.text.length) {
        _nameController.selection = selection;
      } else {
        _nameController.selection = TextSelection.fromPosition(
          TextPosition(offset: _nameController.text.length),
        );
      }
    }

    // ─── Sync Custom Industry ───
    if (widget.customIndustry != _customIndustryController.text) {
      final selection = _customIndustryController.selection;
      _customIndustryController.text = widget.customIndustry;
      if (selection.start <= _customIndustryController.text.length) {
        _customIndustryController.selection = selection;
      } else {
        _customIndustryController.selection = TextSelection.fromPosition(
          TextPosition(offset: _customIndustryController.text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customIndustryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCustomIndustry = widget.industry == 'Other';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tell us about your\norganization',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us personalize your experience.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),

        // ─── Organization Name ───
        _buildLabel('Organization Name', theme),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          onChanged: widget.onNameChanged,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: _inputDecoration(
            hint: 'e.g., Acme Corp',
            icon: Icons.business_outlined,
            theme: theme,
          ),
        ),

        const SizedBox(height: 20),

        // ─── Industry ───
        _buildLabel('Industry', theme),
        const SizedBox(height: 8),
        _buildDropdown(
          value: widget.industry,
          items: OnboardingOptions.industries,
          hint: 'Select your industry',
          onChanged: widget.onIndustryChanged,
          theme: theme,
        ),

        // ─── Custom Industry ───
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: showCustomIndustry
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _customIndustryController,
                    onChanged: widget.onCustomIndustryChanged,
                    autofocus: true,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: _inputDecoration(
                      hint: 'Type your industry',
                      icon: Icons.edit_outlined,
                      theme: theme,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 20),

        // ─── Team Size ───
        _buildLabel('Team Size', theme),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: OnboardingOptions.teamSizes.map((size) {
            final isSelected = widget.teamSize == size;
            return _TeamSizeChip(
              label: size,
              isSelected: isSelected,
              onTap: () => widget.onTeamSizeChanged(size),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required ThemeData theme,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurface.withOpacity(0.3),
      ),
      prefixIcon: Icon(
        icon,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
        size: 20,
      ),
      filled: true,
      fillColor: theme.colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String hint,
    required ValueChanged<String> onChanged,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
          dropdownColor: theme.colorScheme.surface,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _TeamSizeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TeamSizeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}