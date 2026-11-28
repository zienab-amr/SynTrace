import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/sync/cubit/sync_state.dart';
import 'package:syntrace/core/sync/models/sync_status.dart';

class SyncCubit extends Cubit<SyncState> {
  SyncCubit() : super(const SyncState());

  void updateStatus(SyncStatus status) {
    if (isClosed) return;

    emit(state.copyWith(status: status));
  }

  void startSync(int totalTasks) {
    if (isClosed) return;

    emit(
      state.copyWith(
        status: SyncStatus.syncing,
        totalTasks: totalTasks,
        completedTasks: 0,
        failedTasks: 0,
      ),
    );
  }

  void taskCompleted() {
    if (isClosed || !state.isSyncing) return;

    emit(state.copyWith(completedTasks: state.completedTasks + 1));
  }

  void taskFailed() {
    if (isClosed || !state.isSyncing) return;

    emit(state.copyWith(failedTasks: state.failedTasks + 1));
  }

  void finishSync() {
    if (isClosed || !state.isSyncing) return;

    if (state.totalTasks == 0) {
      updateStatus(SyncStatus.initial);
      return;
    }

    if (state.failedTasks == 0 && state.completedTasks == state.totalTasks) {
      emit(
        state.copyWith(
          status: SyncStatus.upToDate,
          lastSuccessfulSync: DateTime.now().toUtc(),
        ),
      );

      return;
    }

    updateStatus(
      state.completedTasks > 0 ? SyncStatus.partiallySynced : SyncStatus.failed,
    );
  }

  void reset() {
    if (isClosed) return;

    emit(const SyncState());
  }
}
