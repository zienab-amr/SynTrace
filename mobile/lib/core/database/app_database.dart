import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:syntrace/core/database/tables/cached_resources_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [CachedResources])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'syntrace_cache',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.dart.js'),
          ),
        ),
      );

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
      },
    );
  }
}
