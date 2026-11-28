import 'package:equatable/equatable.dart';
import 'package:syntrace/core/sync/models/sync_status.dart';

class SyncState extends Equatable {
  final SyncStatus status;
  final DateTime? lastSuccessfulSync;
  final int totalTasks;
  final int completedTasks;
  final int failedTasks;

  const SyncState({
    this.status = SyncStatus.initial,
    this.lastSuccessfulSync,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.failedTasks = 0,
  });

  double get progress {
    if (totalTasks == 0) return 0;

    return ((completedTasks + failedTasks) / totalTasks)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  bool get isSyncing => status == SyncStatus.syncing;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSuccessfulSync,
    int? totalTasks,
    int? completedTasks,
    int? failedTasks,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSuccessfulSync: lastSuccessfulSync ?? this.lastSuccessfulSync,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      failedTasks: failedTasks ?? this.failedTasks,
    );
  }

  @override
  List<Object?> get props => [
    status,
    lastSuccessfulSync,
    totalTasks,
    completedTasks,
    failedTasks,
  ];
}
