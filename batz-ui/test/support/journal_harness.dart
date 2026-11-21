import 'dart:io';

import 'package:batz/data/local/database.dart';
import 'package:batz/data/local/derived_tables.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/domain/ids.dart';
import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';

/// A derived table that exists only in tests, to check the mechanism without
/// any accounting entity.
final noteTable = DerivedTable(
  entity: 'note',
  table: 'notes',
  columns: {
    'title': const DerivedColumn.text('title'),
    'amount': const DerivedColumn.integer('amount'),
    'done': const DerivedColumn.integer('done'),
  },
);

/// A database plus its journal, on a file or in memory.
class Harness {
  Harness._(this.db, this.journal);

  static Future<Harness> open({File? file, int Function()? now, String? deviceId, List<DerivedTable>? tables}) async {
    // Simulated devices live side by side, each on its own executor: the
    // race Drift warns about cannot happen.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = LocalDatabase(file == null ? NativeDatabase.memory() : NativeDatabase(file));
    final journal = await Journal.open(
      db,
      tables: tables ?? [noteTable],
      now: now,
      newDeviceId: deviceId == null ? newId : () => deviceId,
    );
    return Harness._(db, journal);
  }

  final LocalDatabase db;
  final Journal journal;

  Future<void> close() => db.close();

  /// Visible notes: id to {title, amount, done}.
  Future<Map<String, Map<String, Object?>>> notes() async => {
    for (final row in await db.customSelect('SELECT * FROM notes WHERE deleted = 0 ORDER BY id').get())
      row.read<String>('id'): {'title': row.data['title'], 'amount': row.data['amount'], 'done': row.data['done']},
  };

  /// Every derived row, deleted ones included, with every column; empty if
  /// this version has no notes table.
  Future<List<Map<String, Object?>>> allRows() async {
    final exists = await db.customSelect("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'notes'").get();
    if (exists.isEmpty) return [];
    return [for (final row in await db.customSelect('SELECT * FROM notes ORDER BY id').get()) row.data];
  }
}

/// Shorthand for an entry made by another device.
JournalEntry entry(int millis, int counter, String device, String id, String field, Object? value) =>
    JournalEntry(Hlc(millis, counter, device), FieldChange('note', id, field, value));
