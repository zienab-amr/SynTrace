import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/auth/presentation/cubit/signup_cubit.dart';
import 'package:syntrace/features/auth/presentation/cubit/signup_state.dart';
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
    final currentState = context.read<SignupCubit>().state;
    if (currentState is SignupLoading) return;

    context.read<SignupCubit>().verifyOtp(
      email: widget.email,
      otp: _otpController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignupCubit, SignupState>(
      listener: (context, state) {
        if (state is SignupSuccess) {
          _showSuccess('Account created! Please sign in.');
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) context.go(AppRoutes.login);
          });
        }
        if (state is SignupError) {
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
                    if (value == null || value.isEmpty)
                      return 'OTP is required';
                    if (value.length < 4) return 'Enter the full code';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
        submitButton: BlocBuilder<SignupCubit, SignupState>(
          builder: (context, state) {
            final isLoading = state is SignupLoading;
            return AuthButton(
              label: 'Verify & Create Account',
              isLoading: isLoading,
              onPressed: isLoading ? null : _onVerify,
            );
          },
        ),
        footer: TextButton(
          onPressed: () => context.go(AppRoutes.signup),
          child: const Text("Didn't receive the code? Go back"),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.secondary),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}
