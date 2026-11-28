import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import '../cubit/forgot_password_cubit.dart';
import '../cubit/forgot_password_state.dart';
import '../validators/auth_validators.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_footer.dart';
import '../widgets/auth_screen_layout.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit(ForgotPasswordState state) {
    if (state.busy || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final cubit = context.read<ForgotPasswordCubit>();
    if (state.email == null) {
      cubit.sendCode(_email.text);
    } else {
      cubit.reset(
        otp: _otp.text,
        password: _password.text,
        confirmation: _confirmation.text,
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
    listener: (context, state) {
      if (state.message != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
      }
      if (state.completed) {
        _otp.clear();
        _password.clear();
        _confirmation.clear();
        context.go(AppRoutes.login);
      }
    },
    builder: (context, state) {
      final resetting = state.email != null;
      final remaining =
          state.resendAt?.difference(DateTime.now()).inMilliseconds ?? 0;
      final seconds = remaining > 0 ? (remaining / 1000).ceil() : 0;
      return AuthScreenLayout(
        title: resetting ? 'Reset password' : 'Forgot password?',
        subtitle: resetting
            ? 'Enter the code requested for ${state.email} and choose a new password.'
            : 'Enter your registered work email to request a reset code.',
        formFields: [
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!resetting)
                  AuthTextField(
                    label: 'Work Email',
                    hint: 'you@company.com',
                    icon: Icons.email_outlined,
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: AuthValidators.email,
                  ),
                if (resetting) ...[
                  AuthTextField(
                    label: 'Verification code',
                    hint: '000000',
                    icon: Icons.lock_outline,
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    validator: AuthValidators.otp,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: 'New password',
                    hint: 'Enter new password',
                    icon: Icons.lock_outline,
                    controller: _password,
                    isPassword: true,
                    validator: AuthValidators.signupPassword,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: 'Confirm password',
                    hint: 'Repeat new password',
                    icon: Icons.lock_outline,
                    controller: _confirmation,
                    isPassword: true,
                    validator: (value) => value == _password.text
                        ? AuthValidators.signupPassword(value)
                        : 'Passwords do not match',
                  ),
                  TextButton(
                    onPressed: state.busy || seconds > 0
                        ? null
                        : () {
                            _otp.clear();
                            context.read<ForgotPasswordCubit>().sendCode(
                              state.email!,
                            );
                          },
                    child: Text(
                      seconds > 0
                          ? 'Resend code in ${seconds}s'
                          : 'Resend code',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        submitButton: AuthButton(
          label: resetting
              ? 'Reset password'
              : seconds > 0
              ? 'Try again in ${seconds}s'
              : 'Send reset code',
          isLoading: state.busy,
          onPressed: state.busy || (!resetting && seconds > 0)
              ? null
              : () => _submit(state),
        ),
        footer: AuthFooter(
          question: 'Remember your password?',
          actionLabel: 'Back to sign in',
          onAction: () {
            if (!state.busy) context.go(AppRoutes.login);
          },
        ),
      );
    },
  );
}
