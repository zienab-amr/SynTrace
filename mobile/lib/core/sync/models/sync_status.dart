enum SyncStatus {
  initial,
  offline,
  connecting,
  syncing,
  upToDate,
  partiallySynced,
  serverUnavailable,
  sessionExpired,
  failed,
}

extension SyncStatusExtension on SyncStatus {
  bool get isSyncing => this == SyncStatus.syncing;

  bool get isOffline =>
      this == SyncStatus.offline || this == SyncStatus.serverUnavailable;

  String get label {
    return switch (this) {
      SyncStatus.initial => 'Checking connection',
      SyncStatus.offline => 'Offline',
      SyncStatus.connecting => 'Connecting',
      SyncStatus.syncing => 'Syncing',
      SyncStatus.upToDate => 'Up to date',
      SyncStatus.partiallySynced => 'Partially synced',
      SyncStatus.serverUnavailable => 'Server unavailable',
      SyncStatus.sessionExpired => 'Session expired',
      SyncStatus.failed => 'Sync failed',
    };
  }
}
