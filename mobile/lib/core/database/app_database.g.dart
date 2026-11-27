// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedResourcesTable extends CachedResources
    with TableInfo<$CachedResourcesTable, CachedResource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedResourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceTypeMeta = const VerificationMeta(
    'resourceType',
  );
  @override
  late final GeneratedColumn<String> resourceType = GeneratedColumn<String>(
    'resource_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceKeyMeta = const VerificationMeta(
    'resourceKey',
  );
  @override
  late final GeneratedColumn<String> resourceKey = GeneratedColumn<String>(
    'resource_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadVersionMeta = const VerificationMeta(
    'payloadVersion',
  );
  @override
  late final GeneratedColumn<int> payloadVersion = GeneratedColumn<int>(
    'payload_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tenantId,
    userId,
    resourceType,
    resourceKey,
    payload,
    payloadVersion,
    syncedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_resources';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedResource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('resource_type')) {
      context.handle(
        _resourceTypeMeta,
        resourceType.isAcceptableOrUnknown(
          data['resource_type']!,
          _resourceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resourceTypeMeta);
    }
    if (data.containsKey('resource_key')) {
      context.handle(
        _resourceKeyMeta,
        resourceKey.isAcceptableOrUnknown(
          data['resource_key']!,
          _resourceKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resourceKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('payload_version')) {
      context.handle(
        _payloadVersionMeta,
        payloadVersion.isAcceptableOrUnknown(
          data['payload_version']!,
          _payloadVersionMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    tenantId,
    userId,
    resourceType,
    resourceKey,
  };
  @override
  CachedResource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedResource(
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      resourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_type'],
      )!,
      resourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      payloadVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_version'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
    );
  }

  @override
  $CachedResourcesTable createAlias(String alias) {
    return $CachedResourcesTable(attachedDatabase, alias);
  }
}

class CachedResource extends DataClass implements Insertable<CachedResource> {
  final String tenantId;
  final String userId;
  final String resourceType;
  final String resourceKey;
  final String payload;
  final int payloadVersion;
  final DateTime syncedAt;
  final DateTime? expiresAt;
  const CachedResource({
    required this.tenantId,
    required this.userId,
    required this.resourceType,
    required this.resourceKey,
    required this.payload,
    required this.payloadVersion,
    required this.syncedAt,
    this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tenant_id'] = Variable<String>(tenantId);
    map['user_id'] = Variable<String>(userId);
    map['resource_type'] = Variable<String>(resourceType);
    map['resource_key'] = Variable<String>(resourceKey);
    map['payload'] = Variable<String>(payload);
    map['payload_version'] = Variable<int>(payloadVersion);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    return map;
  }

  CachedResourcesCompanion toCompanion(bool nullToAbsent) {
    return CachedResourcesCompanion(
      tenantId: Value(tenantId),
      userId: Value(userId),
      resourceType: Value(resourceType),
      resourceKey: Value(resourceKey),
      payload: Value(payload),
      payloadVersion: Value(payloadVersion),
      syncedAt: Value(syncedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory CachedResource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedResource(
      tenantId: serializer.fromJson<String>(json['tenantId']),
      userId: serializer.fromJson<String>(json['userId']),
      resourceType: serializer.fromJson<String>(json['resourceType']),
      resourceKey: serializer.fromJson<String>(json['resourceKey']),
      payload: serializer.fromJson<String>(json['payload']),
      payloadVersion: serializer.fromJson<int>(json['payloadVersion']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tenantId': serializer.toJson<String>(tenantId),
      'userId': serializer.toJson<String>(userId),
      'resourceType': serializer.toJson<String>(resourceType),
      'resourceKey': serializer.toJson<String>(resourceKey),
      'payload': serializer.toJson<String>(payload),
      'payloadVersion': serializer.toJson<int>(payloadVersion),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
    };
  }

  CachedResource copyWith({
    String? tenantId,
    String? userId,
    String? resourceType,
    String? resourceKey,
    String? payload,
    int? payloadVersion,
    DateTime? syncedAt,
    Value<DateTime?> expiresAt = const Value.absent(),
  }) => CachedResource(
    tenantId: tenantId ?? this.tenantId,
    userId: userId ?? this.userId,
    resourceType: resourceType ?? this.resourceType,
    resourceKey: resourceKey ?? this.resourceKey,
    payload: payload ?? this.payload,
    payloadVersion: payloadVersion ?? this.payloadVersion,
    syncedAt: syncedAt ?? this.syncedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
  );
  CachedResource copyWithCompanion(CachedResourcesCompanion data) {
    return CachedResource(
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      userId: data.userId.present ? data.userId.value : this.userId,
      resourceType: data.resourceType.present
          ? data.resourceType.value
          : this.resourceType,
      resourceKey: data.resourceKey.present
          ? data.resourceKey.value
          : this.resourceKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      payloadVersion: data.payloadVersion.present
          ? data.payloadVersion.value
          : this.payloadVersion,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedResource(')
          ..write('tenantId: $tenantId, ')
          ..write('userId: $userId, ')
          ..write('resourceType: $resourceType, ')
          ..write('resourceKey: $resourceKey, ')
          ..write('payload: $payload, ')
          ..write('payloadVersion: $payloadVersion, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tenantId,
    userId,
    resourceType,
    resourceKey,
    payload,
    payloadVersion,
    syncedAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedResource &&
          other.tenantId == this.tenantId &&
          other.userId == this.userId &&
          other.resourceType == this.resourceType &&
          other.resourceKey == this.resourceKey &&
          other.payload == this.payload &&
          other.payloadVersion == this.payloadVersion &&
          other.syncedAt == this.syncedAt &&
          other.expiresAt == this.expiresAt);
}

class CachedResourcesCompanion extends UpdateCompanion<CachedResource> {
  final Value<String> tenantId;
  final Value<String> userId;
  final Value<String> resourceType;
  final Value<String> resourceKey;
  final Value<String> payload;
  final Value<int> payloadVersion;
  final Value<DateTime> syncedAt;
  final Value<DateTime?> expiresAt;
  final Value<int> rowid;
  const CachedResourcesCompanion({
    this.tenantId = const Value.absent(),
    this.userId = const Value.absent(),
    this.resourceType = const Value.absent(),
    this.resourceKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.payloadVersion = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedResourcesCompanion.insert({
    required String tenantId,
    required String userId,
    required String resourceType,
    required String resourceKey,
    required String payload,
    this.payloadVersion = const Value.absent(),
    required DateTime syncedAt,
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tenantId = Value(tenantId),
       userId = Value(userId),
       resourceType = Value(resourceType),
       resourceKey = Value(resourceKey),
       payload = Value(payload),
       syncedAt = Value(syncedAt);
  static Insertable<CachedResource> custom({
    Expression<String>? tenantId,
    Expression<String>? userId,
    Expression<String>? resourceType,
    Expression<String>? resourceKey,
    Expression<String>? payload,
    Expression<int>? payloadVersion,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tenantId != null) 'tenant_id': tenantId,
      if (userId != null) 'user_id': userId,
      if (resourceType != null) 'resource_type': resourceType,
      if (resourceKey != null) 'resource_key': resourceKey,
      if (payload != null) 'payload': payload,
      if (payloadVersion != null) 'payload_version': payloadVersion,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedResourcesCompanion copyWith({
    Value<String>? tenantId,
    Value<String>? userId,
    Value<String>? resourceType,
    Value<String>? resourceKey,
    Value<String>? payload,
    Value<int>? payloadVersion,
    Value<DateTime>? syncedAt,
    Value<DateTime?>? expiresAt,
    Value<int>? rowid,
  }) {
    return CachedResourcesCompanion(
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      resourceType: resourceType ?? this.resourceType,
      resourceKey: resourceKey ?? this.resourceKey,
      payload: payload ?? this.payload,
      payloadVersion: payloadVersion ?? this.payloadVersion,
      syncedAt: syncedAt ?? this.syncedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (resourceType.present) {
      map['resource_type'] = Variable<String>(resourceType.value);
    }
    if (resourceKey.present) {
      map['resource_key'] = Variable<String>(resourceKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (payloadVersion.present) {
      map['payload_version'] = Variable<int>(payloadVersion.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedResourcesCompanion(')
          ..write('tenantId: $tenantId, ')
          ..write('userId: $userId, ')
          ..write('resourceType: $resourceType, ')
          ..write('resourceKey: $resourceKey, ')
          ..write('payload: $payload, ')
          ..write('payloadVersion: $payloadVersion, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedResourcesTable cachedResources = $CachedResourcesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedResources];
}

typedef $$CachedResourcesTableCreateCompanionBuilder =
    CachedResourcesCompanion Function({
      required String tenantId,
      required String userId,
      required String resourceType,
      required String resourceKey,
      required String payload,
      Value<int> payloadVersion,
      required DateTime syncedAt,
      Value<DateTime?> expiresAt,
      Value<int> rowid,
    });
typedef $$CachedResourcesTableUpdateCompanionBuilder =
    CachedResourcesCompanion Function({
      Value<String> tenantId,
      Value<String> userId,
      Value<String> resourceType,
      Value<String> resourceKey,
      Value<String> payload,
      Value<int> payloadVersion,
      Value<DateTime> syncedAt,
      Value<DateTime?> expiresAt,
      Value<int> rowid,
    });

class $$CachedResourcesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedResourcesTable> {
  $$CachedResourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceType => $composableBuilder(
    column: $table.resourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceKey => $composableBuilder(
    column: $table.resourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedResourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedResourcesTable> {
  $$CachedResourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceType => $composableBuilder(
    column: $table.resourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceKey => $composableBuilder(
    column: $table.resourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedResourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedResourcesTable> {
  $$CachedResourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get resourceType => $composableBuilder(
    column: $table.resourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resourceKey => $composableBuilder(
    column: $table.resourceKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$CachedResourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedResourcesTable,
          CachedResource,
          $$CachedResourcesTableFilterComposer,
          $$CachedResourcesTableOrderingComposer,
          $$CachedResourcesTableAnnotationComposer,
          $$CachedResourcesTableCreateCompanionBuilder,
          $$CachedResourcesTableUpdateCompanionBuilder,
          (
            CachedResource,
            BaseReferences<
              _$AppDatabase,
              $CachedResourcesTable,
              CachedResource
            >,
          ),
          CachedResource,
          PrefetchHooks Function()
        > {
  $$CachedResourcesTableTableManager(
    _$AppDatabase db,
    $CachedResourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedResourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedResourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedResourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tenantId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> resourceType = const Value.absent(),
                Value<String> resourceKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> payloadVersion = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedResourcesCompanion(
                tenantId: tenantId,
                userId: userId,
                resourceType: resourceType,
                resourceKey: resourceKey,
                payload: payload,
                payloadVersion: payloadVersion,
                syncedAt: syncedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tenantId,
                required String userId,
                required String resourceType,
                required String resourceKey,
                required String payload,
                Value<int> payloadVersion = const Value.absent(),
                required DateTime syncedAt,
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedResourcesCompanion.insert(
                tenantId: tenantId,
                userId: userId,
                resourceType: resourceType,
                resourceKey: resourceKey,
                payload: payload,
                payloadVersion: payloadVersion,
                syncedAt: syncedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedResourcesTable, CachedResource>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedResourcesTable,
                    CachedResource
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedResourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedResourcesTable,
      CachedResource,
      $$CachedResourcesTableFilterComposer,
      $$CachedResourcesTableOrderingComposer,
      $$CachedResourcesTableAnnotationComposer,
      $$CachedResourcesTableCreateCompanionBuilder,
      $$CachedResourcesTableUpdateCompanionBuilder,
      (
        CachedResource,
        BaseReferences<_$AppDatabase, $CachedResourcesTable, CachedResource>,
      ),
      CachedResource,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedResourcesTableTableManager get cachedResources =>
      $$CachedResourcesTableTableManager(_db, _db.cachedResources);
}
