import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/core/cache/cache_session.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/features/dashboard/data/models/dashboard_models.dart';
import 'package:syntrace/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:syntrace/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:syntrace/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:syntrace/features/projects/data/models/project_api_model.dart';

// In-memory fixtures are confined to the test suite. No API or storage calls.
const _user = UserModel(
  id: 'test-user',
  name: 'Test Developer',
  email: 'developer@example.test',
  role: UserRole.developer,
  roleNames: ['Developer'],
  tenantId: 'test-tenant',
);

const _freshData = DashboardData(
  projects: [
    ProjectApiModel(
      id: 'test-project',
      name: 'Test project',
      clientId: 'test-client',
      status: ProjectApiStatus.inProgress,
    ),
  ],
);

class _TestDashboardRepository extends DashboardRepository {
  int cacheReads = 0;
  int remoteReads = 0;
  UserModel? requestedUser;
  CancelToken? requestToken;
  final Completer<void> started = Completer<void>();
  final Future<DashboardData> Function()? onLoad;

  _TestDashboardRepository({this.onLoad});

  @override
  Future<DashboardData> readCachedDashboard({required UserModel user}) async {
    cacheReads++;
    return const DashboardData();
  }

  @override
  Future<DashboardData> loadDashboard({
    required UserModel user,
    CancelToken? cancelToken,
  }) async {
    remoteReads++;
    requestedUser = user;
    requestToken = cancelToken;
    if (!started.isCompleted) started.complete();
    return onLoad == null ? _freshData : await onLoad!();
  }
}

void main() {
  final session = CacheSession.instance;
  final current = CurrentUserService.instance;

  void resetSession() {
    session.invalidate();
    current.userNotifier.value = null;
  }

  void activateTestSession() {
    session.activate();
    current.userNotifier.value = _user;
  }

  setUp(resetSession);
  tearDown(resetSession);

  group('DashboardCubit', () {
    test('rejects a missing session without reading data', () async {
      final repository = _TestDashboardRepository();
      final cubit = DashboardCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.loadDashboard();

      expect(
        cubit.state,
        const DashboardError('Your workspace is unavailable.'),
      );
      expect(repository.cacheReads, 0);
      expect(repository.remoteReads, 0);
    });

    test('rejects a blocked session without reading data', () async {
      current.userNotifier.value = _user;
      final repository = _TestDashboardRepository();
      final cubit = DashboardCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.loadDashboard();

      expect(cubit.state, const DashboardError('Your session is unavailable.'));
      expect(repository.cacheReads, 0);
      expect(repository.remoteReads, 0);
    });

    test('loads data and finishes refreshing for an active session', () async {
      activateTestSession();
      final repository = _TestDashboardRepository();
      final cubit = DashboardCubit(repository: repository);
      addTearDown(cubit.close);
      final emissions = expectLater(
        cubit.stream,
        emitsInOrder([
          isA<DashboardLoading>(),
          const DashboardLoaded(data: _freshData, isRefreshing: true),
          const DashboardLoaded(data: _freshData),
        ]),
      );

      await cubit.loadDashboard();
      await emissions;

      expect(repository.cacheReads, 1);
      expect(repository.remoteReads, 1);
      expect(repository.requestedUser, _user);
      final loaded = cubit.state as DashboardLoaded;
      expect(loaded.data.totalProjects, 1);
      expect(loaded.data.activeProjects, 1);
      expect(loaded.data.teamMembersCount, isNull);
      expect(loaded.isRefreshing, isFalse);
      expect(loaded.isFromCache, isFalse);
    });

    test('discards an in-flight result when the session ends', () async {
      activateTestSession();
      final pending = Completer<DashboardData>();
      final repository = _TestDashboardRepository(onLoad: () => pending.future);
      final cubit = DashboardCubit(repository: repository);
      addTearDown(cubit.close);
      final states = <DashboardState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      final loading = cubit.loadDashboard();
      await repository.started.future;
      expect(cubit.state, isA<DashboardLoading>());

      resetSession();
      expect(repository.requestToken?.isCancelled, isTrue);
      expect(cubit.state, isA<DashboardInitial>());

      pending.complete(_freshData);
      await loading;
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<DashboardInitial>());
      expect(states.whereType<DashboardLoaded>(), isEmpty);
    });
  });
}
