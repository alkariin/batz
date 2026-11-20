import 'dart:async';

import '../../domain/calendar_date.dart';
import '../../domain/journal/journal_entry.dart';
import '../../domain/ledger/account.dart';
import '../../domain/ledger/category.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/transaction.dart';
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

  Future<Ledger> load() async {
    return Ledger(
      accounts: await _rows(accountsTable, _account),
      categories: await _rows(categoriesTable, _category),
      transactions: await _rows(transactionsTable, _transaction),
      lines: await _rows(transactionLinesTable, _line),
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
    return TransactionLine(
      id: row['id']! as String,
      transactionId: transactionId,
      categoryId: categoryId as String?,
      amount: amount,
      periodStart: start,
      periodEnd: end,
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
