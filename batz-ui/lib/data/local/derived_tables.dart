import '../../domain/ledger/account.dart';
import '../../domain/ledger/balance.dart';
import '../../domain/ledger/category.dart';
import '../../domain/ledger/debt.dart';
import '../../domain/ledger/redistribution.dart';
import '../../domain/ledger/rule.dart';
import '../../domain/ledger/share_classification.dart';
import '../../domain/ledger/statement.dart';
import '../../domain/ledger/transaction.dart';
import '../../domain/modules/electricity.dart';
import '../../domain/modules/insurances.dart';
import '../../domain/modules/monthly_tasks.dart';
import '../../domain/modules/salary.dart';
import '../../domain/modules/settings.dart';
import '../../domain/modules/subscriptions.dart';
import '../../domain/modules/taxes.dart';
import '../../domain/modules/vacations.dart';

/// How journal entries of one entity are materialised into a table.
///
/// Design rules (docs/decisions.md, « Design rules of the derived tables »):
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
  redistributionsTable,
  shareClassificationsTable,
  balancesTable,
  debtsTable,
  moduleSettingsTable,
  salarySheetsTable,
  salaryDeductionsTable,
  taxYearsTable,
  taxLinesTable,
  tripSheetsTable,
  electricityReadingsTable,
  subscriptionsTable,
  tranchesTable,
  monthlyTasksTable,
  monthlyChecksTable,
  insurancesTable,
  insuranceTranchesTable,
  insuranceDocumentsTable,
  insuranceLinksTable,
];

final accountsTable = DerivedTable(
  entity: AccountFields.entity,
  table: 'accounts',
  columns: {
    AccountFields.name: const DerivedColumn.text('name'),
    AccountFields.type: const DerivedColumn.text('type'),
    AccountFields.importFormat: const DerivedColumn.text('import_format'),
    AccountFields.archived: const DerivedColumn.integer('archived'),
    AccountFields.position: const DerivedColumn.integer('position'),
    AccountFields.declared: const DerivedColumn.integer('declared'),
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
    LineFields.refundedLineId: const DerivedColumn.text('refunded_line_id'),
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
    RuleFields.lines: const DerivedColumn.text('lines'),
    RuleFields.keywords: const DerivedColumn.text('keywords'),
    RuleFields.targetCategoryId: const DerivedColumn.text('target_category_id'),
    RuleFields.targetAccountId: const DerivedColumn.text('target_account_id'),
  },
);

final redistributionsTable = DerivedTable(
  entity: RedistributionFields.entity,
  table: 'redistributions',
  columns: {
    RedistributionFields.year: const DerivedColumn.integer('year'),
    RedistributionFields.sourceCategoryId: const DerivedColumn.text('source_category_id'),
    RedistributionFields.targetCategoryId: const DerivedColumn.text('target_category_id'),
    RedistributionFields.basisPoints: const DerivedColumn.integer('basis_points'),
    RedistributionFields.amount: const DerivedColumn.integer('amount'),
  },
);

final shareClassificationsTable = DerivedTable(
  entity: ShareClassificationFields.entity,
  table: 'share_classifications',
  columns: {
    ShareClassificationFields.lineId: const DerivedColumn.text('line_id'),
    ShareClassificationFields.year: const DerivedColumn.integer('year'),
    ShareClassificationFields.categoryId: const DerivedColumn.text('category_id'),
    ShareClassificationFields.originCategoryId: const DerivedColumn.text('origin_category_id'),
  },
);

final balancesTable = DerivedTable(
  entity: BalanceFields.entity,
  table: 'balances',
  columns: {
    BalanceFields.accountId: const DerivedColumn.text('account_id'),
    BalanceFields.date: const DerivedColumn.text('date'),
    BalanceFields.amount: const DerivedColumn.integer('amount'),
    BalanceFields.note: const DerivedColumn.text('note'),
  },
);

final debtsTable = DerivedTable(
  entity: DebtFields.entity,
  table: 'debts',
  columns: {
    DebtFields.direction: const DerivedColumn.text('direction'),
    DebtFields.person: const DerivedColumn.text('person'),
    DebtFields.amount: const DerivedColumn.integer('amount'),
    DebtFields.basisPoints: const DerivedColumn.integer('basis_points'),
    DebtFields.eventDate: const DerivedColumn.text('event_date'),
    DebtFields.invoiceDate: const DerivedColumn.text('invoice_date'),
    DebtFields.requestDate: const DerivedColumn.text('request_date'),
    DebtFields.receivedDate: const DerivedColumn.text('received_date'),
    DebtFields.description: const DerivedColumn.text('description'),
    DebtFields.repaid: const DerivedColumn.integer('repaid'),
    DebtFields.enteredOn: const DerivedColumn.text('entered_on'),
    DebtFields.checkedOn: const DerivedColumn.text('checked_on'),
    DebtFields.sourceTransactionId: const DerivedColumn.text('source_transaction_id'),
    DebtFields.refundTransactionId: const DerivedColumn.text('refund_transaction_id'),
  },
);

final moduleSettingsTable = DerivedTable(
  entity: ModuleSettingFields.entity,
  table: 'module_settings',
  columns: {
    ModuleSettingFields.module: const DerivedColumn.text('module'),
    ModuleSettingFields.categoryName: const DerivedColumn.text('category_name'),
  },
);

final salarySheetsTable = DerivedTable(
  entity: SalarySheetFields.entity,
  table: 'salary_sheets',
  columns: {
    SalarySheetFields.year: const DerivedColumn.integer('year'),
    SalarySheetFields.gross: const DerivedColumn.integer('gross'),
    SalarySheetFields.net: const DerivedColumn.integer('net'),
  },
);

final salaryDeductionsTable = DerivedTable(
  entity: SalaryDeductionFields.entity,
  table: 'salary_deductions',
  columns: {
    SalaryDeductionFields.sheetId: const DerivedColumn.text('sheet_id'),
    SalaryDeductionFields.label: const DerivedColumn.text('label'),
    SalaryDeductionFields.amount: const DerivedColumn.integer('amount'),
    SalaryDeductionFields.rank: const DerivedColumn.integer('rank'),
  },
);

final taxYearsTable = DerivedTable(
  entity: TaxYearFields.entity,
  table: 'tax_years',
  columns: {
    TaxYearFields.year: const DerivedColumn.integer('year'),
    TaxYearFields.taxableWealth: const DerivedColumn.integer('taxable_wealth'),
    TaxYearFields.marginalRate: const DerivedColumn.integer('marginal_rate'),
  },
);

final taxLinesTable = DerivedTable(
  entity: TaxLineFields.entity,
  table: 'tax_lines',
  columns: {
    TaxLineFields.year: const DerivedColumn.integer('year'),
    TaxLineFields.tax: const DerivedColumn.text('tax'),
    TaxLineFields.base: const DerivedColumn.integer('base'),
    TaxLineFields.baseRate: const DerivedColumn.integer('base_rate'),
    TaxLineFields.coefficient: const DerivedColumn.integer('coefficient'),
  },
);

final tripSheetsTable = DerivedTable(
  entity: TripSheetFields.entity,
  table: 'trip_sheets',
  columns: {
    TripSheetFields.lineId: const DerivedColumn.text('line_id'),
    TripSheetFields.place: const DerivedColumn.text('place'),
    TripSheetFields.days: const DerivedColumn.integer('days'),
    TripSheetFields.date: const DerivedColumn.text('date'),
    TripSheetFields.amount: const DerivedColumn.integer('amount'),
  },
);

final electricityReadingsTable = DerivedTable(
  entity: ElectricityReadingFields.entity,
  table: 'electricity_readings',
  columns: {
    ElectricityReadingFields.lineId: const DerivedColumn.text('line_id'),
    ElectricityReadingFields.wh: const DerivedColumn.integer('wh'),
  },
);

final subscriptionsTable = DerivedTable(
  entity: SubscriptionFields.entity,
  table: 'subscriptions',
  columns: {
    SubscriptionFields.name: const DerivedColumn.text('name'),
    SubscriptionFields.note: const DerivedColumn.text('note'),
  },
);

final tranchesTable = DerivedTable(
  entity: TrancheFields.entity,
  table: 'subscription_tranches',
  columns: {
    TrancheFields.subscriptionId: const DerivedColumn.text('subscription_id'),
    TrancheFields.amount: const DerivedColumn.integer('amount'),
    TrancheFields.frequency: const DerivedColumn.text('frequency'),
    TrancheFields.start: const DerivedColumn.text('start'),
    TrancheFields.end: const DerivedColumn.text('end_date'),
  },
);

final monthlyTasksTable = DerivedTable(
  entity: MonthlyTaskFields.entity,
  table: 'monthly_tasks',
  columns: {
    MonthlyTaskFields.name: const DerivedColumn.text('name'),
    MonthlyTaskFields.position: const DerivedColumn.integer('position'),
    MonthlyTaskFields.accountId: const DerivedColumn.text('account_id'),
    MonthlyTaskFields.since: const DerivedColumn.text('since'),
  },
);

final monthlyChecksTable = DerivedTable(
  entity: MonthlyCheckFields.entity,
  table: 'monthly_checks',
  columns: {
    MonthlyCheckFields.taskId: const DerivedColumn.text('task_id'),
    MonthlyCheckFields.month: const DerivedColumn.text('month'),
    MonthlyCheckFields.done: const DerivedColumn.integer('done'),
  },
);

final insurancesTable = DerivedTable(
  entity: InsuranceFields.entity,
  table: 'insurances',
  columns: {InsuranceFields.name: const DerivedColumn.text('name')},
);

final insuranceTranchesTable = DerivedTable(
  entity: InsuranceTrancheFields.entity,
  table: 'insurance_tranches',
  columns: {
    InsuranceTrancheFields.insuranceId: const DerivedColumn.text('insurance_id'),
    InsuranceTrancheFields.start: const DerivedColumn.text('start'),
    InsuranceTrancheFields.end: const DerivedColumn.text('end_date'),
    InsuranceTrancheFields.note: const DerivedColumn.text('note'),
  },
);

final insuranceDocumentsTable = DerivedTable(
  entity: InsuranceDocumentFields.entity,
  table: 'insurance_documents',
  columns: {
    InsuranceDocumentFields.trancheId: const DerivedColumn.text('tranche_id'),
    InsuranceDocumentFields.kind: const DerivedColumn.text('kind'),
    InsuranceDocumentFields.name: const DerivedColumn.text('name'),
    InsuranceDocumentFields.fingerprint: const DerivedColumn.text('fingerprint'),
    InsuranceDocumentFields.size: const DerivedColumn.integer('size'),
    InsuranceDocumentFields.mediaType: const DerivedColumn.text('media_type'),
  },
);

final insuranceLinksTable = DerivedTable(
  entity: InsuranceLinkFields.entity,
  table: 'insurance_links',
  columns: {
    InsuranceLinkFields.trancheId: const DerivedColumn.text('tranche_id'),
    InsuranceLinkFields.label: const DerivedColumn.text('label'),
    InsuranceLinkFields.url: const DerivedColumn.text('url'),
  },
);
