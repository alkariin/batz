import 'dart:io';

import 'package:batz/data/ledger/ledger_repository.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/data/local/open_database.dart';
import 'package:batz/data/secret_store.dart';
import 'package:batz/data/sync/sync_store.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:flutter_test/flutter_test.dart';

/// Databases written by versions 0.1.0, 0.2.0 and 0.3.0 (see
/// test/fixtures/README.md).
const _fixture = 'test/fixtures/v0.1.0/batz.db';
const _fixtureDeviceId = 'a0000000-0000-4000-8000-000000000001';
const _fixture020 = 'test/fixtures/v0.2.0/batz.db';
const _fixture020DeviceId = 'a0000000-0000-4000-8000-000000000002';
const _fixture030 = 'test/fixtures/v0.3.0/batz.db';
const _fixture030DeviceId = 'a0000000-0000-4000-8000-000000000003';
const _fixture030Other = 'b0000000-0000-4000-8000-000000000004';
const _fixture030Pairing = 'c0000000-0000-4000-8000-000000000005';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('batz-upgrade');
    File(_fixture).copySync('${dir.path}/$databaseFileName');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a database of version 0.3.0 opens with this version, data and server memory kept', () async {
    File(_fixture030).copySync('${dir.path}/$databaseFileName');
    final db = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final journal = await Journal.open(db);
    expect(journal.deviceId, _fixture030DeviceId);
    expect(journal.derivedTablesRebuilt, isTrue, reason: 'the statements and the imported fields are new');
    final entries = await journal.entries();
    expect(entries, hasLength(76));
    expect((await journal.knownState()).origins, {_fixture030DeviceId, _fixture030Other});

    final repository = LedgerRepository(db, journal);
    final ledger = await repository.load();
    expect(ledger.sortedAccounts.map((a) => a.name), ['Compte privé', 'Espèces', 'Épargne']);
    expect(ledger.accounts['acc-bank']!.importFormat, ImportFormat.postfinance);
    expect(ledger.trees[2026]!.ordered.map((c) => c.name), [
      'Revenus',
      'Salaire',
      'Dépenses',
      'Logement',
      'Loyer et charges',
      'Nourriture',
    ], reason: 'the rename received from another device is kept');
    expect(ledger.transactions.keys.toSet(), {'tx-food', 'tx-saving'}, reason: 'one transaction deleted');
    final food = ledger.transactions['tx-food']!;
    expect((food.amount, food.description, food.note), (-4790, 'Marché', 'Légumes et fruits'));
    final saving = ledger.transactions['tx-saving']!;
    expect((saving.accountId, saving.counterpartAccountId, saving.amount), ('acc-cash', 'acc-savings', -20000));
    expect(ledger.cashTotals(2026).expenses, -4790);

    // What the device remembered of the server is still there: nothing waits.
    final memory = await SyncStore(db).read(_fixture030Pairing);
    expect(memory, isNotNull);
    expect(memory!.lastSuccess, DateTime.utc(2026, 11, 21, 9));
    expect(await journal.pendingFor(memory.known), 0);

    // The new version writes after the latest entry of 0.3.0.
    final before = entries.last.hlc;
    final hlc = await journal.write(ledger.renameCategory('cat-food', 'Alimentation'));
    expect(hlc! > before, isTrue);
    expect((await repository.load()).categories['cat-food']!.name, 'Alimentation');
    await db.close();
  });

  test('a database of version 0.2.0 opens with this version, data kept', () async {
    File(_fixture020).copySync('${dir.path}/$databaseFileName');
    final db = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final journal = await Journal.open(db);
    expect(journal.deviceId, _fixture020DeviceId);
    expect(await journal.entries(), hasLength(140));

    final repository = LedgerRepository(db, journal);
    final ledger = await repository.load();
    expect(ledger.sortedAccounts.map((a) => a.name), ['Compte privé', 'Espèces'], reason: 'one account deleted');
    expect(ledger.trees.keys.toList()..sort(), [2026, 2027]);
    expect(ledger.trees[2026]!.ordered.map((c) => c.name), [
      'Revenus',
      'Salaire',
      'Dépenses',
      'Logement',
      'Loyer',
      'Nourriture',
    ]);
    expect(ledger.trees[2027]!.ordered.map((c) => c.name), ledger.trees[2026]!.ordered.map((c) => c.name));
    expect(ledger.forest.detached, isEmpty);
    expect(ledger.transactions.keys.toSet(), {'tx-food', 'tx-rent', 'tx-withdrawal', 'tx-2027'});
    final food = ledger.transactions['tx-food']!;
    expect((food.amount, food.description, food.note), (-4790, 'Marché', 'Légumes et fruits'));
    expect(ledger.transactions['tx-withdrawal']!.counterpartAccountId, 'acc-cash');
    final rent = ledger.transactions['tx-rent']!.line!;
    expect((rent.periodStart.encode(), rent.periodEnd.encode()), ('2026-09-01', '2027-08-31'));
    expect(ledger.cashTotals(2026).expenses, -4790 - 210000);

    // The new version writes into it, after the latest entry of 0.2.0.
    final before = (await journal.entries()).last.hlc;
    final hlc = await journal.write(ledger.renameCategory('cat-food', 'Alimentation'));
    expect(hlc! > before, isTrue);
    expect((await repository.load()).categories['cat-food']!.name, 'Alimentation');
    await db.close();
  });

  test('a database of version 0.1.0 opens with this version, device identifier kept', () async {
    final db = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final journal = await Journal.open(db);

    expect(journal.deviceId, _fixtureDeviceId);
    expect(journal.derivedTablesRebuilt, isTrue, reason: '0.1.0 had no derived table');
    final entries = await journal.entries();
    expect(entries, hasLength(3));
    expect(entries.map((e) => e.field), containsAll(['name', 'type', 'archived']));
    // Entries 0.1.0 could only keep are now applied.
    final ledger = await LedgerRepository(db, journal).load();
    expect(ledger.accounts.values, [const Account(id: 'acc-1', name: 'Espèces', type: AccountType.cash)]);
    await db.close();

    // The next launch finds the schema in place and changes nothing.
    final again = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final reopened = await Journal.open(again);
    expect(reopened.deviceId, _fixtureDeviceId);
    expect(reopened.derivedTablesRebuilt, isFalse);
    await again.close();
  });
}
