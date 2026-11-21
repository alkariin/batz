import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/balances.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/random_ledger.dart';
import '../../support/statements.dart';

final today = d(2026, 11, 21);

/// Every amount of every view of every year of [ledger].
Map<String, Object> viewAmounts(Ledger ledger) {
  final views = ledger.views;
  return {
    for (final year in views.years(currentYear: 2026))
      for (final kind in ViewKind.values)
        '$year ${kind.name}': () {
          final view = views.of(year, kind)!;
          return [
            view.categories,
            view.toClassify,
            view.unclassified,
            view.income,
            view.expenses,
            view.paidForOtherYears,
            view.paidInOtherYears,
            [for (final line in view.redistributions) (line.rule.id, line.moved)],
          ];
        }(),
  };
}

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply((l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)));
  });
  tearDown(() => h.close());

  Future<Ledger> declare(String account, CalendarDate date, int amount) =>
      h.apply((l) => l.declareBalance(account, date, amount, today: today));

  test('a balance of 10\'000 declared on 31.12.2025, 500 received on 15.3.2026, a balance of 10\'800 declared on '
      '30.6.2026: the balance is 10\'500 from 15.3 to 29.6, and the value variation of 300 is dated 30.6', () async {
    await declare('savings', d(2025, 12, 31), 1000000);
    await h.apply(
      (l) => l.recordTransfer('in', transfer(from: 'private', to: 'savings', cents: 50000, date: d(2026, 3, 15))),
    );
    final ledger = await declare('savings', d(2026, 6, 30), 1080000);
    final savings = ledger.balances.of('savings');

    expect(savings.balanceAt(d(2025, 12, 30)), isNull, reason: 'not in the wealth before its first balance');
    expect(savings.balanceAt(d(2025, 12, 31)), 1000000);
    expect(savings.balanceAt(d(2026, 3, 14)), 1000000);
    for (var day = d(2026, 3, 15); day.isBefore(d(2026, 6, 30)); day = day.addDays(1)) {
      expect(savings.balanceAt(day), 1050000, reason: '$day');
    }
    expect(savings.balanceAt(d(2026, 6, 30)), 1080000);
    expect(savings.balanceAt(d(2026, 12, 31)), 1080000);

    final history = savings.history;
    expect(history.map((s) => (s.point.date, s.point.amount, s.expected, s.variation)), [
      (d(2025, 12, 31), 1000000, null, null),
      (d(2026, 6, 30), 1080000, 1050000, 30000),
    ]);
    expect(history[1].movements.map((m) => (m.transaction.id, m.amount, m.arrival)), [('in', 50000, true)]);
    expect(savings.variationAt(1), 30000);
    expect(ledger.balances.of('private').movements.single.amount, -50000);
  });

  test('on a declared account, the gap with the expected balance is a value variation; income, expenses and every '
      'amount of the annual view are the same before and after the declaration (specification, phase 5)', () async {
    await h.apply(
      (l) => l.recordEntry(
        'salary',
        'l1',
        entry(account: 'private', category: 'salary', cents: 600000, direction: Direction.inflow, date: d(2026, 1, 25)),
      ),
    );
    await h.apply(
      (l) => l.recordEntry(
        'interest',
        'l2',
        entry(account: 'savings', category: 'salary', cents: 1250, direction: Direction.inflow, date: d(2026, 6, 30)),
      ),
    );
    await h.apply(
      (l) => l.recordEntry(
        'rent',
        'l3',
        entry(
          account: 'private',
          category: 'rent',
          cents: 210000,
          date: d(2026, 9, 1),
          periodStart: d(2026, 9, 1),
          periodEnd: d(2027, 8, 31),
        ),
      ),
    );
    await h.apply(
      (l) => l.recordTransfer('save', transfer(from: 'private', to: 'savings', cents: 100000, date: d(2026, 2, 1))),
    );
    final before = await h.ledger();
    final amounts = viewAmounts(before);
    final transactions = before.transactions;

    await declare('savings', d(2025, 12, 31), 500000);
    final ledger = await declare('savings', d(2026, 11, 20), 612345);

    expect(ledger.transactions, transactions, reason: 'declaring creates no transaction');
    expect(viewAmounts(ledger), amounts, reason: 'nor changes any amount of the annual view');
    final savings = ledger.balances.of('savings');
    expect(savings.history.last.expected, 500000 + 100000 + 1250);
    expect(savings.history.last.variation, 612345 - 601250);
    expect(savings.balanceAt(today), 612345);
  });

  test('declared balances on random data change nothing in the annual views', () {
    for (var seed = 1; seed <= 5; seed++) {
      final r = Random(seed);
      final plain = randomLedger(Random(seed));
      final declared = Ledger(
        accounts: plain.accounts.values,
        categories: [for (final tree in plain.trees.values) ...tree.byId.values],
        transactions: plain.transactions.values,
        rules: plain.rules.values,
        redistributions: plain.redistributions.values,
        shareClassifications: plain.shareClassifications.values,
        balances: [
          for (var i = 0; i < 20; i++)
            () {
              final account = ['cash', 'savings'][r.nextInt(2)];
              final date = CalendarDate(2025 + r.nextInt(4), 1 + r.nextInt(12), 1 + r.nextInt(28));
              return DeclaredBalance(
                id: balanceId(account, date),
                accountId: account,
                date: date,
                amount: r.nextInt(1000000),
              );
            }(),
        ],
      );
      expect(declared.declaredBalances, isNotEmpty);
      expect(viewAmounts(declared), viewAmounts(plain), reason: 'seed $seed');
    }
  });

  test('a movement on the day of a balance is part of it: the balance of that day is the one declared', () async {
    await declare('savings', d(2026, 5, 31), 80000);
    await h.apply(
      (l) => l.recordTransfer('same-day', transfer(from: 'private', to: 'savings', cents: 20000, date: d(2026, 6, 30))),
    );
    final ledger = await declare('savings', d(2026, 6, 30), 100000);
    final savings = ledger.balances.of('savings');
    expect(savings.history.last.expected, 100000, reason: 'the movement of the day counts in the expected balance');
    expect(savings.history.last.variation, 0);
    expect(savings.balanceAt(d(2026, 6, 29)), 80000);
    expect(savings.balanceAt(d(2026, 6, 30)), 100000);
    expect(savings.balanceAt(d(2026, 7, 1)), 100000, reason: 'not counted twice');
    expect(savings.history.last.movements.single.transaction.id, 'same-day');
  });

  test('an account without a declared balance is not in the wealth: no balance at any date', () async {
    final ledger = await h.apply((l) => l.recordTransfer('w', transfer(from: 'private', to: 'cash', cents: 20000)));
    final cash = ledger.balances.of('cash');
    expect((cash.hasOwnBalance, cash.points.isEmpty, cash.movements.single.amount), (true, true, 20000));
    expect(cash.balanceAt(today), isNull);
    expect(cash.history, isEmpty);
    expect(ledger.balances.of('savings').balanceAt(today), isNull);
  });

  test('a balance can be negative, a loan: movements add to it', () async {
    await declare('savings', d(2026, 1, 31), -500000);
    final ledger = await h.apply(
      (l) => l.recordTransfer('pay', transfer(from: 'private', to: 'savings', cents: 100000, date: d(2026, 2, 28))),
    );
    expect(ledger.balances.of('savings').balanceAt(d(2026, 3, 1)), -400000);
  });

  test('a line to validate whose rules propose a transfer moves both accounts, like a transfer; the detailed account '
      'starts from the opening balance of its first statement, the day before it, and ends on its closing '
      'balance', () async {
    final january = fixtureStatement('2026-01');
    await h.repository.write(
      (await h.ledger()).importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
    );
    await h.apply(
      (l) => l.createRule(
        'savings',
        const RuleDraft(year: 2026, keywords: ['compte épargne'], targetAccountId: 'savings'),
      ),
    );
    final ledger = await declare('savings', d(2026, 1, 1), 300000);

    final savings = ledger.balances.of('savings');
    expect(savings.movements.single.amount, 50000, reason: 'the proposed transfer arrives');
    expect(savings.balanceAt(d(2026, 1, 27)), 300000);
    expect(savings.balanceAt(d(2026, 1, 28)), 350000);

    final bank = ledger.balances.of('bank');
    expect(bank.points.single.statement, isNotNull);
    expect((bank.points.single.date, bank.points.single.amount), (d(2025, 12, 31), january.statement.openingBalance));
    expect(bank.balanceAt(d(2025, 12, 31)), january.statement.openingBalance);
    expect(bank.balanceAt(d(2026, 1, 31)), january.statement.closingBalance);
    expect(bank.movements, hasLength(january.statement.lines.length));

    // Without the rule, the line is unclassified: it still leaves the bank,
    // but arrives nowhere.
    final without = await h.apply((l) => l.deleteRule('savings'));
    expect(without.balances.of('bank').balanceAt(d(2026, 1, 31)), january.statement.closingBalance);
    expect(without.balances.of('savings').movements, isEmpty);
  });

  test('a balance left on an account that became detailed still counts, after the opening balance of a statement of '
      'the same day; it can be deleted, not declared nor modified', () async {
    final g = await LedgerHarness.open();
    addTearDown(g.close);
    await g.apply((l) => l.createAccount('acc', const AccountDraft(name: 'Banque', type: AccountType.privateAccount)));
    await g.apply((l) => l.declareBalance('acc', d(2025, 12, 31), 200000, today: today));
    await g.apply((l) => l.declareBalance('acc', d(2026, 2, 15), 999900, today: today));
    await g.apply(
      (l) => l.updateAccount(
        'acc',
        const AccountDraft(name: 'Banque', type: AccountType.privateAccount, importFormat: ImportFormat.postfinance),
      ),
    );
    final january = fixtureStatement('2026-01');
    final ledger = await g.apply(
      (l) => l.importStatement('acc', january.statement, fingerprint: january.fingerprint).modification,
    );
    final account = ledger.balances.of('acc');
    expect(account.points.map((p) => (p.date, p.amount, p.isDeclared)), [
      (d(2025, 12, 31), january.statement.openingBalance, false),
      (d(2025, 12, 31), 200000, true),
      (d(2026, 2, 15), 999900, true),
    ]);
    expect(account.variationAt(1), 200000 - january.statement.openingBalance);
    final closing = 200000 + january.statement.closingBalance - january.statement.openingBalance;
    expect(account.balanceAt(d(2026, 1, 31)), closing);
    expect(account.variationAt(2), 999900 - closing);

    final id = balanceId('acc', d(2026, 2, 15));
    expect(
      () => ledger.declareBalance('acc', d(2026, 3, 1), 1, today: today),
      throwsLedger(LedgerError.balanceOnDetailedAccount),
    );
    expect(
      () => ledger.updateBalance(id, d(2026, 2, 15), 1, today: today),
      throwsLedger(LedgerError.balanceOnDetailedAccount),
    );
    final after = await g.apply((l) => l.deleteBalance(id));
    expect(after.balances.of('acc').points, hasLength(2));
  });

  test('a balance is refused on the detailed account, on a debts account, in the future and on an unknown account, '
      'with its reason; today is accepted', () async {
    final ledger = await h.ledger();
    expect(
      () => ledger.declareBalance('bank', today, 1, today: today),
      throwsLedger(LedgerError.balanceOnDetailedAccount),
    );
    expect(
      () => ledger.declareBalance('debts', today, 1, today: today),
      throwsLedger(LedgerError.balanceOnDebtsAccount),
    );
    expect(
      () => ledger.declareBalance('savings', today.addDays(1), 1, today: today),
      throwsLedger(LedgerError.balanceInFuture),
    );
    expect(() => ledger.declareBalance('gone', today, 1, today: today), throwsLedger(LedgerError.unknownAccount));
    expect(() => ledger.updateBalance('gone', today, 1, today: today), throwsLedger(LedgerError.unknownBalance));
    expect(() => ledger.deleteBalance('gone'), throwsLedger(LedgerError.unknownBalance));
    final accepted = await declare('savings', today, 1);
    expect(accepted.balances.of('savings').balanceAt(today), 1);
  });

  test('declaring twice the same day replaces; a modification moves the balance to its new day; a balance deleted '
      'comes back when declared again', () async {
    await declare('savings', d(2026, 3, 31), 1000);
    var ledger = await declare('savings', d(2026, 3, 31), 2000);
    expect(ledger.declaredBalances.values.map((b) => (b.id, b.amount)), [(balanceId('savings', d(2026, 3, 31)), 2000)]);

    final id = balanceId('savings', d(2026, 3, 31));
    ledger = await h.apply((l) => l.updateBalance(id, d(2026, 3, 31), 2500, today: today));
    expect(ledger.declaredBalances[id]!.amount, 2500);
    ledger = await h.apply((l) => l.updateBalance(id, d(2026, 4, 30), 2600, today: today));
    expect(ledger.declaredBalancesOf('savings').map((b) => (b.date, b.amount)), [(d(2026, 4, 30), 2600)]);
    expect(
      () => ledger.updateBalance(balanceId('savings', d(2026, 4, 30)), today.addDays(1), 1, today: today),
      throwsLedger(LedgerError.balanceInFuture),
    );

    ledger = await h.apply((l) => l.deleteBalance(balanceId('savings', d(2026, 4, 30))));
    expect(ledger.declaredBalances, isEmpty);
    ledger = await declare('savings', d(2026, 4, 30), 3000);
    expect(ledger.declaredBalancesOf('savings').single.amount, 3000);
  });

  test('an account with declared balances is archived rather than deleted, stays in the wealth with its last balance, '
      'and still accepts a balance, of 0 to leave it (H4)', () async {
    await declare('savings', d(2026, 3, 31), 150000);
    final removal = (await h.ledger()).removeAccount('savings');
    expect((removal.archives, removal.transactionCount, removal.balanceCount), (true, 0, 1));
    var ledger = await h.apply((_) => removal.modification);
    expect(ledger.accounts['savings']!.archived, isTrue);
    expect(ledger.balances.of('savings').balanceAt(today), 150000);
    ledger = await declare('savings', d(2026, 10, 31), 0);
    expect(ledger.balances.of('savings').balanceAt(today), 0);
    expect(ledger.balances.of('savings').variationAt(1), -150000);
  });

  test('a transfer to an account deleted on another device, and balances left on a debts account, have no balance: '
      'their movements are kept, their balances ignored', () async {
    await h.apply((l) => l.recordTransfer('lend', transfer(from: 'private', to: 'debts', cents: 30000)));
    await h.apply((l) => l.recordTransfer('gone', transfer(from: 'private', to: 'cash', cents: 1000)));
    await h.repository.write(Modification.delete(AccountFields.entity, 'cash'));
    await h.repository.write(
      Modification.set(BalanceFields.entity, balanceId('debts', d(2026, 1, 31)), {
        BalanceFields.accountId: 'debts',
        BalanceFields.date: '2026-01-31',
        BalanceFields.amount: 5000,
      }),
    );
    final ledger = await h.ledger();
    final cash = ledger.balances.of('cash'), debts = ledger.balances.of('debts');
    expect((cash.account, cash.hasOwnBalance, cash.movements.single.amount), (null, false, 1000));
    expect((debts.hasOwnBalance, debts.points.isEmpty, debts.ignored.single.amount), (false, true, 5000));
    expect(debts.balanceAt(today), isNull);
    expect(debts.movements.single.amount, 30000);
    expect(ledger.balances.all.map((a) => a.accountId), containsAll(['bank', 'private', 'cash', 'debts', 'savings']));
  });

  test('two devices declaring the same account the same day write one balance, the latest amount', () async {
    var wallA = 1000, wallB = 1000;
    final a = await LedgerHarness.open(deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
    final b = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
    addTearDown(a.close);
    addTearDown(b.close);
    await a.apply((l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)));
    await b.journal.merge(await a.journal.entries());
    wallA = 5000;
    await a.apply((l) => l.declareBalance('savings', d(2026, 6, 30), 100000, today: today));
    wallB = 7000;
    await b.apply((l) => l.declareBalance('savings', d(2026, 6, 30), 120000, today: today));
    final fromA = await a.journal.entries(), fromB = await b.journal.entries();
    await a.journal.merge(fromB);
    await b.journal.merge(fromA);
    for (final device in [a, b]) {
      final ledger = await device.ledger();
      expect(ledger.declaredBalances.values.map((v) => (v.date, v.amount)), [(d(2026, 6, 30), 120000)]);
    }
    expect(await a.tables(['balances']), await b.tables(['balances']));
  });

  test('declaring a balance needs no category tree, whatever its year', () async {
    final g = await LedgerHarness.open();
    addTearDown(g.close);
    await g.apply((l) => l.createAccount('acc', const AccountDraft(name: 'Épargne', type: AccountType.savings)));
    final ledger = await g.apply((l) => l.declareBalance('acc', d(2020, 1, 1), 100, today: today));
    expect(ledger.trees, isEmpty);
    expect(ledger.balances.of('acc').balanceAt(today), 100);
  });
}

Matcher throwsLedger(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));
