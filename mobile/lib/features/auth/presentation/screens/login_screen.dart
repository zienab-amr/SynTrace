import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/core/services/session_navigation_service.dart';
import 'package:syntrace/features/auth/presentation/cubit/login_cubit.dart';
import 'package:syntrace/features/auth/presentation/cubit/login_state.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_button.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_demo_hint.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_footer.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_screen_layout.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:syntrace/features/auth/presentation/validators/auth_validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isNavigating = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_isNavigating) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final cubit = context.read<LoginCubit>();

    if (cubit.state is LoginLoading) return;

    FocusScope.of(context).unfocus();

    cubit.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _handleLoginSuccess() async {
    if (_isNavigating || !mounted) return;

    setState(() => _isNavigating = true);

    try {
      final destination = await SessionNavigationService.resolveDestination();

      if (!mounted) return;

      if (destination == AppRoutes.login) {
        _showErrorMessage(context, 'Unable to restore your session.');
        return;
      }

      _passwordController.clear();

      context.go(destination);
    } catch (_) {
      if (!mounted) return;

      _showErrorMessage(context, 'Unable to restore your session.');
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginCubit, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          _handleLoginSuccess();
        }

        if (state is LoginError) {
          _showErrorMessage(context, state.message);
        }
      },
      child: AuthScreenLayout(
        title: 'Welcome back',
        subtitle: 'Sign in to your engineering intelligence workspace',
        formFields: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: 'Work Email',
                  hint: 'you@company.com',
                  icon: Icons.email_outlined,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: AuthValidators.email,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Password',
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  controller: _passwordController,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: AuthValidators.loginPassword,
                ),
                BlocBuilder<LoginCubit, LoginState>(
                  builder: (context, state) => Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: state is LoginLoading || _isNavigating
                          ? null
                          : () {
                              _passwordController.clear();
                              context.go(
                                AppRoutes.forgotPassword,
                                extra: _emailController.text.trim(),
                              );
                            },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        submitButton: BlocBuilder<LoginCubit, LoginState>(
          builder: (context, state) {
            final isLoading = state is LoginLoading || _isNavigating;

            return AuthButton(
              label: 'Sign in to SynTrace',
              isLoading: isLoading,
              onPressed: isLoading ? null : _onLogin,
            );
          },
        ),
        demoHint: const AuthDemoHint(
          message: 'Sign in with your registered email and password.',
        ),
        footer: AuthFooter(
          question: "Don't have an account?",
          actionLabel: 'Sign Up',
          onAction: () {
            if (_isNavigating ||
                context.read<LoginCubit>().state is LoginLoading) {
              return;
            }

            context.go(AppRoutes.signup);
          },
        ),
      ),
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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
