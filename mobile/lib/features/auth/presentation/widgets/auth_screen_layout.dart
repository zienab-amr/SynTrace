import 'package:flutter/material.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_branding_panel.dart';
import 'package:syntrace/features/auth/presentation/widgets/auth_header.dart';

/// ═══════════════════════════════════════════════════════════
/// AuthScreenLayout
/// 
/// Widget(Login + Signup)
/// Layout، Background، Branding Panel، Header
/// ═══════════════════════════════════════════════════════════
class AuthScreenLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> formFields;
  final Widget submitButton;
  final Widget? demoHint;
  final Widget footer;

  const AuthScreenLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formFields,
    required this.submitButton,
    this.demoHint,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: isWide ? _buildWebLayout(context) : _buildMobileLayout(context),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Web Layout — Split
  // ═══════════════════════════════════════════════════════
  Widget _buildWebLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // ═══ Left: Branding ═══
        const Expanded(
          flex: 6,
          child: AuthBrandingPanel(),
        ),

        // ═══ Right: Form ═══
        Expanded(
          flex: 4,
          child: Container(
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildContent(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // Mobile Layout
  // ═══════════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Content (Web , Mobile)
  // ═══════════════════════════════════════════════════════
  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ═══ Header ═══
        AuthHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 40),

        // ═══ Form Fields ═══
        ...formFields,

        const SizedBox(height: 24),

        // ═══ Submit Button ═══
        submitButton,

        // ═══ Demo Hint ═══
        if (demoHint != null) ...[
          const SizedBox(height: 16),
          demoHint!,
        ],

        const SizedBox(height: 24),

        // ═══ Footer ═══
        footer,

        const SizedBox(height: 20),

        // ═══ Security Note ═══
        _buildSecurityNote(context),
      ],
    );
  }

  Widget _buildSecurityNote(BuildContext context) {
    return Text(
      'Enterprise-grade security · SOC 2 Type II',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
        fontSize: 10,
        letterSpacing: 0.3,
      ),
    );
  }
}