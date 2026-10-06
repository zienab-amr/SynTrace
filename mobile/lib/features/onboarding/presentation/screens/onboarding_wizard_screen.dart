import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';
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
  final _pageController = PageController();
  int _lastStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OnboardingCubit>().start();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingInProgress) {
          if (_lastStep != state.currentStep && _pageController.hasClients) {
            _lastStep = state.currentStep;
            _pageController.animateToPage(
              state.currentStep,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        }

        if (state is OnboardingCompleted) {
          context.go(AppRoutes.dashboard);
        }
      },
      builder: (context, state) {
        if (state is! OnboardingInProgress) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Stack(
            children: [
              // ═══════ 1. Background (نفس الـ Splash) ═══════
              const Positioned.fill(
                child: Opacity(
                  opacity: 0.35,
                  child: SplashBackground(),
                ),
              ),

              // ═══════ 2. Vignette ═══════
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          theme.scaffoldBackgroundColor.withOpacity(0.0),
                          theme.scaffoldBackgroundColor.withOpacity(0.7),
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // ═══════ 3. Content ═══════
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        // ─── Pages ───
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            physics: const PageScrollPhysics(),
                            onPageChanged: (index) {
                              if (index > _lastStep) {
                                if (!state.canGoNext) {
                                  _pageController.animateToPage(
                                    _lastStep,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                  return;
                                }
                              }
                              _lastStep = index;
                              context.read<OnboardingCubit>().goToStep(index);
                            },
                            children: [
                              const _StepWrapper(child: WelcomeStep()),
                              _StepWrapper(
                                child: OrganizationInfoStep(
                                  organizationName: state.data.organizationName,
                                  industry: state.data.industry,
                                  customIndustry: state.data.customIndustry,
                                  teamSize: state.data.teamSize,
                                  onNameChanged: (v) => context
                                      .read<OnboardingCubit>()
                                      .updateOrganizationName(v),
                                  onIndustryChanged: (v) => context
                                      .read<OnboardingCubit>()
                                      .updateIndustry(v),
                                  onCustomIndustryChanged: (v) => context
                                      .read<OnboardingCubit>()
                                      .updateCustomIndustry(v),
                                  onTeamSizeChanged: (v) => context
                                      .read<OnboardingCubit>()
                                      .updateTeamSize(v),
                                ),
                              ),
                              _StepWrapper(
                                child: TeamSetupStep(
                                  emails: state.data.teamEmails,
                                  onAdd: (e) => context
                                      .read<OnboardingCubit>()
                                      .addTeamEmail(e),
                                  onRemove: (e) => context
                                      .read<OnboardingCubit>()
                                      .removeTeamEmail(e),
                                ),
                              ),
                              _StepWrapper(
                                child: PreferencesStep(
                                  isDarkMode: state.data.isDarkMode,
                                  notificationsEnabled:
                                      state.data.notificationsEnabled,
                                  onDarkModeChanged: (v) => context
                                      .read<OnboardingCubit>()
                                      .updateDarkMode(v),
                                  onNotificationsChanged: (v) => context
                                      .read<OnboardingCubit>()
                                      .updateNotifications(v),
                                ),
                              ),
                              _StepWrapper(
                                child: FinishStep(data: state.data),
                              ),
                            ],
                          ),
                        ),

                        // ─── Progress ───
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: OnboardingProgress(
                            currentStep: state.currentStep,
                            totalSteps: OnboardingInProgress.totalSteps,
                          ),
                        ),

                        // ─── Navigation ───
                        OnboardingNavigation(
                          canGoBack: !state.isFirstStep,
                          canGoNext: state.canGoNext,
                          isLastStep: state.isLastStep,
                          onBack: () =>
                              context.read<OnboardingCubit>().previousStep(),
                          onNext: () =>
                              context.read<OnboardingCubit>().nextStep(),
                          onSkip: state.currentStep == 2
                              ? () =>
                                  context.read<OnboardingCubit>().nextStep()
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Step Wrapper
// ═══════════════════════════════════════════════════════════
class _StepWrapper extends StatelessWidget {
  final Widget child;

  const _StepWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: child,
          ),
        ),
      ),
    );
  }
}