import '../../domain/ledger/account.dart';
import '../../domain/ledger/category.dart';
import '../../domain/ledger/rule.dart';
import '../../domain/ledger/statement.dart';
import '../../domain/ledger/transaction.dart';

/// How journal entries of one entity are materialised into a table.
///
/// Design rules (docs/decisions.md, phase 1):
///
/// - A derived table has no constraint: no uniqueness, no foreign key, no
///   NOT NULL on a field. With synchronisation, the fields of a record arrive
///   one by one and in any order; integrating them must never fail. Business
///   rules are checked by the domain when the user enters data, and readers
///   ignore incomplete records.
/// - A derived table never migrates. Its definition is part of the derived
///   schema; when the schema changes, every derived table is dropped,
///   recreated and recomputed from the journal (see `Journal.open`).
///
/// The table has an `id TEXT PRIMARY KEY` column, a
/// `deleted INTEGER NOT NULL DEFAULT 0` column fed by the deletion field, and
/// one nullable column per field.
class DerivedTable {
  DerivedTable({
    required this.entity,
    required this.table,
    required Map<String, DerivedColumn> columns,
    List<List<String>> indexes = const [],
  }) : columns = Map.unmodifiable(columns),
       indexes = List.unmodifiable(indexes.map(List<String>.unmodifiable)) {
    _checkIdentifier(table, 'table');
    final names = <String>{};
    for (final column in columns.values) {
      _checkIdentifier(column.name, 'column');
      if (column.name == 'id' || column.name == 'deleted') {
        throw ArgumentError.value(column.name, 'column', 'reserved SQL identifier');
      }
      if (!names.add(column.name)) throw ArgumentError.value(column.name, 'column', 'used twice');
    }
    for (final index in indexes) {
      for (final column in index) {
        if (!names.contains(column) && column != 'deleted') {
          throw ArgumentError.value(column, 'index', 'unknown column');
        }
      }
    }
  }

  static final _identifier = RegExp(r'^[a-z][a-z0-9_]*$');

  static void _checkIdentifier(String name, String what) {
    if (!_identifier.hasMatch(name)) throw ArgumentError.value(name, what, 'invalid SQL identifier');
  }

  /// Entity name used in the journal.
  final String entity;

  /// SQL table name.
  final String table;

  /// Journal field name to SQL column.
  final Map<String, DerivedColumn> columns;

  /// Plain (non-unique) indexes, each a list of column names: they speed up
  /// reads and never refuse a row.
  final List<List<String>> indexes;

  /// Statements that create the table and its indexes.
  List<String> get createStatements => [
    'CREATE TABLE $table (id TEXT PRIMARY KEY, deleted INTEGER NOT NULL DEFAULT 0'
        '${columns.values.map((c) => ', ${c.name} ${c.type.sql}').join()})',
    for (final index in indexes) 'CREATE INDEX ${table}_${index.join('_')} ON $table (${index.join(', ')})',
  ];
}

/// SQL storage class of a derived column. Booleans are stored as 0 or 1.
enum SqlType {
  text('TEXT'),
  integer('INTEGER');

  const SqlType(this.sql);
  final String sql;
}

class DerivedColumn {
  const DerivedColumn(this.name, this.type);

  const DerivedColumn.text(this.name) : type = SqlType.text;
  const DerivedColumn.integer(this.name) : type = SqlType.integer;

  final String name;
  final SqlType type;
}

/// The derived schema made of [tables]: the text that identifies it. Two
/// schemas are the same if and only if their texts are equal.
String derivedSchemaOf(List<DerivedTable> tables) {
  final sorted = [...tables]..sort((a, b) => a.table.compareTo(b.table));
  return sorted.expand((t) => t.createStatements).join(';\n');
}

/// The derived tables of the app.
final List<DerivedTable> appDerivedTables = [
  accountsTable,
  categoriesTable,
  transactionsTable,
  transactionLinesTable,
  statementsTable,
  rulesTable,
];

final accountsTable = DerivedTable(
  entity: AccountFields.entity,
  table: 'accounts',
  columns: {
    AccountFields.name: const DerivedColumn.text('name'),
    AccountFields.type: const DerivedColumn.text('type'),
    AccountFields.importFormat: const DerivedColumn.text('import_format'),
    AccountFields.archived: const DerivedColumn.integer('archived'),
  },
);

final categoriesTable = DerivedTable(
  entity: CategoryFields.entity,
  table: 'categories',
  columns: {
    CategoryFields.year: const DerivedColumn.integer('year'),
    CategoryFields.name: const DerivedColumn.text('name'),
    CategoryFields.parentId: const DerivedColumn.text('parent_id'),
    CategoryFields.nature: const DerivedColumn.text('nature'),
    CategoryFields.position: const DerivedColumn.integer('position'),
  },
);

final transactionsTable = DerivedTable(
  entity: TransactionFields.entity,
  table: 'transactions',
  columns: {
    TransactionFields.accountId: const DerivedColumn.text('account_id'),
    TransactionFields.date: const DerivedColumn.text('date'),
    TransactionFields.amount: const DerivedColumn.integer('amount'),
    TransactionFields.counterpartAccountId: const DerivedColumn.text('counterpart_account_id'),
    TransactionFields.description: const DerivedColumn.text('description'),
    TransactionFields.note: const DerivedColumn.text('note'),
    TransactionFields.status: const DerivedColumn.text('status'),
    TransactionFields.rawText: const DerivedColumn.text('raw_text'),
    TransactionFields.statementId: const DerivedColumn.text('statement_id'),
    TransactionFields.statementRank: const DerivedColumn.integer('statement_rank'),
  },
  indexes: [
    ['date'],
    ['statement_id'],
  ],
);

final transactionLinesTable = DerivedTable(
  entity: LineFields.entity,
  table: 'transaction_lines',
  columns: {
    LineFields.transactionId: const DerivedColumn.text('transaction_id'),
    LineFields.categoryId: const DerivedColumn.text('category_id'),
    LineFields.amount: const DerivedColumn.integer('amount'),
    LineFields.periodStart: const DerivedColumn.text('period_start'),
    LineFields.periodEnd: const DerivedColumn.text('period_end'),
  },
  indexes: [
    ['transaction_id'],
  ],
);

final statementsTable = DerivedTable(
  entity: StatementFields.entity,
  table: 'statements',
  columns: {
    StatementFields.accountId: const DerivedColumn.text('account_id'),
    StatementFields.format: const DerivedColumn.text('format'),
    StatementFields.iban: const DerivedColumn.text('iban'),
    StatementFields.periodStart: const DerivedColumn.text('period_start'),
    StatementFields.periodEnd: const DerivedColumn.text('period_end'),
    StatementFields.openingBalance: const DerivedColumn.integer('opening_balance'),
    StatementFields.closingBalance: const DerivedColumn.integer('closing_balance'),
    StatementFields.fingerprint: const DerivedColumn.text('fingerprint'),
  },
);

final rulesTable = DerivedTable(
  entity: RuleFields.entity,
  table: 'rules',
  columns: {
    RuleFields.year: const DerivedColumn.integer('year'),
    RuleFields.keywords: const DerivedColumn.text('keywords'),
    RuleFields.targetCategoryId: const DerivedColumn.text('target_category_id'),
    RuleFields.targetAccountId: const DerivedColumn.text('target_account_id'),
    RuleFields.periodModel: const DerivedColumn.text('period_model'),
    RuleFields.periodMonths: const DerivedColumn.integer('period_months'),
  },
);
