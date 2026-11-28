import 'package:syntrace/core/sync/models/sync_task.dart';

class SyncRegistry {
  final Map<String, SyncTask> _tasks = {};

  void register(SyncTask task) {
    _tasks[task.id] = task;
  }

  void unregister(String id) {
    _tasks.remove(id);
  }

  bool contains(String id) {
    return _tasks.containsKey(id);
  }

  List<SyncTask> get tasks {
    final result = _tasks.values.toList();

    result.sort((a, b) => a.priority.compareTo(b.priority));

    return List.unmodifiable(result);
  }

  bool get isEmpty => _tasks.isEmpty;

  void clear() {
    _tasks.clear();
  }
}
