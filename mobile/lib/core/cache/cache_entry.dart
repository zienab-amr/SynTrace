class CacheEntry<T> {
  final T data;
  final DateTime syncedAt;
  final DateTime? expiresAt;
  final bool isStale;

  const CacheEntry({
    required this.data,
    required this.syncedAt,
    required this.isStale,
    this.expiresAt,
  });

  Duration get age {
    final duration = DateTime.now().toUtc().difference(syncedAt.toUtc());

    return duration.isNegative ? Duration.zero : duration;
  }

  bool get isExpired {
    final expiration = expiresAt;

    if (expiration == null) return false;

    return !DateTime.now().toUtc().isBefore(expiration.toUtc());
  }
}
