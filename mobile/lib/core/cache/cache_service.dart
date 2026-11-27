import 'package:syntrace/core/cache/cache_repository.dart';
import 'package:syntrace/core/database/app_database.dart';
import 'package:syntrace/core/database/daos/cache_dao.dart';

class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  AppDatabase? _database;
  CacheRepository? _repository;

  bool get isInitialized => _database != null;

  CacheRepository get repository {
    final repository = _repository;

    if (repository == null) {
      throw StateError('CacheService has not been initialized.');
    }

    return repository;
  }

  Future<void> initialize() async {
    if (isInitialized) return;

    final database = AppDatabase();
    final dao = CacheDao(database);

    try {
      await dao.deleteExpired();

      _database = database;

      _repository = CacheRepository(dao: dao);
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  Future<void> dispose() async {
    final database = _database;

    _repository = null;
    _database = null;

    await database?.close();
  }
}
