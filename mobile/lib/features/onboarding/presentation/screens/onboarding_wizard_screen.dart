import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/cache/cache_operation_lock.dart';
import 'package:syntrace/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:syntrace/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:syntrace/features/onboarding/presentation/widgets/onboarding_navigation.dart';
import 'package:syntrace/features/onboarding/presentation/widgets/onboarding_progress.dart';
import 'package:syntrace/features/onboarding/presentation/widgets/steps/finish_step.dart';
import 'package:syntrace/features/onboarding/presentation/widgets/steps/organization_info_step.dart';
import 'package:syntrace/features/onboarding/presentation/widgets/steps/preferences_step.dart';
import 'package:syntrace/features/onboarding/presentation/widgets/steps/team_setup_step.dart';
import 'package:syntrace/features/onboarding/presentation/widgets/steps/welcome_step.dart';
import 'package:syntrace/features/splash/presentation/widgets/network_background.dart';

class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (CurrentUserService.instance.user?.isAdmin == true) {
        context.read<OnboardingCubit>().start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (CurrentUserService.instance.user?.isAdmin != true) {
      return const _MemberWelcome();
    }
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) {
          context.go(AppRoutes.dashboard);
        }

        if (state is OnboardingError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
              ),
            );
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);

        return PopScope(
          canPop: state is! OnboardingLoading,
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(opacity: 0.35, child: SplashBackground()),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: state is OnboardingInProgress
                          ? _WizardContent(state: state)
                          : const _WizardLoading(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WizardContent extends StatelessWidget {
  final OnboardingInProgress state;

  const _WizardContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();

    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.025, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: SizedBox.expand(
              key: ValueKey(state.currentStep),
              child: _buildStep(context),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: OnboardingProgress(
            currentStep: state.currentStep,
            totalSteps: OnboardingInProgress.totalSteps,
          ),
        ),
        OnboardingNavigation(
          canGoBack: !state.isFirstStep,
          canGoNext: state.canGoNext,
          isLastStep: state.isLastStep,
          onBack: cubit.previousStep,
          onNext: cubit.nextStep,
          onSkip: state.currentStep == 2 && state.data.teamMembers.isEmpty
              ? cubit.nextStep
              : null,
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final data = state.data;

    switch (state.currentStep) {
      case 0:
        return const _CenteredStep(child: WelcomeStep());

      case 1:
        return _CenteredStep(
          child: OrganizationInfoStep(
            organizationName: data.organizationName,
            industry: data.industry,
            customIndustry: data.customIndustry,
            teamSize: data.teamSize,
            onNameChanged: cubit.updateOrganizationName,
            onIndustryChanged: cubit.updateIndustry,
            onCustomIndustryChanged: cubit.updateCustomIndustry,
            onTeamSizeChanged: cubit.updateTeamSize,
          ),
        );

      case 2:
        return TeamSetupStep(
          teamMembers: data.teamMembers,
          onAdd: cubit.addTeamMember,
          onRemove: cubit.removeTeamMember,
        );

      case 3:
        return PreferencesStep(
          isDarkMode: data.isDarkMode,
          notificationsEnabled: data.notificationsEnabled,
          onDarkModeChanged: cubit.updateDarkMode,
          onNotificationsChanged: cubit.updateNotifications,
        );

      case 4:
        return FinishStep(data: data);

      default:
        return const SizedBox.shrink();
    }
  }
}

class _CenteredStep extends StatelessWidget {
  final Widget child;

  const _CenteredStep({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: child,
        ),
      ),
    );
  }
}

class _WizardLoading extends StatelessWidget {
  const _WizardLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Preparing your workspace...',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('Please wait a moment.', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MemberWelcome extends StatefulWidget {
  const _MemberWelcome();

  @override
  State<_MemberWelcome> createState() => _MemberWelcomeState();
}

class _MemberWelcomeState extends State<_MemberWelcome> {
  bool _saving = false;

  Future<void> _finish() async {
    if (_saving) return;
    final scope = CacheScope.fromCurrentUser();
    if (scope == null) return;
    setState(() => _saving = true);
    try {
      final guard = CacheSessionGuard.capture(scope);
      await CacheOperationLock.instance.run(() async {
        guard.ensureValid();
        await SecureStorageService.instance.saveOnboardingCompleted(true);
        guard.ensureValid();
      });
      if (mounted && guard.isValid) context.go(AppRoutes.dashboard);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to complete setup. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.hub_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to SynTrace',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Explore your assigned projects, connect your work and ask the assistant. Your workspace access is managed by your administrator.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _saving ? null : _finish,
                    child: Text(_saving ? 'Finishing…' : 'Get started'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
