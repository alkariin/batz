import 'dart:async';

import '../../domain/journal/journal_entry.dart';
import '../../domain/ledger/account.dart';
import '../../domain/ledger/ledger.dart';
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
    return Ledger(accounts: await _rows(accountsTable, _account));
  }

  Future<List<T>> _rows<T>(DerivedTable table, T? Function(Map<String, Object?> row) read) async {
    final rows = await _db.customSelect('SELECT * FROM ${table.table} WHERE deleted = 0').get();
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

  static String? _string(Object? value) => value is String && value.trim().isNotEmpty ? value : null;

  static T? _enum<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
