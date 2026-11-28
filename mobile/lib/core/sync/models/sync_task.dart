import 'package:dio/dio.dart';
import 'package:syntrace/core/cache/cache_scope.dart';

typedef SyncTaskCallback =
    Future<void> Function(CacheScope scope, CancelToken cancelToken);

class SyncTask {
  final String id;
  final int priority;
  final Duration refreshInterval;
  final SyncTaskCallback execute;

  const SyncTask({
    required this.id,
    required this.execute,
    this.priority = 100,
    this.refreshInterval = const Duration(minutes: 5),
  });
}
