import 'dart:io';

import 'package:batz/data/ledger/ledger_repository.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/data/local/open_database.dart';
import 'package:batz/data/secret_store.dart';
import 'package:batz/data/sync/sync_store.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/refund.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/modules/electricity.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/domain/modules/settings.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:batz/domain/modules/vacations.dart';
import 'package:batz/domain/period_model.dart';
import 'package:batz/domain/views/balances.dart';
import 'package:batz/domain/views/share_operations.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Databases written by versions 0.1.0, 0.2.0, 0.3.0, 0.4.1, 0.5.0, 0.6.0
/// and 0.7.0 (see test/fixtures/README.md).
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
const _fixture050 = 'test/fixtures/v0.5.0/batz.db';
const _fixture050DeviceId = 'a0000000-0000-4000-8000-000000000050';
const _fixture060 = 'test/fixtures/v0.6.0/batz.db';
const _fixture060DeviceId = 'a0000000-0000-4000-8000-000000000060';
const _fixture070 = 'test/fixtures/v0.7.0/batz.db';
const _fixture070DeviceId = 'a0000000-0000-4000-8000-000000000070';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('batz-upgrade');
    File(_fixture).copySync('${dir.path}/$databaseFileName');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a database of version 0.7.0 opens with this version: an entry in every module kept, nothing rebuilt', () async {
    File(_fixture070).copySync('${dir.path}/$databaseFileName');
    final db = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final journal = await Journal.open(db);
    expect(journal.deviceId, _fixture070DeviceId);
    expect(journal.derivedTablesRebuilt, isFalse, reason: 'this version adds no entity to the journal');
    final entries = await journal.entries();
    expect(entries, hasLength(177));

    final repository = LedgerRepository(db, journal);
    final ledger = await repository.load();
    expect(ledger.sortedAccounts.map((a) => a.name), ['Compte privé', 'Espèces']);
    expect(ledger.transactions, hasLength(5));

    // Salary sheet: three deductions, no gap.
    final sheet = ledger.salarySheet(2026)!;
    expect((sheet.gross, sheet.net, sheet.gap), (9600000, 8505600, 0));
    expect(sheet.deductions.map((d) => (d.id, d.label, d.amount)), [
      ('ded-1', 'AVS', 508800),
      ('ded-2', 'AC', 105600),
      ('ded-3', 'LPP', 480000),
    ]);

    // Fiscal year: 2'000.00 + 7'440.00 + 232.50, the paid instalment.
    final taxes = ledger.taxYear(2026);
    expect((taxes.record!.taxableWealth, taxes.record!.marginalRate), (5000000, 2500));
    expect(taxes.lines.map((l) => l.amount), [200000, 744000, 0, 23250, 0]);
    expect((taxes.total, taxes.paid), (967250, 150000));

    // The vacations module reads « Voyages »: the trip and the manual line.
    expect(ledger.moduleCategoryName(ModuleKind.vacations), 'Voyages');
    final trips = ledger.vacations.trips;
    expect(trips.map((t) => (t.place, t.days, t.amount, t.date.encode(), t.isManual)), [
      ('Gruyère', 2, 30000, '2026-09-12', true),
      ('Lisbonne', 8, 125000, '2026-07-10', false),
    ]);
    expect(trips.last.pricePerDay, 15625);

    // Electricity: 950 kWh over the first quarter.
    final power = ledger.electricityYear(2026);
    expect((power.price, power.wh, power.days, power.linesWithoutKwh), (24000, 950000, 90, 0));

    // The subscription whose price changed in September.
    final music = ledger.modules.subscriptions['sub-music']!;
    expect((music.name, music.note), ('Musique', 'Formule famille'));
    expect(music.tranches.map((t) => (t.amount, t.start.encode(), t.end?.encode())), [
      (1295, '2026-01-01', '2026-08-31'),
      (1495, '2026-09-01', null),
    ]);

    // The new version writes after the latest entry of 0.7.0.
    final before = entries.last.hlc;
    final hlc = await journal.write(ledger.setElectricity('line-t-power', 1000000));
    expect(hlc! > before, isTrue);
    final after = await repository.load();
    expect(after.electricityYear(2026).wh, 1000000);
    await db.close();
  });

  test('a database of version 0.6.0 opens with this version: declared balances and debts, one of them split, '
      'kept', () async {
    File(_fixture060).copySync('${dir.path}/$databaseFileName');
    final db = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final journal = await Journal.open(db);
    expect(journal.deviceId, _fixture060DeviceId);
    expect(journal.derivedTablesRebuilt, isTrue, reason: 'the settings of the modules are new');
    final entries = await journal.entries();
    expect(entries, hasLength(103));

    final repository = LedgerRepository(db, journal);
    final ledger = await repository.load();
    expect(ledger.sortedAccounts.map((a) => a.name), ['Compte privé', 'Dettes', 'Espèces', 'Épargne']);
    final savings = ledger.balances.of('acc-savings');
    expect(savings.points.map((p) => (p.date.encode(), p.amount)), [('2025-12-31', 1000000), ('2026-06-30', 1080000)]);
    expect(savings.variationAt(1), 30000);
    expect(ledger.balances.of('acc-cash').balanceAt(CalendarDate(2026, 3, 31)), 20000 - 4500 - 50000);
    expect(
      {for (final d in ledger.debts.values) d.id: (d.total, d.repaid)},
      {'debt-meal': (4000, false), 'debt-meal-2': (6000, true), 'debt-loan': (8000, false)},
    );
    expect(ledger.debts['debt-meal-2']!.receivedDate, CalendarDate(2026, 4, 1));
    expect(ledger.openDebtsAt(CalendarDate(2026, 3, 31)), 10000);
    expect(ledger.openDebtsAt(CalendarDate(2026, 11, 21)), 4000 - 8000);

    // The new version writes after the latest entry of 0.6.0.
    final before = entries.last.hlc;
    final hlc = await journal.write(ledger.setModuleCategory(ModuleKind.taxes, 'Nourriture'));
    expect(hlc! > before, isTrue);
    final after = await repository.load();
    expect(after.moduleCategory(ModuleKind.taxes, 2026)!.id, 'cat-food');
    expect(after.views.linesIn(2026, ViewKind.economic, 'cat-food').single.total, -4500);
    await db.close();
  });

  test('a database of version 0.5.0 opens with this version: redistribution rules, attached refund and answer to a '
      'share kept', () async {
    File(_fixture050).copySync('${dir.path}/$databaseFileName');
    final db = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final journal = await Journal.open(db);
    expect(journal.deviceId, _fixture050DeviceId);
    expect(journal.derivedTablesRebuilt, isTrue, reason: 'the declared balances are new');
    final entries = await journal.entries();
    expect(entries, hasLength(139));

    final repository = LedgerRepository(db, journal);
    final ledger = await repository.load();
    expect(ledger.sortedAccounts.map((a) => a.name), ['Compte privé', 'Espèces', 'Épargne']);
    expect(ledger.accounts['acc-bank']!.importFormat, ImportFormat.postfinance);
    expect(ledger.trees.keys.toList()..sort(), [2026, 2027]);
    final food2027 = copiedCategoryId('cat-food', 2027);
    expect(ledger.categories[food2027]!.name, 'Alimentation');

    // The redistribution rule and its copy.
    expect(ledger.redistributionsOf(2026).single.id, 'red-food');
    final copy = ledger.redistributionsOf(2027).single;
    expect(copy.id, copiedRedistributionId('red-food', 2027));
    expect((copy.sourceId, copy.targetId, copy.basisPoints), (food2027, copiedCategoryId('cat-cleaning', 2027), 1000));

    // The refund attached to its expense.
    final visit = ledger.transactions['tx-visit']!;
    expect(ledger.refundsOf(visit).map((t) => t.id), ['tx-back']);
    expect(ledger.netCostOf(visit), -30000 + 12000);
    expect(ledger.brokenRefunds, isEmpty);

    // The answer given for the share of 2027.
    expect(ledger.views.answerOf('tx-market-line', 2027)!.categoryId, food2027);
    expect(ledger.pendingShareCount, 0);
    final economic = ledger.views.of(2026, ViewKind.economic)!;
    expect(economic.redistributions.single.moved.month(1), -(10000 - 4000) ~/ 10);
    expect(ledger.views.of(2027, ViewKind.economic)!.totalOf(food2027), -60000);
    expect(ledger.transactions['tx-saving']!.counterpartAccountId, 'acc-savings');

    // The new version writes after the latest entry of 0.5.0: a balance
    // declared on the savings, which received the transfer.
    final before = entries.last.hlc;
    final hlc = await journal.write(ledger.detachRefund('tx-back'));
    expect(hlc! > before, isTrue);
    await journal.write(
      ledger.declareBalance('acc-savings', CalendarDate(2026, 7, 31), 25000, today: CalendarDate(2026, 11, 21)),
    );
    final after = await repository.load();
    expect(after.refundsOf(visit), isEmpty);
    final savings = after.balances.of('acc-savings');
    expect((savings.balanceAt(CalendarDate(2026, 7, 31)), savings.movements.single.amount), (25000, 20000));
    await db.close();
  });

  test('a database of version 0.4.1 opens with this version: statement, rules, validated lines and lines to '
      'validate kept', () async {
    File(_fixture041).copySync('${dir.path}/$databaseFileName');
    final db = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final journal = await Journal.open(db);
    expect(journal.deviceId, _fixture041DeviceId);
    expect(journal.derivedTablesRebuilt, isTrue, reason: 'the redistribution rules are new');
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
