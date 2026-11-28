import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session.dart';

class CacheSessionGuard {
  final CacheScope scope;
  final int generation;

  const CacheSessionGuard._({required this.scope, required this.generation});

  factory CacheSessionGuard.capture(CacheScope scope) {
    final guard = CacheSessionGuard._(
      scope: scope,
      generation: CacheSession.instance.generation,
    );

    guard.ensureValid();

    return guard;
  }

  bool get isValid {
    return CacheSession.instance.isValid(scope: scope, generation: generation);
  }

  void ensureValid() {
    if (!isValid) {
      throw StateError('The cache session is no longer active.');
    }
  }
}
