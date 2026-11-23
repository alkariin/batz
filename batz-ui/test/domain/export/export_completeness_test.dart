// Every entity of the journal and each of its fields is exported, or excluded
// with its reason.
import 'package:batz/data/local/derived_tables.dart';
import 'package:batz/domain/export/export_schema.dart';
import 'package:batz/domain/export/ledger_export.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/settings.dart';
import 'package:batz/domain/modules/subscriptions.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:flutter_test/flutter_test.dart';

/// What [schema] leaves out of the journal described by [tables]: each
/// entity and each field neither exported nor excluded with a reason.
List<String> missingFromExport(Map<String, ExportedEntity> schema, List<DerivedTable> tables) => [
  for (final table in tables)
    if (!schema.containsKey(table.entity) && !excludedEntities.containsKey(table.entity))
      'entity ${table.entity}'
    else if (schema[table.entity] case final entity?)
      for (final field in [...table.columns.keys, deletedField])
        if (!entity.fields.containsKey(field) &&
            !entity.excluded.containsKey(field) &&
            !excludedFromEveryEntity.containsKey(field))
          '${table.entity}.$field',
];

void main() {
  test('every entity of the journal and each of its fields is exported or excluded with its reason', () {
    expect(missingFromExport(exportSchema, appDerivedTables), isEmpty);
    expect(excludedEntities, isEmpty, reason: 'everything entered or imported is exported');
    expect(excludedFromEveryEntity.keys, [deletedField]);
    for (final reason in [
      ...excludedFromEveryEntity.values,
      for (final e in exportSchema.values) ...e.excluded.values,
    ]) {
      expect(reason.trim(), isNotEmpty);
    }
  });

  test('the test fails when an entity or a field is taken out of the export', () {
    for (final entity in exportSchema.keys) {
      final withoutEntity = {...exportSchema}..remove(entity);
      expect(missingFromExport(withoutEntity, appDerivedTables), ['entity $entity']);
      final exported = exportSchema[entity]!;
      for (final field in exported.fields.keys) {
        final withoutField = {
          ...exportSchema,
          entity: ExportedEntity(
            file: exported.file,
            idColumn: exported.idColumn,
            fields: {...exported.fields}..remove(field),
            excluded: exported.excluded,
          ),
        };
        expect(missingFromExport(withoutField, appDerivedTables), ['$entity.$field']);
      }
    }
    // A field added to an entity later and forgotten.
    final table = appDerivedTables.first;
    final grown = DerivedTable(
      entity: table.entity,
      table: table.table,
      columns: {...table.columns, 'addedLater': const DerivedColumn.text('added_later')},
    );
    expect(missingFromExport(exportSchema, [grown, ...appDerivedTables.skip(1)]), ['${table.entity}.addedLater']);
    // An entity added later and forgotten.
    final added = DerivedTable(entity: 'addedLater', table: 'added_later', columns: {});
    expect(missingFromExport(exportSchema, [...appDerivedTables, added]), ['entity addedLater']);
  });

  test('no entity or field of the export is unknown to the journal', () {
    final tables = {for (final t in appDerivedTables) t.entity: t};
    for (final MapEntry(key: entity, value: exported) in exportSchema.entries) {
      expect(tables, contains(entity));
      for (final field in [...exported.fields.keys, ...exported.excluded.keys]) {
        expect(tables[entity]!.columns, contains(field), reason: '$entity.$field');
      }
    }
  });

  test('each field goes to a column of its file, and the identifiers are at the end', () {
    expect(ExportFiles.all, hasLength(17));
    expect(ExportHeaders.byFile.keys, ExportFiles.all);
    for (final MapEntry(key: entity, value: exported) in exportSchema.entries) {
      final headers = ExportHeaders.byFile[exported.file]!;
      expect(headers, contains(exported.idColumn), reason: entity);
      for (final MapEntry(key: field, value: column) in exported.fields.entries) {
        expect(headers, contains(column.header), reason: '$entity.$field');
        expect(column.kind == ExportKind.label, column.labels != null, reason: '$entity.$field');
      }
    }
    for (final MapEntry(key: file, value: headers) in ExportHeaders.byFile.entries) {
      expect(headers.toSet(), hasLength(headers.length), reason: '$file: a header twice');
      final firstId = headers.indexWhere((h) => h.startsWith('id'));
      expect(firstId, greaterThan(0), reason: '$file has identifiers, after its values');
      expect(headers.skip(firstId).every((h) => h.startsWith('id')), isTrue, reason: '$file: identifiers at the end');
    }
  });

  test('every name the journal stores has its label', () {
    void covers<T extends Enum>(Map<T, String> labels, List<T> values) {
      expect(labels.keys.toSet(), values.toSet());
      expect(labels.values.toSet(), hasLength(values.length), reason: 'two values with one label');
    }

    covers(ExportLabels.accountTypes, AccountType.values);
    covers(ExportLabels.importFormats, ImportFormat.values);
    covers(ExportLabels.natures, CategoryNature.values);
    covers(ExportLabels.statuses, TransactionStatus.values);
    covers(ExportLabels.kinds, TransactionKind.values);
    covers(ExportLabels.debtDirections, DebtDirection.values);
    covers(ExportLabels.taxes, TaxKind.values);
    covers(ExportLabels.frequencies, TrancheFrequency.values);
    covers(ExportLabels.modules, ModuleKind.values);
  });
}
