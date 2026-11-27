import 'dart:async';
import 'package:syntrace/features/auth/data/pending_signup_service.dart';
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
import 'package:syntrace/features/auth/presentation/validators/auth_validators.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  bool _isNavigating = false;
  Timer? _timer;
  final _pending = PendingSignupService.instance;

  int _remaining(DateTime? deadline) {
    if (deadline == null) return 0;
    final ms = deadline.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _onVerify() {
    if (_isNavigating) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final cubit = context.read<SignupCubit>();

    if (cubit.state is SignupLoading) return;

    FocusScope.of(context).unfocus();

    cubit.verifyOtp(email: widget.email, otp: _otpController.text.trim());
  }

  void _handleSignupSuccess() {
    if (_isNavigating || !mounted) return;
    setState(() => _isNavigating = true);
    _otpController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created. Sign in to continue.')),
    );
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignupCubit, SignupState>(
      listener: (context, state) {
        if (state is OtpSent) {
          _otpController.clear();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('A new code was sent.')));
        }
        if (state is SignupSuccess) {
          _handleSignupSuccess();
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
                  validator: AuthValidators.otp,
                ),
              ],
            ),
          ),
        ],
        submitButton: BlocBuilder<SignupCubit, SignupState>(
          builder: (context, state) {
            final isLoading = state is SignupLoading || _isNavigating;

            return AuthButton(
              label: 'Verify & Create Account',
              isLoading: isLoading,
              onPressed: isLoading || _remaining(_pending.expiresAt) == 0
                  ? null
                  : _onVerify,
            );
          },
        ),
        footer: BlocBuilder<SignupCubit, SignupState>(
          builder: (context, state) {
            final busy = state is SignupLoading || _isNavigating;
            final wait = _remaining(_pending.resendAt);
            final expiry = _remaining(_pending.expiresAt);
            final hasPending =
                _pending.pendingRequest?.email ==
                widget.email.trim().toLowerCase();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  expiry == 0
                      ? 'Code expired or unavailable'
                      : 'Code expires in ${expiry ~/ 60}:${(expiry % 60).toString().padLeft(2, '0')}',
                ),
                TextButton(
                  onPressed: busy || wait > 0 || !hasPending
                      ? null
                      : () =>
                            context.read<SignupCubit>().resendOtp(widget.email),
                  child: Text(
                    wait > 0 ? 'Resend code in ${wait}s' : 'Resend code',
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          context.read<SignupCubit>().reset();
                          context.go(AppRoutes.signup);
                        },
                  child: const Text('Change email / Go back'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
