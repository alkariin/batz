import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/ledger/transaction.dart';

import 'random_ledger.dart';

/// [randomLedger] (expenses, incomes, refunds, lines to validate, proposed
/// transfers, merge gaps, between 2026 and 2029) with what the wealth must
/// cope with, drawn at random from [r]:
///
/// - accounts: `bank` (detailed) gets a first statement, its opening balance
///   on 31.12.2025; `private`, `pillar` and `vehicle` are added, `debts` is a
///   debts account, and transfers also go to `gone`, an account deleted on
///   another device;
/// - 60 more transfers between all of them, from 2025 to 2028;
/// - 25 balances declared on `cash`, `savings`, `private`, `pillar` and
///   `bank` (left by a merge), some on the day of a movement, some after
///   the day the wealth is seen; balances left on `debts` and `gone`;
/// - 30 debts, both directions, with or without event, repaid or not, with
///   or without date of receipt.
Ledger randomWealthLedger(Random r) {
  final base = randomLedger(r, transactions: 200);
  CalendarDate day(int fromYear, int years) =>
      CalendarDate(fromYear + r.nextInt(years), 1 + r.nextInt(12), 1 + r.nextInt(28));
  final accounts = [
    ...base.accounts.values,
    const Account(id: 'private', name: 'UBS', type: AccountType.privateAccount),
    const Account(id: 'pillar', name: '3e pilier', type: AccountType.pillar3),
    const Account(id: 'vehicle', name: 'Voiture', type: AccountType.vehicle, archived: true),
    const Account(id: 'debts', name: 'Dettes', type: AccountType.debts),
  ];
  const ids = ['bank', 'cash', 'savings', 'private', 'pillar', 'vehicle', 'debts', 'gone'];
  final transfers = [
    for (var i = 0; i < 60; i++)
      LedgerTransaction(
        id: 'w$i',
        accountId: ids[r.nextInt(ids.length)],
        counterpartAccountId: ids[r.nextInt(ids.length)],
        date: day(2025, 4),
        amount: (r.nextInt(5) == 0 ? 1 : -1) * (1 + r.nextInt(300000)),
      ),
  ];
  final statement = Statement(
    id: 's2026',
    accountId: 'bank',
    format: 'postfinance',
    iban: 'CH0000000000000000000',
    periodStart: CalendarDate(2026, 1, 1),
    periodEnd: CalendarDate(2026, 1, 31),
    openingBalance: r.nextInt(1000000),
    closingBalance: 0,
    fingerprint: 'f',
  );
  final movementDays = [
    for (final t in [...base.transactions.values, ...transfers]) t.date,
  ];
  final balances = <String, DeclaredBalance>{};
  for (var i = 0; i < 30; i++) {
    final account = ['cash', 'savings', 'private', 'pillar', 'bank', 'debts', 'gone', 'vehicle'][r.nextInt(8)];
    final date = r.nextInt(4) == 0 ? movementDays[r.nextInt(movementDays.length)] : day(2025, 4);
    final id = balanceId(account, date);
    balances[id] = DeclaredBalance(id: id, accountId: account, date: date, amount: r.nextInt(2000000) - 300000);
  }
  final debts = [
    for (var i = 0; i < 30; i++)
      () {
        final repaid = r.nextInt(3) == 0;
        return Debt(
          id: 'debt$i',
          direction: DebtDirection.values[r.nextInt(2)],
          person: 'Personne $i',
          amount: 1 + r.nextInt(200000),
          basisPoints: r.nextBool() ? 10000 : 1 + r.nextInt(10000),
          enteredOn: day(2025, 4),
          eventDate: r.nextBool() ? day(2025, 4) : null,
          receivedDate: r.nextBool() ? day(2025, 4) : null,
          repaid: repaid,
          checkedOn: repaid && r.nextInt(4) > 0 ? day(2025, 4) : null,
        );
      }(),
  ];
  return Ledger(
    accounts: accounts,
    categories: [for (final tree in base.trees.values) ...tree.byId.values],
    transactions: [...base.transactions.values, ...transfers],
    statements: [statement],
    rules: base.rules.values,
    redistributions: base.redistributions.values,
    shareClassifications: base.shareClassifications.values,
    balances: balances.values,
    debts: debts,
  );
}
