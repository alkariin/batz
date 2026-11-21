import 'dart:io';

import 'package:batz/data/ledger/ledger_repository.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/data/local/open_database.dart';
import 'package:batz/data/secret_store.dart';
import 'package:batz/data/sync/sync_store.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/period_model.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Databases written by versions 0.1.0, 0.2.0, 0.3.0 and 0.4.1 (see
/// test/fixtures/README.md).
const _fixture = 'test/fixtures/v0.1.0/batz.db';
const _fixtureDeviceId = 'a0000000-0000-4000-8000-000000000001';
const _fixture020 = 'test/fixtures/v0.2.0/batz.db';
const _fixture020DeviceId = 'a0000000-0000-4000-8000-000000000002';
const _fixture030 = 'test/fixtures/v0.3.0/batz.db';
const _fixture030DeviceId = 'a0000000-0000-4000-8000-000000000003';
const _fixture030Other = 'b0000000-0000-4000-8000-000000000004';
const _fixture030Pairing = 'c0000000-0000-4000-8000-000000000005';
const _fixture041 = 'test/fixtures/v0.4.1/batz.db';
const _fixture041DeviceId = 'a0000000-0000-4000-8000-000000000041';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('batz-upgrade');
    File(_fixture).copySync('${dir.path}/$databaseFileName');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a database of version 0.4.1 opens with this version: statement, rules, validated lines and lines to '
      'validate kept', () async {
    File(_fixture041).copySync('${dir.path}/$databaseFileName');
    final db = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final journal = await Journal.open(db);
    expect(journal.deviceId, _fixture041DeviceId);
    final entries = await journal.entries();
    expect(entries, hasLength(419));

    final repository = LedgerRepository(db, journal);
    final ledger = await repository.load();
    expect(ledger.sortedAccounts.map((a) => a.name), ['Compte privé', 'Espèces', 'Épargne']);
    expect(ledger.accounts['acc-bank']!.importFormat, ImportFormat.postfinance);
    final names = ['Revenus', 'Salaire', 'Dépenses', 'Logement', 'Loyer', 'Nourriture', 'Assurances'];
    expect(ledger.trees.keys.toList()..sort(), [2026, 2027]);
    expect(ledger.trees[2026]!.ordered.map((c) => c.name), names);
    expect(ledger.trees[2027]!.ordered.map((c) => c.name), names);

    // The rules and their copies.
    expect(ledger.rulesOf(2026).map((r) => r.id).toSet(), {'rule-food', 'rule-rent', 'rule-savings'});
    expect(ledger.rulesOf(2027).map((r) => r.id).toSet(), {
      for (final id in ['rule-food', 'rule-rent', 'rule-savings']) copiedRuleId(id, 2027),
    });
    final rent = ledger.rules['rule-rent']!;
    expect(rent.keywords, ['gérance', 'bail']);
    expect((rent.targetCategoryId, rent.periodModel), ('cat-rent', PeriodModel.nextMonth));
    expect(ledger.rules['rule-savings']!.targetAccountId, 'acc-savings');
    expect(ledger.rules[copiedRuleId('rule-food', 2027)]!.targetCategoryId, copiedCategoryId('cat-food', 2027));

    // The statement, its validated lines and its lines to validate.
    final statement = ledger.statementsOf('acc-bank').single;
    expect((statement.periodStart.encode(), statement.periodEnd.encode()), ('2026-01-01', '2026-01-31'));
    final lines = ledger.linesOf(statement.id);
    expect(lines, hasLength(27));
    expect(lines.where((t) => t.isValidated), hasLength(8));
    expect(ledger.linesToValidate, hasLength(19));
    expect(ledger.linesToValidate.every((t) => ledger.proposals[t.id] == const NoRule()), isTrue);
    final insurance = lines.singleWhere((t) => t.description == 'Assurance ménage');
    expect((insurance.note, insurance.line!.categoryId), ('Prime annuelle', 'cat-insurance'));
    expect((insurance.line!.periodStart.encode(), insurance.line!.periodEnd.encode()), ('2026-01-01', '2026-12-31'));
    final groceries = lines.where((t) => t.rawText!.contains('Épicerie du Coin')).toList();
    expect(groceries, hasLength(5));
    expect(groceries.every((t) => t.isValidated && t.line!.categoryId == 'cat-food'), isTrue);
    final rentLine = lines.singleWhere((t) => t.rawText!.contains('Gérance'));
    expect((rentLine.line!.periodStart.encode(), rentLine.line!.periodEnd.encode()), ('2026-02-01', '2026-02-28'));
    final saving = lines.singleWhere((t) => t.rawText!.contains('Compte épargne'));
    expect(saving.counterpartAccountId, 'acc-savings');
    expect(saving.lines, isEmpty);

    // The manual expenses.
    final cash = ledger.transactions['tx-cash']!;
    expect(
      (cash.amount, cash.line!.periodStart.encode(), cash.line!.periodEnd.encode()),
      (-210000, '2026-09-01', '2027-08-31'),
    );
    expect(ledger.transactions['tx-2027']!.line!.categoryId, copiedCategoryId('cat-food', 2027));

    // The new version writes after the latest entry of 0.4.1, and its rules
    // apply to the lines left to validate.
    final before = entries.last.hlc;
    final hlc = await journal.write(
      ledger.createRule(
        'rule-bakery',
        const RuleDraft(year: 2026, keywords: ['boulangerie'], targetCategoryId: 'cat-food'),
      ),
    );
    expect(hlc! > before, isTrue);
    final after = await repository.load();
    expect(after.linesToValidate.where((t) => after.proposalOf(t)?.categoryId == 'cat-food'), hasLength(3));
    await db.close();
  });

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
    expect(ledger.views.of(2026, ViewKind.cash)!.expenses.total, -4790);

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
    expect(ledger.views.of(2026, ViewKind.cash)!.expenses.total, -4790 - 210000);

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
