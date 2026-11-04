import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:syntrace/features/onboarding/presentation/cubit/onboarding_state.dart';

void main() {
  group('OnboardingCubit', () {
    test('start initializes at step 0', () {
      final cubit = OnboardingCubit();
      cubit.start();
      expect(cubit.state, isA<OnboardingInProgress>());
      expect((cubit.state as OnboardingInProgress).currentStep, 0);
    });

    test('updateOrganizationName updates data', () {
      final cubit = OnboardingCubit();
      cubit.start();
      cubit.updateOrganizationName('SynTrace');
      final state = cubit.state as OnboardingInProgress;
      expect(state.data.organizationName, 'SynTrace');
    });

    test('addTeamMember adds to list', () {
      final cubit = OnboardingCubit();
      cubit.start();
      cubit.addTeamMember({'firstName': 'X', 'email': 'x@x.com'});
      final state = cubit.state as OnboardingInProgress;
      expect(state.data.teamMembers.length, 1);
    });
  });
}