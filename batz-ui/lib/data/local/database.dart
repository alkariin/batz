import 'package:drift/drift.dart';

part 'database.g.dart';

/// Every change ever made, on any device: the source of truth. All other
/// tables are derived from it and can be rebuilt from it.
@DataClassName('JournalRow')
class JournalEntries extends Table {
  @override
  String get tableName => 'journal';

  /// Encoded [Hlc]: sorts in time order, and names the device.
  TextColumn get hlc => text()();
  TextColumn get entity => text()();
  TextColumn get recordId => text()();
  TextColumn get field => text()();

  /// JSON-encoded value.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {hlc, entity, recordId, field};
}

/// The timestamp of the change that currently gives each field its value.
@DataClassName('FieldVersionRow')
class FieldVersions extends Table {
  TextColumn get entity => text()();
  TextColumn get recordId => text()();
  TextColumn get field => text()();
  TextColumn get hlc => text()();

  @override
  Set<Column<Object>> get primaryKey => {entity, recordId, field};
}

/// Values that belong to this installation only and are never synchronised,
/// such as the device identifier.
@DataClassName('LocalStateRow')
class LocalState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [JournalEntries, FieldVersions, LocalState])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
