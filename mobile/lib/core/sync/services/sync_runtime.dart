import 'package:syntrace/core/sync/cubit/sync_cubit.dart';
import 'package:syntrace/core/sync/models/sync_task.dart';
import 'package:syntrace/core/sync/models/sync_trigger.dart';
import 'package:syntrace/core/sync/services/connectivity_service.dart';
import 'package:syntrace/core/sync/services/sync_manager.dart';
import 'package:syntrace/core/sync/services/sync_registry.dart';

class SyncRuntime {
  SyncRuntime._();

  static final SyncRuntime instance = SyncRuntime._();

  final SyncCubit cubit = SyncCubit();

  final SyncRegistry registry = SyncRegistry();

  final ConnectivityService connectivity = ConnectivityService();

  late final SyncManager manager = SyncManager(
    connectivity: connectivity,
    registry: registry,
    cubit: cubit,
  );

  void register(SyncTask task) {
    registry.register(task);
  }

  void unregister(String id) {
    registry.unregister(id);
  }

  void initialize() {
    manager.start();
  }

  void onSessionChanged() {
    manager.onSessionChanged();
  }

  Future<void> refresh() {
    return manager.requestSync(SyncTrigger.manualRefresh);
  }

  Future<void> onRealtimeUpdate() {
    return manager.requestSync(SyncTrigger.realtimeUpdate);
  }

  Future<void> dispose() async {
    await manager.dispose();

    registry.clear();

    await cubit.close();
  }
}
