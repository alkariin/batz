// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $JournalEntriesTable extends JournalEntries with TableInfo<$JournalEntriesTable, JournalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [hlc, entity, recordId, field, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal';
  @override
  VerificationContext validateIntegrity(Insertable<JournalRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hlc')) {
      context.handle(_hlcMeta, hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta));
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(_entityMeta, entity.isAcceptableOrUnknown(data['entity']!, _entityMeta));
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta, recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(_fieldMeta, field.isAcceptableOrUnknown(data['field']!, _fieldMeta));
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hlc, entity, recordId, field};
  @override
  JournalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalRow(
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      entity: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}entity'])!,
      recordId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      field: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}field'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $JournalEntriesTable createAlias(String alias) {
    return $JournalEntriesTable(attachedDatabase, alias);
  }
}

class JournalRow extends DataClass implements Insertable<JournalRow> {
  /// Encoded [Hlc]: sorts in time order, and names the device.
  final String hlc;
  final String entity;
  final String recordId;
  final String field;

  /// JSON-encoded value.
  final String value;
  const JournalRow({
    required this.hlc,
    required this.entity,
    required this.recordId,
    required this.field,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hlc'] = Variable<String>(hlc);
    map['entity'] = Variable<String>(entity);
    map['record_id'] = Variable<String>(recordId);
    map['field'] = Variable<String>(field);
    map['value'] = Variable<String>(value);
    return map;
  }

  JournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return JournalEntriesCompanion(
      hlc: Value(hlc),
      entity: Value(entity),
      recordId: Value(recordId),
      field: Value(field),
      value: Value(value),
    );
  }

  factory JournalRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalRow(
      hlc: serializer.fromJson<String>(json['hlc']),
      entity: serializer.fromJson<String>(json['entity']),
      recordId: serializer.fromJson<String>(json['recordId']),
      field: serializer.fromJson<String>(json['field']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hlc': serializer.toJson<String>(hlc),
      'entity': serializer.toJson<String>(entity),
      'recordId': serializer.toJson<String>(recordId),
      'field': serializer.toJson<String>(field),
      'value': serializer.toJson<String>(value),
    };
  }

  JournalRow copyWith({String? hlc, String? entity, String? recordId, String? field, String? value}) => JournalRow(
    hlc: hlc ?? this.hlc,
    entity: entity ?? this.entity,
    recordId: recordId ?? this.recordId,
    field: field ?? this.field,
    value: value ?? this.value,
  );
  JournalRow copyWithCompanion(JournalEntriesCompanion data) {
    return JournalRow(
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      entity: data.entity.present ? data.entity.value : this.entity,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      field: data.field.present ? data.field.value : this.field,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalRow(')
          ..write('hlc: $hlc, ')
          ..write('entity: $entity, ')
          ..write('recordId: $recordId, ')
          ..write('field: $field, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(hlc, entity, recordId, field, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalRow &&
          other.hlc == this.hlc &&
          other.entity == this.entity &&
          other.recordId == this.recordId &&
          other.field == this.field &&
          other.value == this.value);
}

class JournalEntriesCompanion extends UpdateCompanion<JournalRow> {
  final Value<String> hlc;
  final Value<String> entity;
  final Value<String> recordId;
  final Value<String> field;
  final Value<String> value;
  final Value<int> rowid;
  const JournalEntriesCompanion({
    this.hlc = const Value.absent(),
    this.entity = const Value.absent(),
    this.recordId = const Value.absent(),
    this.field = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEntriesCompanion.insert({
    required String hlc,
    required String entity,
    required String recordId,
    required String field,
    required String value,
    this.rowid = const Value.absent(),
  }) : hlc = Value(hlc),
       entity = Value(entity),
       recordId = Value(recordId),
       field = Value(field),
       value = Value(value);
  static Insertable<JournalRow> custom({
    Expression<String>? hlc,
    Expression<String>? entity,
    Expression<String>? recordId,
    Expression<String>? field,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hlc != null) 'hlc': hlc,
      if (entity != null) 'entity': entity,
      if (recordId != null) 'record_id': recordId,
      if (field != null) 'field': field,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEntriesCompanion copyWith({
    Value<String>? hlc,
    Value<String>? entity,
    Value<String>? recordId,
    Value<String>? field,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return JournalEntriesCompanion(
      hlc: hlc ?? this.hlc,
      entity: entity ?? this.entity,
      recordId: recordId ?? this.recordId,
      field: field ?? this.field,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntriesCompanion(')
          ..write('hlc: $hlc, ')
          ..write('entity: $entity, ')
          ..write('recordId: $recordId, ')
          ..write('field: $field, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FieldVersionsTable extends FieldVersions with TableInfo<$FieldVersionsTable, FieldVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FieldVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entity, recordId, field, hlc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'field_versions';
  @override
  VerificationContext validateIntegrity(Insertable<FieldVersionRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(_entityMeta, entity.isAcceptableOrUnknown(data['entity']!, _entityMeta));
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta, recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(_fieldMeta, field.isAcceptableOrUnknown(data['field']!, _fieldMeta));
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(_hlcMeta, hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta));
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, recordId, field};
  @override
  FieldVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FieldVersionRow(
      entity: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}entity'])!,
      recordId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      field: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}field'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
    );
  }

  @override
  $FieldVersionsTable createAlias(String alias) {
    return $FieldVersionsTable(attachedDatabase, alias);
  }
}

class FieldVersionRow extends DataClass implements Insertable<FieldVersionRow> {
  final String entity;
  final String recordId;
  final String field;
  final String hlc;
  const FieldVersionRow({required this.entity, required this.recordId, required this.field, required this.hlc});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['record_id'] = Variable<String>(recordId);
    map['field'] = Variable<String>(field);
    map['hlc'] = Variable<String>(hlc);
    return map;
  }

  FieldVersionsCompanion toCompanion(bool nullToAbsent) {
    return FieldVersionsCompanion(
      entity: Value(entity),
      recordId: Value(recordId),
      field: Value(field),
      hlc: Value(hlc),
    );
  }

  factory FieldVersionRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FieldVersionRow(
      entity: serializer.fromJson<String>(json['entity']),
      recordId: serializer.fromJson<String>(json['recordId']),
      field: serializer.fromJson<String>(json['field']),
      hlc: serializer.fromJson<String>(json['hlc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'recordId': serializer.toJson<String>(recordId),
      'field': serializer.toJson<String>(field),
      'hlc': serializer.toJson<String>(hlc),
    };
  }

  FieldVersionRow copyWith({String? entity, String? recordId, String? field, String? hlc}) => FieldVersionRow(
    entity: entity ?? this.entity,
    recordId: recordId ?? this.recordId,
    field: field ?? this.field,
    hlc: hlc ?? this.hlc,
  );
  FieldVersionRow copyWithCompanion(FieldVersionsCompanion data) {
    return FieldVersionRow(
      entity: data.entity.present ? data.entity.value : this.entity,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      field: data.field.present ? data.field.value : this.field,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FieldVersionRow(')
          ..write('entity: $entity, ')
          ..write('recordId: $recordId, ')
          ..write('field: $field, ')
          ..write('hlc: $hlc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, recordId, field, hlc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FieldVersionRow &&
          other.entity == this.entity &&
          other.recordId == this.recordId &&
          other.field == this.field &&
          other.hlc == this.hlc);
}

class FieldVersionsCompanion extends UpdateCompanion<FieldVersionRow> {
  final Value<String> entity;
  final Value<String> recordId;
  final Value<String> field;
  final Value<String> hlc;
  final Value<int> rowid;
  const FieldVersionsCompanion({
    this.entity = const Value.absent(),
    this.recordId = const Value.absent(),
    this.field = const Value.absent(),
    this.hlc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FieldVersionsCompanion.insert({
    required String entity,
    required String recordId,
    required String field,
    required String hlc,
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       recordId = Value(recordId),
       field = Value(field),
       hlc = Value(hlc);
  static Insertable<FieldVersionRow> custom({
    Expression<String>? entity,
    Expression<String>? recordId,
    Expression<String>? field,
    Expression<String>? hlc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (recordId != null) 'record_id': recordId,
      if (field != null) 'field': field,
      if (hlc != null) 'hlc': hlc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FieldVersionsCompanion copyWith({
    Value<String>? entity,
    Value<String>? recordId,
    Value<String>? field,
    Value<String>? hlc,
    Value<int>? rowid,
  }) {
    return FieldVersionsCompanion(
      entity: entity ?? this.entity,
      recordId: recordId ?? this.recordId,
      field: field ?? this.field,
      hlc: hlc ?? this.hlc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FieldVersionsCompanion(')
          ..write('entity: $entity, ')
          ..write('recordId: $recordId, ')
          ..write('field: $field, ')
          ..write('hlc: $hlc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalStateTable extends LocalState with TableInfo<$LocalStateTable, LocalStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_state';
  @override
  VerificationContext validateIntegrity(Insertable<LocalStateRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStateRow(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $LocalStateTable createAlias(String alias) {
    return $LocalStateTable(attachedDatabase, alias);
  }
}

class LocalStateRow extends DataClass implements Insertable<LocalStateRow> {
  final String key;
  final String value;
  const LocalStateRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalStateCompanion toCompanion(bool nullToAbsent) {
    return LocalStateCompanion(key: Value(key), value: Value(value));
  }

  factory LocalStateRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'key': serializer.toJson<String>(key), 'value': serializer.toJson<String>(value)};
  }

  LocalStateRow copyWith({String? key, String? value}) =>
      LocalStateRow(key: key ?? this.key, value: value ?? this.value);
  LocalStateRow copyWithCompanion(LocalStateCompanion data) {
    return LocalStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LocalStateRow && other.key == this.key && other.value == this.value);
}

class LocalStateCompanion extends UpdateCompanion<LocalStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStateCompanion.insert({required String key, required String value, this.rowid = const Value.absent()})
    : key = Value(key),
      value = Value(value);
  static Insertable<LocalStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStateCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return LocalStateCompanion(key: key ?? this.key, value: value ?? this.value, rowid: rowid ?? this.rowid);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $JournalEntriesTable journalEntries = $JournalEntriesTable(this);
  late final $FieldVersionsTable fieldVersions = $FieldVersionsTable(this);
  late final $LocalStateTable localState = $LocalStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [journalEntries, fieldVersions, localState];
}

typedef $$JournalEntriesTableCreateCompanionBuilder = JournalEntriesCompanion Function({
  required String hlc,
  required String entity,
  required String recordId,
  required String field,
  required String value,
  Value<int> rowid,
});
typedef $$JournalEntriesTableUpdateCompanionBuilder = JournalEntriesCompanion Function({
  Value<String> hlc,
  Value<String> entity,
  Value<String> recordId,
  Value<String> field,
  Value<String> value,
  Value<int> rowid,
});

class $$JournalEntriesTableFilterComposer extends Composer<_$LocalDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$JournalEntriesTableOrderingComposer extends Composer<_$LocalDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$JournalEntriesTableAnnotationComposer extends Composer<_$LocalDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get entity => $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get recordId => $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get field => $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$JournalEntriesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $JournalEntriesTable,
          JournalRow,
          $$JournalEntriesTableFilterComposer,
          $$JournalEntriesTableOrderingComposer,
          $$JournalEntriesTableAnnotationComposer,
          $$JournalEntriesTableCreateCompanionBuilder,
          $$JournalEntriesTableUpdateCompanionBuilder,
          (JournalRow, BaseReferences<_$LocalDatabase, $JournalEntriesTable, JournalRow>),
          JournalRow,
          PrefetchHooks Function()
        > {
  $$JournalEntriesTableTableManager(_$LocalDatabase db, $JournalEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$JournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$JournalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$JournalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hlc = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion(
                hlc: hlc,
                entity: entity,
                recordId: recordId,
                field: field,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hlc,
                required String entity,
                required String recordId,
                required String field,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion.insert(
                hlc: hlc,
                entity: entity,
                recordId: recordId,
                field: field,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JournalEntriesTable, JournalRow>(table),
                  BaseReferences<_$LocalDatabase, $JournalEntriesTable, JournalRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JournalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $JournalEntriesTable,
      JournalRow,
      $$JournalEntriesTableFilterComposer,
      $$JournalEntriesTableOrderingComposer,
      $$JournalEntriesTableAnnotationComposer,
      $$JournalEntriesTableCreateCompanionBuilder,
      $$JournalEntriesTableUpdateCompanionBuilder,
      (JournalRow, BaseReferences<_$LocalDatabase, $JournalEntriesTable, JournalRow>),
      JournalRow,
      PrefetchHooks Function()
    >;
typedef $$FieldVersionsTableCreateCompanionBuilder = FieldVersionsCompanion Function({
  required String entity,
  required String recordId,
  required String field,
  required String hlc,
  Value<int> rowid,
});
typedef $$FieldVersionsTableUpdateCompanionBuilder = FieldVersionsCompanion Function({
  Value<String> entity,
  Value<String> recordId,
  Value<String> field,
  Value<String> hlc,
  Value<int> rowid,
});

class $$FieldVersionsTableFilterComposer extends Composer<_$LocalDatabase, $FieldVersionsTable> {
  $$FieldVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => ColumnFilters(column));
}

class $$FieldVersionsTableOrderingComposer extends Composer<_$LocalDatabase, $FieldVersionsTable> {
  $$FieldVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnOrderings(column));
}

class $$FieldVersionsTableAnnotationComposer extends Composer<_$LocalDatabase, $FieldVersionsTable> {
  $$FieldVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity => $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get recordId => $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get field => $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => column);
}

class $$FieldVersionsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $FieldVersionsTable,
          FieldVersionRow,
          $$FieldVersionsTableFilterComposer,
          $$FieldVersionsTableOrderingComposer,
          $$FieldVersionsTableAnnotationComposer,
          $$FieldVersionsTableCreateCompanionBuilder,
          $$FieldVersionsTableUpdateCompanionBuilder,
          (FieldVersionRow, BaseReferences<_$LocalDatabase, $FieldVersionsTable, FieldVersionRow>),
          FieldVersionRow,
          PrefetchHooks Function()
        > {
  $$FieldVersionsTableTableManager(_$LocalDatabase db, $FieldVersionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$FieldVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$FieldVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$FieldVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> entity = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<String> field = const Value.absent(),
            Value<String> hlc = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => FieldVersionsCompanion(entity: entity, recordId: recordId, field: field, hlc: hlc, rowid: rowid),
          createCompanionCallback: ({
            required String entity,
            required String recordId,
            required String field,
            required String hlc,
            Value<int> rowid = const Value.absent(),
          }) => FieldVersionsCompanion.insert(entity: entity, recordId: recordId, field: field, hlc: hlc, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FieldVersionsTable, FieldVersionRow>(table),
                  BaseReferences<_$LocalDatabase, $FieldVersionsTable, FieldVersionRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FieldVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $FieldVersionsTable,
      FieldVersionRow,
      $$FieldVersionsTableFilterComposer,
      $$FieldVersionsTableOrderingComposer,
      $$FieldVersionsTableAnnotationComposer,
      $$FieldVersionsTableCreateCompanionBuilder,
      $$FieldVersionsTableUpdateCompanionBuilder,
      (FieldVersionRow, BaseReferences<_$LocalDatabase, $FieldVersionsTable, FieldVersionRow>),
      FieldVersionRow,
      PrefetchHooks Function()
    >;
typedef $$LocalStateTableCreateCompanionBuilder = LocalStateCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$LocalStateTableUpdateCompanionBuilder = LocalStateCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$LocalStateTableFilterComposer extends Composer<_$LocalDatabase, $LocalStateTable> {
  $$LocalStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$LocalStateTableOrderingComposer extends Composer<_$LocalDatabase, $LocalStateTable> {
  $$LocalStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$LocalStateTableAnnotationComposer extends Composer<_$LocalDatabase, $LocalStateTable> {
  $$LocalStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalStateTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $LocalStateTable,
          LocalStateRow,
          $$LocalStateTableFilterComposer,
          $$LocalStateTableOrderingComposer,
          $$LocalStateTableAnnotationComposer,
          $$LocalStateTableCreateCompanionBuilder,
          $$LocalStateTableUpdateCompanionBuilder,
          (LocalStateRow, BaseReferences<_$LocalDatabase, $LocalStateTable, LocalStateRow>),
          LocalStateRow,
          PrefetchHooks Function()
        > {
  $$LocalStateTableTableManager(_$LocalDatabase db, $LocalStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => LocalStateCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalStateTable, LocalStateRow>(table),
                  BaseReferences<_$LocalDatabase, $LocalStateTable, LocalStateRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStateTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $LocalStateTable,
      LocalStateRow,
      $$LocalStateTableFilterComposer,
      $$LocalStateTableOrderingComposer,
      $$LocalStateTableAnnotationComposer,
      $$LocalStateTableCreateCompanionBuilder,
      $$LocalStateTableUpdateCompanionBuilder,
      (LocalStateRow, BaseReferences<_$LocalDatabase, $LocalStateTable, LocalStateRow>),
      LocalStateRow,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$JournalEntriesTableTableManager get journalEntries => $$JournalEntriesTableTableManager(_db, _db.journalEntries);
  $$FieldVersionsTableTableManager get fieldVersions => $$FieldVersionsTableTableManager(_db, _db.fieldVersions);
  $$LocalStateTableTableManager get localState => $$LocalStateTableTableManager(_db, _db.localState);
}
