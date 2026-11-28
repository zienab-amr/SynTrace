import 'package:syntrace/core/cache/cache_scope.dart';

class CacheSession {
  CacheSession._();

  static final instance = CacheSession._();

  int _generation = 0;
  bool _blocked = true;

  int get generation => _generation;

  bool get isBlocked => _blocked;

  void activate() {
    _generation++;
    _blocked = false;
  }

  void invalidate() {
    _generation++;
    _blocked = true;
  }

  bool isValid({required CacheScope scope, required int generation}) {
    return !_blocked && generation == _generation && scope.isCurrentSession;
  }
}
