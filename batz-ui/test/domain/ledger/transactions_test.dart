import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';

Matcher refusedWith(LedgerError error, {int? count}) => throwsA(
  isA<LedgerException>().having((e) => e.error, 'error', error).having((e) => e.count, 'count', count ?? anything),
);

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
  });
  tearDown(() => h.close());

  group('manual entries', () {
    test('an expense is validated, signed, classified, with the payment date as period', () async {
      final l = await h.apply((l) => l.recordEntry('t1', 'l1', entry(cents: 4590, description: ' Migros ')));
      final t = l.transactions['t1']!;
      expect(t.amount, -4590);
      expect(t.status, TransactionStatus.validated);
      expect(t.description, 'Migros');
      expect(t.counterpartAccountId, isNull);
      expect(
        t.line,
        TransactionLine(
          id: 'l1',
          transactionId: 't1',
          categoryId: 'food',
          amount: -4590,
          periodStart: d(2026, 5, 10),
          periodEnd: d(2026, 5, 10),
        ),
      );
      expect(l.kindOf(t), TransactionKind.expense);
    });

    test('the type is deduced: expense, refund, income, transfer (H3)', () async {
      expect(defaultDirection(CategoryNature.expense), Direction.outflow);
      expect(defaultDirection(CategoryNature.income), Direction.inflow);
      await h.apply((l) => l.recordEntry('expense', 'l1', entry()));
      await h.apply((l) => l.recordEntry('refund', 'l2', entry(direction: Direction.inflow)));
      await h.apply((l) => l.recordEntry('income', 'l3', entry(category: 'salary', direction: Direction.inflow)));
      final l = await h.apply((l) => l.recordTransfer('transfer', transfer()));
      expect(
        {for (final t in l.transactions.values) t.id: l.kindOf(t)},
        {
          'expense': TransactionKind.expense,
          'refund': TransactionKind.refund,
          'income': TransactionKind.income,
          'transfer': TransactionKind.transfer,
        },
      );
      expect(l.transactions['refund']!.amount, 1000);
    });

    test('a manual entry on the detailed account is refused', () async {
      final l = await h.ledger();
      expect(() => l.recordEntry('t', 'l', entry(account: 'bank')), refusedWith(LedgerError.detailedAccountManual));
      expect(() => l.recordTransfer('t', transfer(from: 'bank')), refusedWith(LedgerError.detailedAccountManual));
      expect(() => l.recordTransfer('t', transfer(to: 'bank')), refusedWith(LedgerError.detailedAccountManual));
      expect(l.transactions, isEmpty);
    });

    test('a transaction of the detailed account cannot be modified or deleted by hand', () async {
      // As an import (phase 3) would write it.
      final hlc = Hlc(1, 0, '99999999-0000-4000-8000-000000000000');
      await h.journal.merge([
        for (final f in {'accountId': 'bank', 'date': '2026-05-01', 'amount': -500, 'status': 'validated'}.entries)
          JournalEntry(hlc, FieldChange('transaction', 'imported', f.key, f.value)),
      ]);
      final l = await h.ledger();
      expect(l.transactions.keys, ['imported']);
      expect(() => l.updateEntry('imported', entry()), refusedWith(LedgerError.detailedAccountManual));
      expect(() => l.deleteTransaction('imported'), refusedWith(LedgerError.detailedAccountManual));
    });

    test('an expense or income on a debts account is refused, a transfer to it is not', () async {
      final l = await h.ledger();
      expect(() => l.recordEntry('t', 'l', entry(account: 'debts')), refusedWith(LedgerError.debtsAccountManual));
      expect(l.recordTransfer('t', transfer(from: 'cash', to: 'debts')).changes, isNotEmpty);
      expect(l.recordTransfer('t', transfer(from: 'debts', to: 'cash')).changes, isNotEmpty);
    });

    test('the amount must be positive and the account active', () async {
      var l = await h.ledger();
      expect(() => l.recordEntry('t', 'l', entry(cents: 0)), refusedWith(LedgerError.amountRequired));
      expect(() => l.recordEntry('t', 'l', entry(account: 'nope')), refusedWith(LedgerError.unknownAccount));
      l = await h.apply((l) => l.recordEntry('t', 'l', entry()));
      l = await h.apply((l) => l.removeAccount('cash').modification);
      expect(l.accounts['cash']!.archived, isTrue);
      expect(() => l.recordEntry('t2', 'l2', entry()), refusedWith(LedgerError.archivedAccount));
      // The existing entry of the archived account can still be corrected.
      expect(l.updateEntry('t', entry(cents: 1200)).changes, isNotEmpty);
    });

    test('only a category without children, in the tree of the payment year, is accepted (H2)', () async {
      final l = await h.ledger();
      for (final category in ['housing', defaultGroupId(2026, CategoryNature.expense), 'nope']) {
        expect(
          () => l.recordEntry('t', 'l', entry(category: category)),
          refusedWith(LedgerError.categoryNotAssignable),
          reason: category,
        );
      }
      expect(
        () => l.recordEntry('t', 'l', entry(category: 'food', date: d(2027, 1, 5))),
        refusedWith(LedgerError.categoryNotAssignable),
        reason: 'a category of 2026 for a payment of 2027',
      );
    });

    test('the first transaction of a year without a tree creates it, in the same modification (H6)', () async {
      var l = await h.ledger();
      expect(l.trees.containsKey(2027), isFalse);
      final food2027 = l.treeOrPreview(2027).named('Nourriture')!.id;
      expect(food2027, copiedCategoryId('food', 2027));
      final m = l.recordEntry('t', 'l', entry(category: food2027, date: d(2027, 1, 5)));
      expect(m.changes.where((c) => c.entity == 'category'), hasLength(l.trees[2026]!.byId.length * 5));
      l = await h.apply((_) => m);
      expect(l.trees[2027]!.ordered.map((c) => c.name), l.trees[2026]!.ordered.map((c) => c.name));
      expect(l.categoryOf(l.transactions['t']!)!.year, 2027);
      // The second one does not copy it again.
      expect(
        l
            .recordEntry('t2', 'l2', entry(category: food2027, date: d(2027, 2, 5)))
            .changes
            .where((c) => c.entity == 'category'),
        isEmpty,
      );
    });

    test('the period can differ from the payment date; it cannot end before it starts', () async {
      var l = await h.ledger();
      expect(
        () => l.recordEntry('t', 'l', entry(periodStart: d(2026, 5, 2), periodEnd: d(2026, 5, 1))),
        refusedWith(LedgerError.periodInvalid),
      );
      l = await h.apply(
        (l) => l.recordEntry('t', 'l', entry(cents: 210000, periodStart: d(2026, 9, 1), periodEnd: d(2027, 8, 31))),
      );
      expect(l.transactions['t']!.line!.periodStart, d(2026, 9, 1));
      expect(l.transactions['t']!.line!.periodEnd, d(2027, 8, 31));
    });

    test('an entry is modified, then deleted with its line', () async {
      await h.apply((l) => l.recordEntry('t', 'l', entry()));
      var l = await h.apply(
        (l) => l.updateEntry(
          't',
          entry(cents: 2500, category: 'salary', direction: Direction.inflow, description: 'Bonus'),
        ),
      );
      final t = l.transactions['t']!;
      expect(
        (t.amount, t.description, t.line!.categoryId, t.line!.amount, t.line!.id),
        (2500, 'Bonus', 'salary', 2500, 'l'),
      );
      expect(l.kindOf(t), TransactionKind.income);
      l = await h.apply((l) => l.deleteTransaction('t'));
      expect(l.transactions, isEmpty);
      final lines = await h.db.customSelect('SELECT deleted FROM transaction_lines').get();
      expect(lines.single.read<int>('deleted'), 1);
    });
  });

  group('transfers', () {
    test('one record, on the departure account, with the arrival account as counterpart, no category', () async {
      final l = await h.apply((l) => l.recordTransfer('t', transfer(cents: 30000)));
      final t = l.transactions['t']!;
      expect((t.accountId, t.counterpartAccountId, t.amount), ('private', 'cash', -30000));
      expect(t.lines, isEmpty);
      expect(l.categoryOf(t), isNull);
      expect(l.transactionList(accountId: 'cash').single.id, 't', reason: 'listed on both accounts');
    });

    test('two different accounts are required', () async {
      final l = await h.ledger();
      expect(() => l.recordTransfer('t', transfer(from: 'cash', to: 'cash')), refusedWith(LedgerError.sameAccount));
    });

    test('a transfer is modified and deleted', () async {
      await h.apply((l) => l.recordTransfer('t', transfer()));
      var l = await h.apply((l) => l.updateTransfer('t', transfer(from: 'cash', to: 'private', cents: 100)));
      final t = l.transactions['t']!;
      expect((t.accountId, t.counterpartAccountId, t.amount), ('cash', 'private', -100));
      expect(() => l.updateEntry('t', entry()), refusedWith(LedgerError.unknownTransaction));
      l = await h.apply((l) => l.deleteTransaction('t'));
      expect(l.transactions, isEmpty);
    });
  });

  group('usage (H2, H5)', () {
    test('an account used by transactions is archived instead of deleted, with their number', () async {
      await h.apply((l) => l.recordEntry('t1', 'l1', entry()));
      await h.apply((l) => l.recordTransfer('t2', transfer()));
      final l = await h.ledger();
      final removal = l.removeAccount('cash');
      expect((removal.archives, removal.transactionCount), (true, 2));
      expect(l.removeAccount('private').transactionCount, 1, reason: 'counterpart counts');
      expect(l.removeAccount('debts').archives, isFalse);
      final after = await h.apply((_) => removal.modification);
      expect(after.accounts['cash']!.archived, isTrue);
    });

    test('a category used by transactions cannot be deleted; the number is given', () async {
      await h.apply((l) => l.recordEntry('t1', 'l1', entry()));
      await h.apply((l) => l.recordEntry('t2', 'l2', entry()));
      final l = await h.ledger();
      expect(() => l.removeCategory('food'), refusedWith(LedgerError.categoryInUse, count: 2));
      expect(l.removeCategory('rent').changes, isNotEmpty);
    });

    test('a category holding transactions cannot receive children, by addition or by move', () async {
      await h.apply((l) => l.recordEntry('t1', 'l1', entry()));
      final l = await h.ledger();
      expect(
        () => l.addCategory('x', year: 2026, name: 'Restaurant', parentId: 'food'),
        refusedWith(LedgerError.parentHasTransactions, count: 1),
      );
      expect(() => l.moveCategory('rent', parentId: 'food'), refusedWith(LedgerError.parentHasTransactions, count: 1));
    });
  });

  test('the list is sorted by date, most recent first, and filtered by account and year', () async {
    await h.apply((l) => l.recordEntry('a', 'la', entry(date: d(2026, 3, 1))));
    await h.apply((l) => l.recordEntry('b', 'lb', entry(date: d(2026, 7, 1), account: 'private')));
    final food2027 = (await h.ledger()).treeOrPreview(2027).named('Nourriture')!.id;
    await h.apply((l) => l.recordEntry('c', 'lc', entry(date: d(2027, 1, 1), category: food2027)));
    final l = await h.ledger();
    expect(l.transactionList().map((t) => t.id), ['c', 'b', 'a']);
    expect(l.transactionList(year: 2026).map((t) => t.id), ['b', 'a']);
    expect(l.transactionList(accountId: 'cash').map((t) => t.id), ['c', 'a']);
    expect(l.yearsWithTransactions, [2026, 2027]);
    expect(CalendarDate.parse('2026-03-01'), l.transactions['a']!.date);
  });
}
