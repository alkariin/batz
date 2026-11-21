import 'dart:async';

import '../../domain/calendar_date.dart';
import '../../domain/journal/journal_entry.dart';
import '../../domain/ledger/account.dart';
import '../../domain/ledger/balance.dart';
import '../../domain/ledger/category.dart';
import '../../domain/ledger/debt.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/redistribution.dart';
import '../../domain/ledger/rule.dart';
import '../../domain/ledger/share_classification.dart';
import '../../domain/ledger/statement.dart';
import '../../domain/period_model.dart';
import '../../domain/ledger/transaction.dart';
import '../../domain/modules/module_records.dart';
import '../../domain/modules/salary.dart';
import '../../domain/modules/settings.dart';
import '../../domain/modules/taxes.dart';
import '../../domain/modules/vacations.dart';
import '../local/database.dart';
import '../local/derived_tables.dart';
import '../local/journal.dart';

/// Reads the [Ledger] from the derived tables and writes modifications to the
/// journal.
///
/// Reading follows design rule 2 of phase 1: a record that is incomplete or
/// holds a value this version cannot read is ignored, without error. With
/// synchronisation, its missing fields may simply not have arrived yet.
class LedgerRepository {
  LedgerRepository(this._db, this._journal);

  final LocalDatabase _db;
  final Journal _journal;

  /// Writes [modification] to the journal, which applies it to the derived
  /// tables in the same transaction.
  Future<void> write(Modification modification) => _journal.write(modification);

  /// Reads every derived table. The queries are sent together: the database
  /// runs in a background isolate, and the rows of one are read while the
  /// next ones run (step 4.4). They go in groups awaited together, a record
  /// waiting for nine futures at most; the tables of the modules are a group
  /// of their own.
  Future<Ledger> load() async {
    final (
      (accounts, categories, transactions, lines, statements, deleted),
      (rules, redistributions, answers, balances, debts),
      modules,
    ) = await (
      (
        _rows(accountsTable, _account),
        _rows(categoriesTable, _category),
        _rows(transactionsTable, _transaction),
        _rows(transactionLinesTable, _line),
        _rows(statementsTable, _statement),
        _db.customSelect('SELECT id FROM statements WHERE deleted = 1').get(),
      ).wait,
      (
        _rows(rulesTable, _rule),
        _rows(redistributionsTable, _redistribution),
        _rows(shareClassificationsTable, _shareClassification),
        _rows(balancesTable, _balance),
        _rows(debtsTable, _debt),
      ).wait,
      _modules(),
    ).wait;
    return Ledger(
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      lines: lines,
      statements: statements,
      deletedStatementIds: [for (final row in deleted) row.read<String>('id')],
      rules: rules,
      redistributions: redistributions,
      shareClassifications: answers,
      balances: balances,
      debts: debts,
      modules: modules,
    );
  }

  /// What the user entered in the modules.
  Future<ModuleRecords> _modules() async {
    final (settings, sheets, deductions, taxYears, taxLines, trips) = await (
      _rows(moduleSettingsTable, _moduleSetting),
      _rows(salarySheetsTable, _salarySheet),
      _rows(salaryDeductionsTable, _salaryDeduction),
      _rows(taxYearsTable, _taxYear),
      _rows(taxLinesTable, _taxLine),
      _rows(tripSheetsTable, _tripSheet),
    ).wait;
    return ModuleRecords(
      settings: settings,
      salarySheets: sheets,
      salaryDeductions: deductions,
      taxYears: taxYears,
      taxLines: taxLines,
      tripSheets: trips,
    );
  }

  /// The sheet of a trip is read whatever it holds; a manual line without
  /// date or amount shows no trip.
  static TripSheet? _tripSheet(Map<String, Object?> row) {
    final (days, amount) = (row['days'], row['amount']);
    return TripSheet(
      id: row['id']! as String,
      lineId: _string(row['line_id']),
      place: row['place'] is String ? row['place']! as String : '',
      days: days is int ? days : null,
      date: _date(row['date']),
      amount: amount is int ? amount : null,
    );
  }

  /// A fiscal year needs its year; its taxable wealth and marginal rate are
  /// optional.
  static TaxYear? _taxYear(Map<String, Object?> row) {
    final year = row['year'];
    if (year is! int) return null;
    final (wealth, marginal) = (row['taxable_wealth'], row['marginal_rate']);
    return TaxYear(
      id: row['id']! as String,
      year: year,
      taxableWealth: wealth is int ? wealth : null,
      marginalRate: marginal is int ? marginal : null,
    );
  }

  /// A line needs its year and a known tax; base, rate and coefficient are
  /// optional (an incomplete line counts 0).
  static TaxLine? _taxLine(Map<String, Object?> row) {
    final year = row['year'];
    final tax = _enum(TaxKind.values, row['tax']);
    if (year is! int || tax == null) return null;
    final (base, rate, coefficient) = (row['base'], row['base_rate'], row['coefficient']);
    return TaxLine(
      id: row['id']! as String,
      year: year,
      tax: tax,
      base: base is int ? base : null,
      baseRate: rate is int ? rate : null,
      coefficient: coefficient is int ? coefficient : null,
    );
  }

  /// A salary sheet needs its year, its gross and its net.
  static SalarySheet? _salarySheet(Map<String, Object?> row) {
    final (year, gross, net) = (row['year'], row['gross'], row['net']);
    if (year is! int || gross is! int || net is! int) return null;
    return SalarySheet(id: row['id']! as String, year: year, gross: gross, net: net);
  }

  /// A deduction needs its sheet, a label, an amount and a rank.
  static SalaryDeduction? _salaryDeduction(Map<String, Object?> row) {
    final sheetId = _string(row['sheet_id']);
    final label = _string(row['label']);
    final (amount, rank) = (row['amount'], row['rank']);
    if (sheetId == null || label == null || amount is! int) return null;
    return SalaryDeduction(
      id: row['id']! as String,
      sheetId: sheetId,
      label: label,
      amount: amount,
      rank: rank is int ? rank : 0,
    );
  }

  /// A setting needs a known module and a name.
  static ModuleSetting? _moduleSetting(Map<String, Object?> row) {
    final module = _enum(ModuleKind.values, row['module']);
    final name = _string(row['category_name']);
    if (module == null || name == null) return null;
    return ModuleSetting(id: row['id']! as String, module: module, categoryName: name);
  }

  /// A debt needs a known direction, a person, an amount, a percentage and
  /// the day it was entered. A date that cannot be read is no date.
  static Debt? _debt(Map<String, Object?> row) {
    final direction = _enum(DebtDirection.values, row['direction']);
    final person = _string(row['person']);
    final amount = row['amount'];
    final basisPoints = row['basis_points'];
    final enteredOn = _date(row['entered_on']);
    if (direction == null || person == null || amount is! int || basisPoints is! int || enteredOn == null) {
      return null;
    }
    return Debt(
      id: row['id']! as String,
      direction: direction,
      person: person,
      amount: amount,
      basisPoints: basisPoints,
      eventDate: _date(row['event_date']),
      invoiceDate: _date(row['invoice_date']),
      requestDate: _date(row['request_date']),
      receivedDate: _date(row['received_date']),
      description: row['description'] is String ? row['description']! as String : '',
      repaid: row['repaid'] == 1,
      enteredOn: enteredOn,
      checkedOn: _date(row['checked_on']),
    );
  }

  static CalendarDate? _date(Object? value) => CalendarDate.tryParse(value is String ? value : null);

  /// A declared balance needs its account, a valid date and an amount.
  /// Whether it counts is decided by the domain (an unknown account, a debts
  /// account: principle 6 of phase 5).
  static DeclaredBalance? _balance(Map<String, Object?> row) {
    final accountId = _string(row['account_id']);
    final date = CalendarDate.tryParse(row['date'] is String ? row['date']! as String : null);
    final amount = row['amount'];
    if (accountId == null || date == null || amount is! int) return null;
    return DeclaredBalance(id: row['id']! as String, accountId: accountId, date: date, amount: amount);
  }

  /// An answer needs its line, its year, the category chosen and the
  /// category it was given for.
  static ShareClassification? _shareClassification(Map<String, Object?> row) {
    final lineId = _string(row['line_id']);
    final year = row['year'];
    final category = _string(row['category_id']);
    final origin = _string(row['origin_category_id']);
    if (lineId == null || year is! int || category == null || origin == null) return null;
    return ShareClassification(
      id: row['id']! as String,
      lineId: lineId,
      year: year,
      categoryId: category,
      originCategoryId: origin,
    );
  }

  /// A redistribution rule needs a year, a source, a target and a
  /// percentage. Whether it applies is decided by the domain (principle 6).
  static RedistributionRule? _redistribution(Map<String, Object?> row) {
    final year = row['year'];
    final source = _string(row['source_category_id']);
    final target = _string(row['target_category_id']);
    final basisPoints = row['basis_points'];
    if (year is! int || source == null || target == null || basisPoints is! int) return null;
    return RedistributionRule(
      id: row['id']! as String,
      year: year,
      sourceId: source,
      targetId: target,
      basisPoints: basisPoints,
    );
  }

  /// A rule needs a year, a list of keywords and one target. An unknown
  /// period model (written by a newer version) makes it unreadable.
  static MappingRule? _rule(Map<String, Object?> row) {
    final year = row['year'];
    final keywords = decodeKeywords(row['keywords']);
    final category = row['target_category_id'];
    final account = row['target_account_id'];
    final model = row['period_model'];
    final parsedModel = _enum(PeriodModel.values, model);
    final months = row['period_months'];
    if (year is! int || keywords == null || keywords.isEmpty) return null;
    if ((category is String) == (account is String)) return null;
    if (model != null && parsedModel == null) return null;
    return MappingRule(
      id: row['id']! as String,
      year: year,
      keywords: keywords,
      targetCategoryId: category as String?,
      targetAccountId: account as String?,
      periodModel: parsedModel,
      periodMonths: months is int ? months : null,
    );
  }

  /// Rows by identifier: the physical order of a derived table depends on
  /// the order entries arrived in, which differs from one device to another.
  Future<List<T>> _rows<T>(DerivedTable table, T? Function(Map<String, Object?> row) read) async {
    final rows = await _db.customSelect('SELECT * FROM ${table.table} WHERE deleted = 0 ORDER BY id').get();
    return [for (final row in rows) ?read(row.data)];
  }

  static Account? _account(Map<String, Object?> row) {
    final name = _string(row['name']);
    final type = _enum(AccountType.values, row['type']);
    final importFormat = row['import_format'];
    final parsedFormat = _enum(ImportFormat.values, importFormat);
    if (name == null || type == null || (importFormat != null && parsedFormat == null)) return null;
    return Account(
      id: row['id']! as String,
      name: name,
      type: type,
      importFormat: parsedFormat,
      archived: row['archived'] == 1,
    );
  }

  /// A category needs a year and a name. Whether it belongs to a consistent
  /// tree (parent present, nature on its top-level group) is decided by
  /// [Ledger].
  static Category? _category(Map<String, Object?> row) {
    final year = row['year'];
    final name = _string(row['name']);
    final parentId = row['parent_id'];
    final nature = row['nature'];
    final position = row['position'];
    if (year is! int || name == null || (parentId != null && parentId is! String)) return null;
    return Category(
      id: row['id']! as String,
      year: year,
      name: name,
      parentId: parentId as String?,
      nature: _enum(CategoryNature.values, nature),
      position: position is int ? position : 0,
    );
  }

  /// A transaction needs an account, a valid date, an amount and a known
  /// status.
  static LedgerTransaction? _transaction(Map<String, Object?> row) {
    final accountId = row['account_id'];
    final date = CalendarDate.tryParse(row['date'] is String ? row['date']! as String : null);
    final amount = row['amount'];
    final counterpart = row['counterpart_account_id'];
    final status = _enum(TransactionStatus.values, row['status']);
    if (accountId is! String || date == null || amount is! int || status == null) return null;
    if (counterpart != null && counterpart is! String) return null;
    return LedgerTransaction(
      id: row['id']! as String,
      accountId: accountId,
      date: date,
      amount: amount,
      counterpartAccountId: counterpart as String?,
      description: row['description'] is String ? row['description']! as String : '',
      note: row['note'] is String ? row['note']! as String : '',
      status: status,
      rawText: row['raw_text'] is String ? row['raw_text']! as String : null,
      statementId: row['statement_id'] is String ? row['statement_id']! as String : null,
      statementRank: row['statement_rank'] is int ? row['statement_rank']! as int : null,
    );
  }

  /// A statement needs its account, a known format, a valid period, both
  /// balances and the fingerprint of its file.
  static Statement? _statement(Map<String, Object?> row) {
    final accountId = row['account_id'];
    final format = _enum(ImportFormat.values, row['format']);
    final start = CalendarDate.tryParse(row['period_start'] is String ? row['period_start']! as String : null);
    final end = CalendarDate.tryParse(row['period_end'] is String ? row['period_end']! as String : null);
    final opening = row['opening_balance'];
    final closing = row['closing_balance'];
    final fingerprint = _string(row['fingerprint']);
    if (accountId is! String || format == null || start == null || end == null || end.isBefore(start)) return null;
    if (opening is! int || closing is! int || fingerprint == null) return null;
    return Statement(
      id: row['id']! as String,
      accountId: accountId,
      format: format.name,
      iban: row['iban'] is String ? row['iban']! as String : '',
      periodStart: start,
      periodEnd: end,
      openingBalance: opening,
      closingBalance: closing,
      fingerprint: fingerprint,
    );
  }

  /// A line needs its transaction, an amount and a valid period.
  static TransactionLine? _line(Map<String, Object?> row) {
    final transactionId = row['transaction_id'];
    final categoryId = row['category_id'];
    final amount = row['amount'];
    final start = CalendarDate.tryParse(row['period_start'] is String ? row['period_start']! as String : null);
    final end = CalendarDate.tryParse(row['period_end'] is String ? row['period_end']! as String : null);
    if (transactionId is! String || amount is! int || start == null || end == null || end.isBefore(start)) {
      return null;
    }
    if (categoryId != null && categoryId is! String) return null;
    final refunded = row['refunded_line_id'];
    return TransactionLine(
      id: row['id']! as String,
      transactionId: transactionId,
      categoryId: categoryId as String?,
      amount: amount,
      periodStart: start,
      periodEnd: end,
      refundedLineId: refunded is String ? refunded : null,
    );
  }

  static String? _string(Object? value) => value is String && value.trim().isNotEmpty ? value : null;

  static T? _enum<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
