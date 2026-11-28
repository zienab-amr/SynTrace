import 'dart:async';

class CacheOperationLock {
  CacheOperationLock._();

  static final instance = CacheOperationLock._();

  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) async {
    final previous = _tail;
    final completer = Completer<void>();

    _tail = completer.future;

    await previous;

    try {
      return await operation();
    } finally {
      completer.complete();
    }
  }
}
