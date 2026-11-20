import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/auth/presentation/cubit/signup_cubit.dart';
import 'package:syntrace/features/auth/presentation/cubit/signup_state.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_button.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_footer.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_screen_layout.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _phoneController = TextEditingController(); // ضفنا التليفون
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _companyController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSignup() {
    if (!_formKey.currentState!.validate()) return;

    final currentState = context.read<SignupCubit>().state;
    if (currentState is SignupLoading) return;

    if (!_agreedToTerms) {
      _showError('Please accept the Terms & Conditions');
      return;
    }

    context.read<SignupCubit>().sendOtp(
      companyName: _companyController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(), // ═══ Trim + Lowercase
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignupCubit, SignupState>(
      listener: (context, state) {
        if (state is OtpSent) {
          _showSuccess('OTP sent to ${state.email}');
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              context.go(AppRoutes.verifyOtp, extra: state.email);
            }
          });
        }

        if (state is EmailAlreadyExists) {
          _showEmailExistsDialog(context, state.email);
        }

        if (state is SignupError) {
          _showError(state.message);
        }
      },
      child: AuthScreenLayout(
        title: 'Create account',
        subtitle: 'Sign up to get started with SynTrace',
        formFields: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: 'Company Name',
                  hint: 'Acme Corp',
                  icon: Icons.business_outlined,
                  controller: _companyController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Company name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'First Name',
                  hint: 'John',
                  icon: Icons.person_outline,
                  controller: _firstNameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'First name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Last Name',
                  hint: 'Doe',
                  icon: Icons.person_outline,
                  controller: _lastNameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Last name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Phone Number',
                  hint: '+20 123 456 7890',
                  icon: Icons.phone_outlined,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Phone number is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Work Email',
                  hint: 'you@company.com',
                  icon: Icons.email_outlined,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Email is required';
                    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(value))
                      return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Password',
                  hint: 'At least 6 characters',
                  icon: Icons.lock_outline,
                  controller: _passwordController,
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Password is required';
                    if (value.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Confirm Password',
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  controller: _confirmController,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Confirm your password';
                    if (value != _passwordController.text)
                      return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildTermsCheckbox(context),
        ],
        submitButton: BlocBuilder<SignupCubit, SignupState>(
          builder: (context, state) {
            final isLoading = state is SignupLoading;
            return AuthButton(
              label: 'Create Account',
              isLoading: isLoading,
              onPressed: isLoading ? null : _onSignup,
            );
          },
        ),
        footer: AuthFooter(
          question: 'Already have an account?',
          actionLabel: 'Sign In',
          onAction: () => context.go(AppRoutes.login),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (value) =>
                setState(() => _agreedToTerms = value ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            side: BorderSide(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12.5,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showEmailExistsDialog(BuildContext context, String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.info_outline, color: AppColors.warning, size: 22),
              SizedBox(width: 10),
              Text('Email Already Registered'),
            ],
          ),
          content: Text(
            'The email "$email" is already registered.\n\nPlease sign in instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Use Different Email'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go(AppRoutes.login);
              },
              child: const Text('Sign In'),
            ),
          ],
        );
      },
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
