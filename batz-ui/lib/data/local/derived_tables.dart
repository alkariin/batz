/// How journal entries of one entity are materialised into a table.
///
/// The table has an `id TEXT PRIMARY KEY` column, a
/// `deleted INTEGER NOT NULL DEFAULT 0` column fed by the deletion field, and
/// one column per field. Field columns must accept NULL or have a default:
/// with synchronisation, the fields of a record can arrive in any order.
///
/// The derived tables of the accounting entities come with phase 1; phase 0
/// only provides the mechanism.
class DerivedTable {
  DerivedTable({required this.entity, required this.table, required Map<String, String> columns})
    : columns = Map.unmodifiable(columns) {
    if (!_identifier.hasMatch(table)) throw ArgumentError.value(table, 'table', 'invalid SQL identifier');
    for (final column in columns.values) {
      if (!_identifier.hasMatch(column) || column == 'id' || column == 'deleted') {
        throw ArgumentError.value(column, 'column', 'invalid or reserved SQL identifier');
      }
    }
  }

  static final _identifier = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Entity name used in the journal.
  final String entity;

  /// SQL table name.
  final String table;

  /// Journal field name to SQL column name.
  final Map<String, String> columns;
}

/// The derived tables of the app. Empty until phase 1 adds the first
/// accounting entities.
final List<DerivedTable> appDerivedTables = [];
