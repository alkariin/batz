import 'dart:io';

import 'package:batz/data/ledger/ledger_repository.dart';
import 'package:batz/data/local/database.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_fixture.dart';
import '../support/ledger_harness.dart';

const tables = ['accounts', 'categories', 'transactions', 'transaction_lines'];

/// A varied history: creations, modifications, moves, deletions, an archived
/// account, a copied tree, transfers.
Future<void> history(LedgerHarness h) async {
  await seedLedger(h);
  await h.apply((l) => l.recordEntry('t1', 'l1', entry(cents: 4500)));
  await h.apply(
    (l) => l.recordEntry(
      't2',
      'l2',
      entry(account: 'private', category: 'salary', cents: 500000, direction: Direction.inflow),
    ),
  );
  await h.apply(
    (l) => l.recordEntry(
      't3',
      'l3',
      entry(category: 'rent', cents: 210000, periodStart: d(2026, 9, 1), periodEnd: d(2027, 8, 31)),
    ),
  );
  await h.apply((l) => l.recordTransfer('t4', transfer()));
  await h.apply((l) => l.updateEntry('t1', entry(cents: 4600, description: 'Coop')));
  await h.apply((l) => l.updateTransfer('t4', transfer(cents: 20000)));
  await h.apply((l) => l.recordEntry('t5', 'l5', entry()));
  await h.apply((l) => l.deleteTransaction('t5'));
  await h.apply((l) => l.renameCategory('food', 'Alimentation'));
  await h.apply((l) => l.reorderCategory('food', -1)!);
  final food2027 = (await h.ledger()).treeOrPreview(2027).named('Alimentation')!.id;
  await h.apply((l) => l.recordEntry('t6', 'l6', entry(date: d(2027, 1, 2), category: food2027)));
  await h.apply((l) => l.removeAccount('cash').modification);
  await h.apply((l) => l.removeAccount('debts').modification);
}

Future<Map<String, List<Map<String, Object?>>>> snapshot(LocalDatabase db) async => {
  for (final name in [...tables, 'field_versions'])
    name: [for (final row in await db.customSelect('SELECT * FROM $name ORDER BY 1, 2, 3').get()) row.data],
};

void main() {
  test('after a rebuild from the journal, the tables of accounts, categories and transactions are identical', () async {
    final h = await LedgerHarness.open();
    await history(h);
    final before = await snapshot(h.db);
    final ledgerBefore = await h.ledger();
    expect(before['accounts'], hasLength(4));
    expect(before['transactions'], hasLength(6));
    expect(ledgerBefore.transactions, hasLength(5));

    for (final table in tables) {
      await h.db.customStatement('DELETE FROM $table');
    }
    await h.db.customStatement("INSERT INTO accounts (id, name) VALUES ('ghost', 'Fantôme')");
    await h.journal.rebuild();

    expect(await snapshot(h.db), before);
    expect(_describe(await h.ledger()), _describe(ledgerBefore));
    await h.close();
  });

  test('a schema change at start-up rebuilds the same tables', () async {
    final dir = Directory.systemTemp.createTempSync('batz-rebuild');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/batz.db');

    var db = LocalDatabase(NativeDatabase(file));
    final journal = await Journal.open(db);
    final h = LedgerHarnessOn(db, journal);
    await history(h);
    final before = await snapshot(db);
    await db.close();

    // As if the previous version had another derived schema.
    db = LocalDatabase(NativeDatabase(file));
    await db.customStatement("UPDATE local_state SET value = 'older schema' WHERE key = 'derived_schema'");
    await db.customStatement('DROP TABLE transaction_lines');
    final reopened = await Journal.open(db);
    expect(reopened.derivedTablesRebuilt, isTrue);
    expect(await snapshot(db), before);
    expect((await LedgerRepository(db, reopened).load()).transactions, hasLength(5));
    await db.close();
  });
}

String _describe(Ledger l) => [
  ...l.accounts.values.map((a) => '$a'),
  ...l.categories.values.map((c) => '$c'),
  ...l.transactions.values.map((t) => '$t'),
].join('\n');

/// A [LedgerHarness]-like wrapper on an existing database.
class LedgerHarnessOn implements LedgerHarness {
  LedgerHarnessOn(this.db, this.journal) : repository = LedgerRepository(db, journal);

  @override
  final LocalDatabase db;
  @override
  final Journal journal;
  @override
  final LedgerRepository repository;

  @override
  Future<Ledger> ledger() => repository.load();

  @override
  Future<Ledger> apply(Modification Function(Ledger ledger) build) async {
    await repository.write(build(await ledger()));
    return ledger();
  }

  @override
  Future<Map<String, List<Map<String, Object?>>>> tables(List<String> names) => throw UnimplementedError();

  @override
  Future<void> close() => db.close();
}
