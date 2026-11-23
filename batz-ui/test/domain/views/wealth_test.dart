import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/balances.dart';
import 'package:batz/domain/views/wealth.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/random_wealth.dart';
import '../../support/reference_example.dart';

/// Every line of [table], as the screen shows them.
Map<String, int> lines(WealthExplanation table) => {
  'économique': table.economicResult,
  'décalages': table.periodOffsets,
  'trésorerie': table.cashResult,
  'variations': table.valueVariationsTotal,
  'ajoutés': table.addedAccountsTotal,
  'dettes': table.debtsChange,
  'non classé': table.unclassified,
  'hors fortune': table.outsideWealthTotal,
  'fortune': table.wealthChange,
};

/// The checks every table of every year must pass, whatever the data: each
/// line is computed for itself, and they add up to the change of the
/// wealth, to the cent.
void checkWealth(Wealth wealth, {required String reason}) {
  expect(wealth.years, isNotEmpty, reason: reason);
  for (final year in wealth.years) {
    final table = wealth.explain(year);
    final why = '$reason, $year';
    expect(table.economicResult + table.periodOffsets, table.cashResult, reason: '$why: results');
    expect(table.explained, table.wealthChange, reason: '$why: ${lines(table)}');
    expect(table.wealthAtEnd, wealth.fortuneAt(table.end), reason: why);
    expect(table.wealthAtStart, wealth.fortuneAt(table.start), reason: why);
    if (year > wealth.years.first) {
      expect(table.wealthAtStart, wealth.explain(year - 1).wealthAtEnd, reason: why);
    }
  }
  // The curve: the wealth at the end of each month is the wealth computed
  // at that date.
  final monthly = wealth.monthly;
  expect(monthly, isNotEmpty, reason: reason);
  expect((monthly.first.year, monthly.first.month), (wealth.firstDate!.year, wealth.firstDate!.month));
  expect(
    (monthly.last.year, monthly.last.month, monthly.last.date),
    (wealth.today.year, wealth.today.month, wealth.today),
  );
  for (final (i, month) in monthly.indexed) {
    final last = CalendarDate(month.year, month.month, CalendarDate.daysInMonth(month.year, month.month));
    expect(month.date, i == monthly.length - 1 ? wealth.today : last, reason: '$reason, ${month.date}');
    expect(month.amount, wealth.fortuneAt(month.date), reason: '$reason, ${month.date}');
    expect(month.amount, wealth.at(month.date).total, reason: '$reason, ${month.date}');
  }
}

void main() {
  late LedgerHarness h;
  setUp(() async => h = await LedgerHarness.open());
  tearDown(() => h.close());

  test('the reference example gives each line of the table, and 12\'359.00 of change of the wealth', () async {
    final today = d(2027, 1, 15);
    final ledger = await referenceExample(h.apply, today: today);
    final wealth = ledger.wealth(today);
    expect(ledger.linesToValidate.single.amount, -3500);

    final table = wealth.explain(2026);
    expect(lines(table), {
      'économique': 1340000,
      'décalages': -140000,
      'trésorerie': 1200000,
      'variations': 25000,
      'ajoutés': 710000,
      'dettes': 10000,
      'non classé': -3500,
      'hors fortune': -705600,
      'fortune': 1235900,
    });
    expect((table.paidForOtherYears, table.paidInOtherYears), (-140000, 0));
    expect(table.valueVariations, [AccountAmount('savings', ledger.accounts['savings'], 25000)]);
    expect(table.addedAccounts, [AccountAmount('pillar', ledger.accounts['pillar'], 710000)]);
    expect(table.outsideWealth, [AccountAmount('pillar', ledger.accounts['pillar'], -705600)]);
    expect((table.openDebtsAtStart, table.openDebtsAtEnd, table.debtsAccountsMovements), (0, 10000, 0));
    expect((table.wealthAtStart, table.wealthAtEnd), (1500000, 2735900));
    expect(table.explained, table.wealthChange);

    // End of 2026, account by account.
    final end = wealth.at(d(2026, 12, 31));
    expect(
      {for (final a in end.accounts) a.account.id: a.balance},
      {'private': 390900, 'savings': 1625000, 'pillar': 710000},
    );
    expect((end.debts, end.total), (10000, 2735900));
    expect(end.totalsByType, {
      AccountType.privateAccount: 390900,
      AccountType.savings: 1625000,
      AccountType.pillar3: 710000,
    });
    expect(end.accounts.firstWhere((a) => a.account.id == 'private').lastStatement!.closingBalance, 390900);

    // 2025: no annual view, only the balances that enter the wealth.
    final first = wealth.explain(2025);
    expect(first.hasView, isFalse);
    expect(lines(first), {
      'économique': 0,
      'décalages': 0,
      'trésorerie': 0,
      'variations': 0,
      'ajoutés': 1500000,
      'dettes': 0,
      'non classé': 0,
      'hors fortune': 0,
      'fortune': 1500000,
    });
    expect(first.addedAccounts.map((a) => (a.accountId, a.amount)), [('private', 500000), ('savings', 1000000)]);
    expect(wealth.years, [2025, 2026, 2027]);
    checkWealth(wealth, reason: 'reference');
  });

  test('the table of the current year stops today: what is paid later does not count yet', () async {
    final today = d(2026, 7, 31);
    final ledger = await referenceExample(h.apply, today: d(2027, 1, 15));
    final wealth = ledger.wealth(today);
    final table = wealth.explain(2026);
    expect(table.end, today);
    // Paid by today: the salary, the transfers, the restaurant, the food.
    expect(table.cashResult, 6000000 - 20000 - 4570000);
    expect(table.unclassified, 0, reason: 'the unknown line is paid in November');
    expect(table.valueVariations, isEmpty, reason: 'the savings are declared on 31.12');
    expect(table.wealthAtEnd, wealth.fortuneAt(today));
    expect(wealth.views.of(2026, ViewKind.economic)!.paidForOtherYears, 0, reason: 'the rent is paid in September');
    expect(ledger.views.of(2026, ViewKind.economic)!.paidForOtherYears, -140000, reason: 'the annual view counts it');
    expect(wealth.years, [2025, 2026]);
    checkWealth(wealth, reason: 'July');
  });

  test('a pure loan, a transfer to then from « Dettes » with its debt opened then checked, changes neither the '
      'wealth nor the line of the debts', () async {
    await seedLedger(h);
    await h.apply((l) => l.declareBalance('private', d(2025, 12, 31), 1000000, today: d(2026, 1, 1)));
    final before = (await h.ledger()).wealth(d(2026, 2, 28));
    expect(before.fortuneAt(d(2026, 2, 28)), 1000000);

    await h.apply(
      (l) => l.recordTransfer('lend', transfer(from: 'private', to: 'debts', cents: 50000, date: d(2026, 3, 1))),
    );
    var ledger = await h.apply(
      (l) => l.createDebt(
        'loan',
        DebtDraft(
          direction: DebtDirection.owedToMe,
          person: 'Camille Exemple',
          amount: 50000,
          eventDate: d(2026, 3, 1),
        ),
        today: d(2026, 3, 1),
      ),
    );
    var wealth = ledger.wealth(d(2026, 4, 30));
    var table = wealth.explain(2026);
    expect((table.openDebtsAtEnd, table.debtsAccountsMovements, table.debtsChange), (50000, 50000, 0));
    expect((table.wealthChange, table.outsideWealthTotal, table.cashResult), (0, 0, 0));
    expect(wealth.at(d(2026, 4, 30)).accounts.firstWhere((a) => a.account.id == 'private').balance, 950000);
    expect(wealth.at(d(2026, 4, 30)).debts, 50000);
    checkWealth(wealth, reason: 'lent');

    await h.apply(
      (l) => l.recordTransfer('back', transfer(from: 'debts', to: 'private', cents: 50000, date: d(2026, 6, 1))),
    );
    ledger = await h.apply((l) => l.checkDebt('loan', receivedDate: d(2026, 6, 1), today: d(2026, 6, 2)));
    wealth = ledger.wealth(d(2026, 12, 31));
    table = wealth.explain(2026);
    expect((table.openDebtsAtEnd, table.debtsAccountsMovements, table.debtsChange, table.wealthChange), (0, 0, 0, 0));
    for (final month in wealth.monthly) {
      expect(month.amount, 1000000, reason: '${month.date}');
    }
    expect(wealth.fortuneAt(d(2026, 5, 31)), 1000000);
    checkWealth(wealth, reason: 'repaid');
  });

  test('an expense advanced for two then refunded is explained at each step', () async {
    await seedLedger(h);
    await h.apply((l) => l.addCategory('restaurant', year: 2026, name: 'Restaurant', parentId: expensesGroup));
    await h.apply((l) => l.declareBalance('private', d(2025, 12, 31), 1000000, today: d(2026, 1, 1)));
    await h.apply(
      (l) => l.recordEntry(
        'meal',
        'meal-line',
        entry(account: 'private', category: 'restaurant', cents: 20000, date: d(2026, 4, 10)),
      ),
    );
    var ledger = await h.apply(
      (l) => l.createDebt(
        'half',
        DebtDraft(
          direction: DebtDirection.owedToMe,
          person: 'Alex Modèle',
          amount: 20000,
          basisPoints: 5000,
          eventDate: d(2026, 4, 10),
        ),
        today: d(2026, 4, 10),
      ),
    );
    var table = ledger.wealth(d(2026, 4, 20)).explain(2026);
    expect(lines(table), {
      'économique': -20000,
      'décalages': 0,
      'trésorerie': -20000,
      'variations': 0,
      'ajoutés': 0,
      'dettes': 10000,
      'non classé': 0,
      'hors fortune': 0,
      'fortune': -10000,
    });
    checkWealth(ledger.wealth(d(2026, 4, 20)), reason: 'advanced');

    await h.apply(
      (l) => l.recordEntry(
        'refund',
        'refund-line',
        entry(
          account: 'private',
          category: 'restaurant',
          cents: 10000,
          direction: Direction.inflow,
          date: d(2026, 5, 5),
        ),
      ),
    );
    ledger = await h.apply((l) => l.checkDebt('half', receivedDate: d(2026, 5, 5), today: d(2026, 5, 6)));
    table = ledger.wealth(d(2026, 5, 10)).explain(2026);
    expect(lines(table), {
      'économique': -10000,
      'décalages': 0,
      'trésorerie': -10000,
      'variations': 0,
      'ajoutés': 0,
      'dettes': 0,
      'non classé': 0,
      'hors fortune': 0,
      'fortune': -10000,
    });
    checkWealth(ledger.wealth(d(2026, 5, 10)), reason: 'refunded');
  });

  test('on random data, the table of each year adds up to the change of the wealth, to the cent, and the curve is '
      'the wealth computed at each end of month', () {
    for (var seed = 1; seed <= 25; seed++) {
      final ledger = randomWealthLedger(Random(seed));
      for (final today in [d(2027, 8, 15), d(2028, 12, 31), d(2026, 2, 28)]) {
        final wealth = ledger.wealth(today);
        checkWealth(wealth, reason: 'seed $seed, seen on $today');
      }
      // What the data hold, so that each line is exercised.
      final wealth = ledger.wealth(d(2028, 12, 31));
      final tables = [for (final year in wealth.years) wealth.explain(year)];
      for (final (name, value) in [
        ('variations', (WealthExplanation t) => t.valueVariationsTotal),
        ('added', (WealthExplanation t) => t.addedAccountsTotal),
        ('debts', (WealthExplanation t) => t.debtsChange),
        ('debts accounts', (WealthExplanation t) => t.debtsAccountsMovements),
        ('unclassified', (WealthExplanation t) => t.unclassified),
        ('outside', (WealthExplanation t) => t.outsideWealthTotal),
        ('offsets', (WealthExplanation t) => t.periodOffsets),
      ]) {
        expect(tables.map(value), contains(isNot(0)), reason: 'seed $seed: $name');
      }
      expect(tables.first.hasView, isFalse, reason: 'seed $seed: 2025 has no tree');
      final gone = ledger.balances.of('gone');
      expect((gone.account, gone.movements.isNotEmpty), (null, true), reason: 'seed $seed: an account deleted');
    }
  });

  test('a balance declared more than six months ago is old, on an account not archived, neither detailed nor a debts '
      'account; an account without a declared balance is not', () async {
    await seedLedger(h);
    await h.apply((l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)));
    await h.apply((l) => l.createAccount('old', const AccountDraft(name: 'Ancien', type: AccountType.other)));
    final today = d(2026, 8, 31);
    await h.apply((l) => l.declareBalance('savings', d(2026, 2, 28), 1000, today: today));
    await h.apply((l) => l.declareBalance('private', d(2026, 2, 27), 1000, today: today));
    await h.apply((l) => l.declareBalance('old', d(2025, 1, 1), 1000, today: today));
    var ledger = await h.apply(
      (l) => l.updateAccount('old', const AccountDraft(name: 'Ancien', type: AccountType.other, archived: true)),
    );
    expect(sixMonthsBefore(today), d(2026, 2, 28));
    expect(sixMonthsBefore(d(2026, 11, 21)), d(2026, 5, 21));
    expect(sixMonthsBefore(d(2026, 3, 15)), d(2025, 9, 15));
    var wealth = ledger.wealth(today);
    expect(wealth.oldBalances.map((o) => (o.account.id, o.lastDeclared.date)), [('private', d(2026, 2, 27))]);
    expect(
      {for (final a in wealth.at(today).accounts) a.account.id: a.isOld},
      {'old': false, 'private': true, 'cash': false, 'bank': false, 'savings': false},
    );
    expect(wealth.at(today).withoutBalance.map((a) => a.id), [
      'bank',
      'cash',
    ], reason: 'the detailed account has no statement yet');

    ledger = await h.apply((l) => l.declareBalance('private', d(2026, 8, 1), 2000, today: today));
    wealth = ledger.wealth(d(2026, 9, 1));
    expect(wealth.oldBalances.map((o) => o.account.id), ['savings']);
  });

  test('an archived account whose balance is 0 is no longer listed; with a balance, it stays', () async {
    await seedLedger(h);
    await h.apply((l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)));
    final today = d(2026, 11, 21);
    await h.apply((l) => l.declareBalance('savings', d(2026, 1, 31), 50000, today: today));
    await h.apply((l) => l.declareBalance('private', d(2026, 1, 31), 70000, today: today));
    await h.apply((l) => l.removeAccount('savings').modification);
    var ledger = await h.apply((l) => l.removeAccount('private').modification);
    var at = ledger.wealth(today).at(today);
    expect(at.accounts.where((a) => a.account.archived).map((a) => a.account.id), ['private', 'savings']);

    ledger = await h.apply((l) => l.declareBalance('savings', d(2026, 10, 31), 0, today: today));
    at = ledger.wealth(today).at(today);
    expect(at.accounts.map((a) => a.account.id), isNot(contains('savings')));
    expect(at.accounts.map((a) => a.account.id), contains('private'));
    expect(at.total, 70000);
    expect(ledger.wealth(today).at(d(2026, 9, 30)).accounts.map((a) => a.account.id), contains('savings'));
    expect(ledger.accounts['savings']!.archived, isTrue, reason: 'still in the settings of the accounts');
  });

  test('without balances nor debts, there is no wealth: no year, no curve', () async {
    await seedLedger(h);
    final wealth = (await h.ledger()).wealth(d(2026, 11, 21));
    expect((wealth.firstDate, wealth.years.isEmpty, wealth.monthly.isEmpty), (null, true, true));
    expect(wealth.fortuneAt(d(2026, 11, 21)), 0);
    expect(wealth.at(d(2026, 11, 21)).withoutBalance.map((a) => a.id), ['bank', 'private', 'cash']);
  });

  test('a declared balance keeps its note, through a modification and a change of date', () async {
    final today = d(2026, 11, 21);
    await seedLedger(h);
    var ledger = await h.apply(
      (l) => l.declareBalance('private', d(2026, 6, 30), 5000, note: '  Relevé de juin ', today: today),
    );
    final id = balanceId('private', d(2026, 6, 30));
    expect(ledger.declaredBalances[id]!.note, 'Relevé de juin');
    ledger = await h.apply((l) => l.updateBalance(id, d(2026, 7, 1), 5100, note: 'Relevé corrigé', today: today));
    final moved = ledger.declaredBalances[balanceId('private', d(2026, 7, 1))]!;
    expect((moved.amount, moved.note), (5100, 'Relevé corrigé'));
    expect(ledger.declaredBalances.containsKey(id), isFalse);
  });

  test('the accounts follow the order chosen by the user; their types group in the order of their first account', () {
    final today = d(2026, 11, 21);
    final ledger = Ledger(
      accounts: const [
        Account(id: 'bank', name: 'Banque', type: AccountType.privateAccount, position: 2),
        Account(id: 'save', name: 'Épargne', type: AccountType.savings, position: 0),
        Account(id: 'cash', name: 'Espèces', type: AccountType.cash, position: 3),
        Account(id: 'other', name: 'Autre banque', type: AccountType.privateAccount, position: 1),
      ],
      balances: [
        for (final id in ['bank', 'save', 'cash', 'other'])
          DeclaredBalance(id: 'b-$id', accountId: id, date: d(2026, 1, 1), amount: 100),
      ],
    );
    final now = ledger.wealth(today).at(today);
    expect(now.accounts.map((a) => a.account.id), ['save', 'other', 'bank', 'cash']);
    expect(now.byType.keys, [AccountType.savings, AccountType.privateAccount, AccountType.cash]);
    expect(now.byType[AccountType.privateAccount]!.map((a) => a.account.id), ['other', 'bank']);
  });
}

final expensesGroup = defaultGroupId(2026, CategoryNature.expense);
