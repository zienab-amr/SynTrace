import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syntrace/core/theme/app_icons.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;

  final TextEditingController? controller;
  final FocusNode? focusNode;

  final IconData? prefixIcon;
  final Widget? suffix;

  final bool isPassword;
  final bool enabled;
  final bool readOnly;
  final bool requiredField;
  final bool autofocus;

  final int maxLines;
  final int? maxLength;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.prefixIcon,
    this.suffix,
    this.isPassword = false,
    this.enabled = true,
    this.readOnly = false,
    this.requiredField = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.autofillHints,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: widget.label,
            children: [
              if (widget.requiredField)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: colors.error),
                ),
            ],
          ),
          style: context.appText.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          obscureText: widget.isPassword && _obscureText,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: widget.inputFormatters,
          autofillHints: widget.autofillHints,
          autocorrect: !widget.isPassword,
          enableSuggestions: !widget.isPassword,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: context.appText.bodyMedium,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helperText,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscureText ? 'Show password' : 'Hide password',
                    onPressed: widget.enabled
                        ? () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          }
                        : null,
                    icon: Icon(
                      _obscureText ? AppIcons.eye : AppIcons.eyeOff,
                      size: 20,
                    ),
                  )
                : widget.suffix,
          ),
        ),
      ],
    );
  }
}
