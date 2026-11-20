import 'package:batz/domain/ids.dart';
import 'package:batz/data/ledger/ledger_repository.dart';
import 'package:batz/data/local/database.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:drift/native.dart';

/// The app's real derived tables on an in-memory database: a device.
class LedgerHarness {
  LedgerHarness._(this.db, this.journal) : repository = LedgerRepository(db, journal);

  static Future<LedgerHarness> open({String? deviceId, int Function()? now}) async {
    final db = LocalDatabase(NativeDatabase.memory());
    final journal = await Journal.open(db, now: now, newDeviceId: deviceId == null ? newId : () => deviceId);
    return LedgerHarness._(db, journal);
  }

  final LocalDatabase db;
  final Journal journal;
  final LedgerRepository repository;

  Future<Ledger> ledger() => repository.load();

  /// Computes a modification on the current ledger and writes it.
  Future<Ledger> apply(Modification Function(Ledger ledger) build) async {
    await repository.write(build(await ledger()));
    return ledger();
  }

  /// Every row of every derived table, deleted ones included.
  Future<Map<String, List<Map<String, Object?>>>> tables(List<String> names) async => {
    for (final name in names)
      name: [for (final row in await db.customSelect('SELECT * FROM $name ORDER BY id').get()) row.data],
  };

  Future<void> close() => db.close();
}
