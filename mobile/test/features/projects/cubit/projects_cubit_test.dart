import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/features/projects/presentation/cubit/projects_cubit.dart';
import 'package:syntrace/features/projects/presentation/cubit/projects_state.dart';

void main() {
  group('ProjectsCubit', () {
    late ProjectsCubit cubit;

    setUp(() {
      cubit = ProjectsCubit();
    });

    tearDown(() {
      cubit.close();
    });

    // ═══════════════════════════════════════════════════
    // Test 1: Initial
    // ═══════════════════════════════════════════════════
    test('initial state is ProjectsInitial', () {
      expect(cubit.state, isA<ProjectsInitial>());
    });

    // ═══════════════════════════════════════════════════
    // Test 2: Load Projects
    // ═══════════════════════════════════════════════════
    blocTest<ProjectsCubit, ProjectsState>(
      'emits [Loading, Loaded] when loadProjects is called',
      build: () => ProjectsCubit(),
      act: (cubit) => cubit.loadProjects(),
      expect: () => [
        isA<ProjectsLoading>(),
        isA<ProjectsLoaded>(),
      ],
      wait: const Duration(milliseconds: 500),
    );

    // ═══════════════════════════════════════════════════
    // Test 3: Search
    // ═══════════════════════════════════════════════════
    blocTest<ProjectsCubit, ProjectsState>(
      'search filters projects',
      build: () => ProjectsCubit(),
      act: (cubit) async {
        await cubit.loadProjects();
        cubit.search('ERP');
      },
      wait: const Duration(milliseconds: 500),
      verify: (cubit) {
        final state = cubit.state;
        expect(state, isA<ProjectsLoaded>());

        final loaded = state as ProjectsLoaded;
        expect(loaded.searchQuery, 'ERP');
      },
    );

    // ═══════════════════════════════════════════════════
    // Test 4: Clear Filters
    // ═══════════════════════════════════════════════════
    blocTest<ProjectsCubit, ProjectsState>(
      'clearFilters resets search and filters',
      build: () => ProjectsCubit(),
      act: (cubit) async {
        await cubit.loadProjects();
        cubit.search('ERP');
        cubit.clearFilters();
      },
      wait: const Duration(milliseconds: 500),
      verify: (cubit) {
        final state = cubit.state;
        expect(state, isA<ProjectsLoaded>());

        final loaded = state as ProjectsLoaded;
        expect(loaded.searchQuery, isEmpty);
        expect(loaded.hasActiveFilters, false);
      },
    );
  });
}