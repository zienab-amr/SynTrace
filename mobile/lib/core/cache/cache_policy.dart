class CachePolicy {
  final Duration refreshAfter;
  final Duration maxOfflineAge;

  const CachePolicy({required this.refreshAfter, required this.maxOfflineAge});

  bool needsRefresh(DateTime syncedAt, {DateTime? now}) {
    final current = now ?? DateTime.now().toUtc();

    return current.isBefore(syncedAt.toUtc()) ||
        !current.isBefore(syncedAt.toUtc().add(refreshAfter));
  }

  bool canReadOffline(DateTime syncedAt, {DateTime? now}) {
    final current = now ?? DateTime.now().toUtc();

    return !current.isBefore(syncedAt.toUtc()) &&
        current.isBefore(syncedAt.toUtc().add(maxOfflineAge));
  }

  static const profile = CachePolicy(
    refreshAfter: Duration(minutes: 15),
    maxOfflineAge: Duration(hours: 24),
  );

  static const projects = CachePolicy(
    refreshAfter: Duration(minutes: 5),
    maxOfflineAge: Duration(hours: 24),
  );

  static const team = CachePolicy(
    refreshAfter: Duration(minutes: 10),
    maxOfflineAge: Duration(hours: 24),
  );

  static const activity = CachePolicy(
    refreshAfter: Duration(minutes: 2),
    maxOfflineAge: Duration(hours: 24),
  );

  static const conversations = CachePolicy(
    refreshAfter: Duration(minutes: 5),
    maxOfflineAge: Duration(hours: 24),
  );
}
