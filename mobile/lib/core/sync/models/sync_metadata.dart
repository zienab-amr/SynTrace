class SyncMetadata {
  final DateTime? lastSuccessfulSync;
  final DateTime? lastAttempt;
  final int consecutiveFailures;

  const SyncMetadata({
    this.lastSuccessfulSync,
    this.lastAttempt,
    this.consecutiveFailures = 0,
  });

  SyncMetadata markAttempt() {
    return SyncMetadata(
      lastSuccessfulSync: lastSuccessfulSync,
      lastAttempt: DateTime.now().toUtc(),
      consecutiveFailures: consecutiveFailures,
    );
  }

  SyncMetadata markSuccess() {
    final now = DateTime.now().toUtc();

    return SyncMetadata(
      lastSuccessfulSync: now,
      lastAttempt: now,
      consecutiveFailures: 0,
    );
  }

  SyncMetadata markFailure() {
    return SyncMetadata(
      lastSuccessfulSync: lastSuccessfulSync,
      lastAttempt: DateTime.now().toUtc(),
      consecutiveFailures: consecutiveFailures + 1,
    );
  }
}
