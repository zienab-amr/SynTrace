import 'package:syntrace/features/projects/data/project_clients_repository.dart';
import 'package:syntrace/features/employees/data/employees_repository.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/sync/models/sync_task.dart';
import 'package:syntrace/core/sync/services/sync_runtime.dart';

import 'package:syntrace/features/projects/data/services/projects_sync_service.dart';
import 'package:syntrace/features/dashboard/data/services/dashboard_sync_service.dart';

class SyncTaskRegistration {
  SyncTaskRegistration._();

  static void registerAll() {
    final runtime = SyncRuntime.instance;
    runtime.register(
      SyncTask(
        id: 'clients_directory',
        priority: 12,
        refreshInterval: const Duration(minutes: 5),
        execute: (scope, cancelToken) => ProjectClientsRepository().syncClients(
          scope,
          cancelToken: cancelToken,
        ),
      ),
    );
    runtime.register(
      SyncTask(
        id: 'employees_directory',
        priority: 15,
        refreshInterval: const Duration(minutes: 10),
        execute: (scope, cancelToken) async {
          if (CurrentUserService.instance.user?.isAdmin != true) return;
          final result = await EmployeesRepository().getAllEmployees(
            allowCache: false,
            cancelToken: cancelToken,
          );
          if (!result.success) throw StateError('Employee sync failed.');
        },
      ),
    );

    runtime.register(
      SyncTask(
        id: 'projects',
        priority: 10,
        refreshInterval: const Duration(minutes: 5),
        execute: (scope, cancelToken) async {
          await ProjectsSyncService.instance.refresh(
            scope: scope,
            cancelToken: cancelToken,
          );
        },
      ),
    );

    runtime.register(
      SyncTask(
        id: 'dashboard_team_count',
        priority: 20,
        refreshInterval: const Duration(minutes: 10),
        execute: (scope, cancelToken) async {
          final user = CurrentUserService.instance.user;

          if (user?.isAdmin != true) return;

          await DashboardSyncService.instance.refreshTeamCount(
            scope: scope,
            cancelToken: cancelToken,
          );
        },
      ),
    );
  }
}
