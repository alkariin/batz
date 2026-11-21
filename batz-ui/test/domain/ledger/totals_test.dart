import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';

void main() {
  test('a transfer appears neither in income nor in expenses', () async {
    final h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply(
      (l) => l.recordEntry(
        'salary',
        'l1',
        entry(account: 'private', category: 'salary', cents: 500000, direction: Direction.inflow),
      ),
    );
    await h.apply((l) => l.recordEntry('rent', 'l2', entry(account: 'private', category: 'rent', cents: 150000)));
    await h.apply((l) => l.recordEntry('food', 'l3', entry(cents: 12000)));
    await h.apply((l) => l.recordEntry('refund', 'l4', entry(cents: 2000, direction: Direction.inflow)));
    final before = (await h.ledger()).views.of(2026, ViewKind.cash)!;

    // Cash withdrawal and back: two transfers, in both directions.
    await h.apply((l) => l.recordTransfer('withdrawal', transfer(from: 'private', to: 'cash', cents: 30000)));
    await h.apply((l) => l.recordTransfer('deposit', transfer(from: 'cash', to: 'private', cents: 5000)));
    final ledger = await h.ledger();
    final totals = ledger.views.of(2026, ViewKind.cash)!;

    expect(totals.income.total, 500000);
    expect(totals.expenses.total, -160000);
    expect(totals.savings.total, 340000);
    expect(totals.unclassified.total, 0);
    expect((totals.income, totals.expenses), (before.income, before.expenses));
    expect(totals.totals, before.totals);
    expect(ledger.kindOf(ledger.transactions['withdrawal']!), TransactionKind.transfer);
    await h.close();
  });

  test('a group adds up its children; only the payments of the year count', () async {
    final h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply((l) => l.addCategory('charges', year: 2026, name: 'Charges', parentId: 'housing'));
    await h.apply((l) => l.recordEntry('a', 'la', entry(category: 'rent', cents: 150000)));
    await h.apply((l) => l.recordEntry('b', 'lb', entry(category: 'charges', cents: 20000)));
    await h.apply((l) => l.recordEntry('c', 'lc', entry(category: 'food', cents: 5000)));
    // Paid in 2026 for 2027: counted in 2026 in the cash-flow view.
    await h.apply(
      (l) => l.recordEntry(
        'd',
        'ld',
        entry(category: 'food', cents: 1000, periodStart: d(2027, 1, 1), periodEnd: d(2027, 12, 31)),
      ),
    );
    final food2027 = (await h.ledger()).treeOrPreview(2027).named('Nourriture')!.id;
    await h.apply((l) => l.recordEntry('e', 'le', entry(category: food2027, cents: 7000, date: d(2027, 1, 3))));

    final ledger = await h.ledger();
    final totals = ledger.views.of(2026, ViewKind.cash)!;
    final expenses = defaultGroupId(2026, CategoryNature.expense);
    expect(
      {
        for (final e in totals.totals.entries)
          if (e.value != 0) e.key: e.value,
      },
      {'rent': -150000, 'charges': -20000, 'housing': -170000, 'food': -6000, expenses: -176000},
    );
    expect(totals.expenses.total, -176000);
    expect(totals.income.total, 0);
    expect(ledger.views.of(2027, ViewKind.cash)!.expenses.total, -7000);
    expect(ledger.views.of(2025, ViewKind.cash), isNull, reason: 'before the first tree');
    await h.close();
  });
}
