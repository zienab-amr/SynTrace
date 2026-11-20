import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:syntrace/features/dashboard/presentation/cubit/dashboard_state.dart';

void main() {
  group('DashboardCubit', () {
    blocTest<DashboardCubit, DashboardState>(
      'loadDashboard emits [Loading, Loaded]',
      build: () => DashboardCubit(),
      act: (cubit) => cubit.loadDashboard(),
      wait: const Duration(milliseconds: 1000), // بنستنى الـ Timer بتاع الكيوبت
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardLoaded>(),
      ],
    );
  });
}