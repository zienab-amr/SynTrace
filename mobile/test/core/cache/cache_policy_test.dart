import 'package:flutter_test/flutter_test.dart';
import 'package:syntrace/core/cache/cache_policy.dart';

void main() {
  const policy = CachePolicy.projects;
  final synced = DateTime.utc(2026, 11, 27, 12);
  test('fresh snapshot can be read', () {
    final now = synced.add(const Duration(minutes: 4));
    expect(policy.canReadOffline(synced, now: now), isTrue);
    expect(policy.needsRefresh(synced, now: now), isFalse);
  });
  test('refresh boundary is inclusive', () {
    final now = synced.add(const Duration(minutes: 5));
    expect(policy.needsRefresh(synced, now: now), isTrue);
    expect(policy.canReadOffline(synced, now: now), isTrue);
  });
  test('offline limit is exclusive', () {
    expect(
      policy.canReadOffline(synced, now: synced.add(const Duration(hours: 24))),
      isFalse,
    );
  });
  test('future timestamps are rejected', () {
    final now = synced.subtract(const Duration(seconds: 1));
    expect(policy.canReadOffline(synced, now: now), isFalse);
    expect(policy.needsRefresh(synced, now: now), isTrue);
  });
  test('last second before expiry is readable', () {
    expect(
      policy.canReadOffline(
        synced,
        now: synced.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      ),
      isTrue,
    );
  });
}
