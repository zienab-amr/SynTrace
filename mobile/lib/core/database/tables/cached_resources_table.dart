import 'package:drift/drift.dart';

@DataClassName('CachedResource')
class CachedResources extends Table {
  TextColumn get tenantId => text()();

  TextColumn get userId => text()();

  TextColumn get resourceType => text()();

  TextColumn get resourceKey => text()();

  TextColumn get payload => text()();

  IntColumn get payloadVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get syncedAt => dateTime()();

  DateTimeColumn get expiresAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {tenantId, userId, resourceType, resourceKey};
}
