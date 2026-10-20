import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/auth/presentation/cubit/login_cubit.dart';
import 'package:syntrace/features/auth/presentation/cubit/login_state.dart';

void main() {
  group('LoginCubit', () {
    late LoginCubit cubit;

    setUp(() {
      cubit = LoginCubit();
    });

    tearDown(() {
      cubit.close();
    });

    // ═══════════════════════════════════════════════════
    // Test 1: Initial
    // ═══════════════════════════════════════════════════
    test('initial state is LoginInitial', () {
      expect(cubit.state, isA<LoginInitial>());
    });

    // ═══════════════════════════════════════════════════
    // Test 2: Reset
    // ═══════════════════════════════════════════════════
    test('reset emits LoginInitial', () {
      cubit.reset();
      expect(cubit.state, isA<LoginInitial>());
    });

    // ═══════════════════════════════════════════════════
    // Test 3: Login Flow (Mock)
    // ═══════════════════════════════════════════════════
    // ملاحظة: الـ Login محتاج Backend — ممكن نعملها لما يجهز.
  });
}