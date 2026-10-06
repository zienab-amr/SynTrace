import 'package:syntrace/core/state/base_state.dart';
import 'package:syntrace/features/onboarding/data/onboarding_data.dart';

abstract class OnboardingState extends BaseState {
  const OnboardingState();
}

class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

class OnboardingInProgress extends OnboardingState {
  final int currentStep;
  final OnboardingData data;
  final bool canGoNext;

  const OnboardingInProgress({
    required this.currentStep,
    required this.data,
    this.canGoNext = false,
  });

  static const totalSteps = 5;

  bool get isFirstStep => currentStep == 0;
  bool get isLastStep => currentStep == totalSteps - 1;

  double get progress => (currentStep + 1) / totalSteps;

  OnboardingInProgress copyWith({
    int? currentStep,
    OnboardingData? data,
    bool? canGoNext,
  }) {
    return OnboardingInProgress(
      currentStep: currentStep ?? this.currentStep,
      data: data ?? this.data,
      canGoNext: canGoNext ?? this.canGoNext,
    );
  }

  @override
  List<Object?> get props => [currentStep, data, canGoNext];
}

class OnboardingCompleted extends OnboardingState {
  final OnboardingData data;
  const OnboardingCompleted(this.data);

  @override
  List<Object?> get props => [data];
}