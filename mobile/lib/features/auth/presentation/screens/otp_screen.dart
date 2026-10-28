import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/auth/presentation/cubit/login_cubit.dart';
import 'package:syntrace/features/auth/presentation/cubit/login_state.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_button.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_screen_layout.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_text_field.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _onVerify() {
    if (!_formKey.currentState!.validate()) return;

    final currentState = context.read<LoginCubit>().state;
    if (currentState is LoginLoading) return;

    context.read<LoginCubit>().verifyOtp(
          email: widget.email,
          otp: _otpController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginCubit, LoginState>(
      listener: (context, state) {
        if (state is RegisterSuccess) {
          _showSuccess(
            'Account created! Welcome, ${state.registerResponse.email}',
          );
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) context.go(AppRoutes.login);
          });
        }
        if (state is LoginError) {
          _showError(state.message);
        }
      },
      child: AuthScreenLayout(
        title: 'Verify your email',
        subtitle: 'We sent a code to ${widget.email}',
        formFields: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: 'OTP Code',
                  hint: '123456',
                  icon: Icons.lock_clock_outlined,
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'OTP is required';
                    }
                    if (value.length < 4) {
                      return 'Enter the full code';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
        submitButton: BlocBuilder<LoginCubit, LoginState>(
          builder: (context, state) {
            final isLoading = state is LoginLoading;
            return AuthButton(
              label: 'Verify & Create Account',
              isLoading: isLoading,
              onPressed: isLoading ? null : _onVerify,
            );
          },
        ),
        footer: _buildFooter(context),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton(
      onPressed: () => context.go(AppRoutes.signup),
      child: Text(
        "Didn't receive the code? Go back",
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: theme.brightness == Brightness.dark
            ? AppColors.secondary
            : AppColors.secondaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}